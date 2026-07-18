{
  config,
  pkgs,
  lib,
  currentSystemUser ? "maxpw",
  ...
}: let
  cfg = config.custom.backup;
  homeDir = "/home/${currentSystemUser}";
  borg = lib.getExe config.services.borgbackup.package;
  tar = lib.getExe pkgs.gnutar;
  homeAssistantBackupDir = "/var/backup/home-assistant";
  databaseApplicationUnits = [
    "home-assistant.service"
    "miniflux.service"
    "paperless-consumer.service"
    "paperless-scheduler.service"
    "paperless-task-queue.service"
    "paperless-web.service"
  ];
  fileApplicationUnits = [
    "nextcloud-cron.service"
    "phpfpm-nextcloud.service"
    "syncthing.service"
  ];
  restoreMain = pkgs.writeShellApplication {
    name = "borg-restore-main";
    runtimeInputs = [
      config.services.borgbackup.package
      pkgs.findutils
    ];
    text = ''
      set -eu

      if [ "$(id -u)" -ne 0 ]; then
        echo "borg-restore-main must run as root so it can read the repository passphrase" >&2
        echo "Try: sudo borg-restore-main <archive> <existing-empty-directory> [path ...]" >&2
        exit 1
      fi

      if [ "$#" -lt 2 ]; then
        echo "Usage: borg-restore-main <archive> <existing-empty-directory> [path ...]" >&2
        echo "List archives first with: sudo borg-job-main list" >&2
        exit 2
      fi

      archive="$1"
      destination="$2"
      shift 2

      if [ ! -d "$destination" ]; then
        echo "Refusing to create the restore destination; create it explicitly first: $destination" >&2
        exit 1
      fi
      if [ -n "$(find "$destination" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
        echo "Restore destination must be empty: $destination" >&2
        exit 1
      fi

      case "$archive" in
        ::*) archive_ref="$archive" ;;
        *) archive_ref="::$archive" ;;
      esac

      export BORG_REPO=${lib.escapeShellArg cfg.repo}
      export BORG_PASSCOMMAND=${lib.escapeShellArg "cat ${config.sops.secrets.borg-backup-passphrase.path}"}
      cd "$destination"
      exec borg extract --list "$archive_ref" "$@"
    '';
  };
in {
  options.custom.backup = {
    enable = lib.mkEnableOption "borgbackup to external drive";

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "${homeDir}/nix-config"
        "${homeDir}/Documents"
        "${homeDir}/Sync"
        "${homeDir}/.config"
        "${homeDir}/.local/share"
        "${homeDir}/.ssh"
        "${homeDir}/.gnupg"
        "/srv/nextcloud"
        "/srv/paperless/export"
        homeAssistantBackupDir
        "/var/backup/postgresql"
        "/var/lib"
      ];
      description = "Paths to back up";
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "**/node_modules"
        "**/.git/objects"
        "**/__pycache__"
        "**/.cache"
        # /var/lib is in `paths`, but these are huge, high-churn, and
        # reproducible: container layers, VM disk images, LLM model blobs.
        "/var/lib/docker"
        "/var/lib/containers"
        "/var/lib/libvirt/images"
        "/var/lib/private/ollama"
        "/var/lib/ollama"
        # Home Assistant is archived while quiesced before Borg starts. Avoid
        # also capturing its live config tree after the service restarts.
        "/var/lib/hass"
        # PostgreSQL is recovered from the consistent logical dump produced
        # immediately before Borg starts, never from live database files.
        "/var/lib/postgresql"
        "/var/lib/systemd/coredump"
      ];
      description = "Patterns to exclude from backup";
    };

    repo = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/backups/borg";
      description = "Borg repository path";
    };

    driveUUID = lib.mkOption {
      type = lib.types.str;
      default = "73afcc5c-6148-4dc2-ae0e-61649ce71120";
      description = "UUID of the backup drive";
    };

    retention = lib.mkOption {
      # Strict keys so a typo (e.g. `dailly`) fails at eval time instead of
      # silently weakening the prune policy at runtime.
      type = lib.types.submodule {
        options = {
          within = lib.mkOption {type = lib.types.str;};
          daily = lib.mkOption {type = lib.types.int;};
          weekly = lib.mkOption {type = lib.types.int;};
          monthly = lib.mkOption {type = lib.types.int;};
          yearly = lib.mkOption {type = lib.types.int;};
        };
      };
      default = {
        within = "1d";
        daily = 7;
        weekly = 4;
        monthly = 6;
        yearly = 2;
      };
      description = "Borg prune retention policy";
    };
  };

  config = lib.mkIf cfg.enable {
    fileSystems."/mnt/backups" = {
      device = "/dev/disk/by-uuid/${cfg.driveUUID}";
      fsType = "ext4";
      options = [
        "nofail"
        "x-systemd.automount"
        "x-systemd.idle-timeout=10min"
      ];
    };

    services.borgbackup.jobs.main = {
      inherit (cfg) paths;
      inherit (cfg) exclude repo;

      encryption = {
        mode = "repokey-blake2";
        passCommand = "cat ${config.sops.secrets.borg-backup-passphrase.path}";
      };

      compression = "auto,zstd";
      doInit = false;
      removableDevice = true;

      prune.keep = cfg.retention;

      startAt = "03:00";
      persistentTimer = true;

      extraCreateArgs = [
        "--stats"
        "--checkpoint-interval"
        "600"
      ];

      preHook = ''
        echo "Starting backup at $(date)"

        stopped_database_units=()
        for unit in ${lib.escapeShellArgs databaseApplicationUnits}; do
          if systemctl is-active --quiet "$unit"; then
            stopped_database_units+=("$unit")
          fi
        done
        if [ "''${#stopped_database_units[@]}" -gt 0 ]; then
          systemctl stop "''${stopped_database_units[@]}"
        fi

        stopped_file_units=()
        for unit in ${lib.escapeShellArgs fileApplicationUnits}; do
          if systemctl is-active --quiet "$unit"; then
            stopped_file_units+=("$unit")
          fi
        done
        if [ "''${#stopped_file_units[@]}" -gt 0 ]; then
          systemctl stop "''${stopped_file_units[@]}"
        fi

        # Paperless' exporter is the supported application-level restore
        # format. The local override makes this a synchronous oneshot and
        # leaves application recovery under this hook's control.
        systemctl start paperless-exporter.service

        # Home Assistant keeps UI-managed configuration and credentials below
        # /var/lib/hass. Snapshot that tree while the service is stopped; its
        # recorder history is captured separately by the PostgreSQL dump.
        install -d -m 0700 ${lib.escapeShellArg homeAssistantBackupDir}
        home_assistant_archive=${lib.escapeShellArg "${homeAssistantBackupDir}/config.tar"}
        rm -f "$home_assistant_archive.tmp"
        ${tar} --create --sparse --file "$home_assistant_archive.tmp" --directory /var/lib hass
        chmod 0600 "$home_assistant_archive.tmp"
        mv -f "$home_assistant_archive.tmp" "$home_assistant_archive"

        # Logical dumps are portable across PostgreSQL storage and package
        # changes. The service is ordered after the application quiesce above.
        systemctl start postgresqlBackup.service

        # Paperless restores from its exporter output and Miniflux is fully
        # represented by the logical database dump, so they can return as soon
        # as the dump finishes. Nextcloud and Syncthing remain quiesced while
        # Borg copies their live file trees.
        for unit in "''${stopped_database_units[@]}"; do
          systemctl start "$unit"
        done
        stopped_database_units=()
      '';

      postHook = ''
        # The upstream Borg unit invokes this from an EXIT trap while `set -e`
        # is still active. Disable fail-fast so one broken service cannot leave
        # every other application quiesced.
        set +e
        backup_exit_status=$exitStatus
        cleanup_failed=0

        for unit in "''${stopped_database_units[@]:-}" "''${stopped_file_units[@]:-}"; do
          if [ -n "$unit" ]; then
            if ! systemctl start "$unit"; then
              echo "Failed to restart $unit after backup" >&2
              cleanup_failed=1
            fi
          fi
        done

        if [ "$backup_exit_status" -eq 0 ] && [ "$cleanup_failed" -eq 0 ]; then
          echo "Backup finished successfully at $(date)"
        elif [ "$backup_exit_status" -ne 0 ]; then
          echo "Backup failed with status $backup_exit_status at $(date)" >&2
        fi
        if [ "$cleanup_failed" -ne 0 ]; then
          echo "One or more services failed to recover after backup" >&2
          if [ "$exitStatus" -eq 0 ]; then
            exitStatus=1
          fi
        fi
      '';

      extraArgs = "--lock-wait 60";
    };

    services.postgresqlBackup = {
      enable = true;
      backupAll = true;
      compression = "zstd";
      location = "/var/backup/postgresql";
      # Borg starts this oneshot directly after quiescing the applications.
      startAt = [];
    };

    systemd.services = {
      borgbackup-job-main = {
        requires = ["srv.mount"];
        after = ["srv.mount"];
        unitConfig.RequiresMountsFor = [
          "/srv"
        ];
      };

      borgbackup-check-main = {
        description = "Incremental consistency check of the main Borg repository";
        requires = ["mnt-backups.mount"];
        after = ["mnt-backups.mount" "borgbackup-job-main.service"];
        unitConfig.RequiresMountsFor = [cfg.repo];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        environment = {
          BORG_REPO = cfg.repo;
          BORG_PASSCOMMAND = "cat ${config.sops.secrets.borg-backup-passphrase.path}";
        };
        script = ''
          ${borg} check --lock-wait 60 --repository-only --max-duration 3600
          ${borg} check --lock-wait 60 --archives-only --last 1
        '';
      };
    };

    systemd.timers.borgbackup-check-main = {
      description = "Weekly Borg repository consistency check";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "Sun *-*-* 05:00:00";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };

    environment.systemPackages = [
      config.services.borgbackup.package
      restoreMain
    ];
  };
}
