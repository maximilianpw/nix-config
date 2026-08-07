{
  config,
  pkgs,
  lib,
  currentSystemUser ? "maxpw",
  currentSystemUserDir ? currentSystemUser,
  ...
}: let
  cfg = config.custom.backup;
  homeDir = "/home/${currentSystemUser}";
  borg = lib.getExe config.services.borgbackup.package;
  tar = lib.getExe pkgs.gnutar;
  git = lib.getExe pkgs.git;
  jq = lib.getExe pkgs.jq;
  flock = lib.getExe' pkgs.util-linux "flock";
  borgOperationLockFile = "/run/homelab-backup/borg-operation.lock";
  homeAssistantBackupDir = "/var/backup/home-assistant";
  homelabBackupDir = "/var/backup/homelab";
  backupMetricsDir = "/var/lib/prometheus-node-exporter-text-files";
  homelab = import ../../lib/homelab.nix {inherit lib;};
  # Lifecycle ownership is declarative; service-specific export and archive
  # commands remain in this coordinator.
  databaseApplicationUnits = homelab.backup.dumpUnits;
  fileApplicationUnits = homelab.backup.archiveUnits;
  userDatabaseApplicationUnits = homelab.backup.userDumpUnits;
  userFileApplicationUnits = homelab.backup.userArchiveUnits;
  t3codeVersion = (import ../../users/${currentSystemUserDir}/settings.nix {inherit pkgs;}).t3codeRelease.version;
  baseBackupPaths = [
    "${homeDir}/nix-config"
    "${homeDir}/Documents"
    "${homeDir}/Sync"
    "${homeDir}/.config"
    "${homeDir}/.local/share"
    "${homeDir}/.ssh"
    "${homeDir}/.gnupg"
    # Preserve broad system identity/state coverage while recovery owners are
    # made explicit service by service in the typed inventory.
    "/var/lib"
  ];
  pathCoveredBy = parents: path:
    lib.any (parent: path == parent || lib.hasPrefix "${parent}/" path) parents;
  inventoryArchiveRoots =
    builtins.filter (
      path: !(pathCoveredBy baseBackupPaths path)
    )
    homelab.backup.archivePaths;
  applicationVersions = {
    bazarr = config.services.bazarr.package.version;
    grafana = config.services.grafana.package.version;
    homeassistant = config.services.home-assistant.package.version;
    homepage = config.services.homepage-dashboard.package.version;
    immich = config.services.immich.package.version;
    jellyfin = config.services.jellyfin.package.version;
    kuma = config.services.uptime-kuma.package.version;
    lidarr = config.services.lidarr.package.version;
    miniflux = config.services.miniflux.package.version;
    nextcloud = config.services.nextcloud.package.version;
    paperless = config.services.paperless.package.version;
    prowlarr = config.services.prowlarr.package.version;
    prometheus = config.services.prometheus.package.version;
    qbittorrent = config.containers.qbt.config.services.qbittorrent.package.version;
    radarr = config.services.radarr.package.version;
    sabnzbd = config.services.sabnzbd.package.version;
    seerr = config.services.seerr.package.version;
    sonarr = config.services.sonarr.package.version;
    syncthing = config.services.syncthing.package.version;
    t3code = t3codeVersion;
    tunarr = pkgs.tunarr.version;
    vaultwarden = config.services.vaultwarden.package.version;
    # Preserve the schema-v1 manifest key while the canonical inventory name
    # above lets coverage track the service directly.
    uptimeKuma = config.services.uptime-kuma.package.version;
  };
  statefulServiceNames = builtins.attrNames (
    lib.filterAttrs (_: service: service.state.kind != "none") homelab.services
  );
  missingApplicationVersions =
    builtins.filter (
      service: !(builtins.hasAttr service applicationVersions)
    )
    statefulServiceNames;
  manifestMetadata = assert lib.assertMsg (missingApplicationVersions == [])
  "backup manifest lacks package versions for stateful services: ${lib.concatStringsSep ", " missingApplicationVersions}"; {
    schemaVersion = 1;
    system.nixosVersion = config.system.nixos.version;
    postgresql = {
      majorVersion = lib.versions.major config.services.postgresql.package.version;
      packageVersion = config.services.postgresql.package.version;
    };
    inherit applicationVersions;
    expectedDatabases = homelab.backup.expectedDatabases;
    expectedPrimaryStatePaths = homelab.backup.primaryStatePaths;
    expectedArchivePaths = lib.unique (homelab.backup.archivePaths
      ++ [
        "${homeDir}/nix-config"
        "/var/backup/homelab/manifest.json"
      ]);
    disposableState = homelab.backup.disposableServices;
    recovery = homelab.backup.recovery;
  };
  manifestStatic = builtins.toJSON manifestMetadata;
  coordinator = pkgs.writeShellApplication {
    name = "homelab-backup-coordinator";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnutar
      pkgs.systemd
    ];
    text = ''
      export SYSTEMCTL_BIN=${lib.getExe' pkgs.systemd "systemctl"}
      export TAR_BIN=${tar}
      export SLEEP_BIN=${lib.getExe' pkgs.coreutils "sleep"}
      export HOMELAB_DUMP_UNITS=${lib.escapeShellArg (lib.concatStringsSep " " databaseApplicationUnits)}
      export HOMELAB_ARCHIVE_UNITS=${lib.escapeShellArg (lib.concatStringsSep " " fileApplicationUnits)}
      export HOMELAB_USER_DUMP_UNITS=${lib.escapeShellArg (lib.concatStringsSep " " userDatabaseApplicationUnits)}
      export HOMELAB_USER_ARCHIVE_UNITS=${lib.escapeShellArg (lib.concatStringsSep " " userFileApplicationUnits)}
      export HOMELAB_POSTGRESQL_BACKUP_UNIT=${lib.escapeShellArg homelab.infrastructure.postgresqlBackup.unit}
      export HOME_ASSISTANT_ARCHIVE_DIR=${lib.escapeShellArg homeAssistantBackupDir}
      exec ${lib.getExe pkgs.bash} ${../../scripts/homelab-backup-coordinator.sh} "$@"
    '';
  };
  postHookRunner = pkgs.writeShellApplication {
    name = "homelab-backup-posthook";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      export HOMELAB_COORDINATOR_BIN=${lib.getExe coordinator}
      export HOMELAB_BACKUP_METRICS_DIR=${lib.escapeShellArg backupMetricsDir}
      export DATE_BIN=${lib.getExe' pkgs.coreutils "date"}
      exec ${lib.getExe pkgs.bash} ${../../scripts/homelab-backup-posthook.sh} "$@"
    '';
  };
  inspectMain = pkgs.writeShellApplication {
    name = "homelab-backup-inspect";
    runtimeInputs = [
      config.services.borgbackup.package
      pkgs.gawk
      pkgs.gnutar
      pkgs.jq
    ];
    text = ''
      export BORG_BIN=${borg}
      export JQ_BIN=${jq}
      export TAR_BIN=${tar}
      export BORG_REPO=${lib.escapeShellArg cfg.repo}
      export BORG_PASSCOMMAND=${lib.escapeShellArg "cat ${config.sops.secrets.borg-backup-passphrase.path}"}
      export HOMELAB_REQUIRE_ROOT=1
      exec ${lib.getExe pkgs.bash} ${../../scripts/homelab-backup-inspect.sh} "$@"
    '';
  };
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
      default = lib.unique (baseBackupPaths ++ inventoryArchiveRoots ++ [homelabBackupDir]);
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
        # LazyLibrarian is retired; never recapture orphaned state while the
        # root-owned directory awaits explicit deletion.
        "/var/lib/lazylibrarian"
        # Tunarr can rebuild its sparse Meilisearch index from the preserved
        # database and snapshots; archiving the sparse file wastes space.
        "/var/lib/tunarr/data.ms"
        # Home Assistant is archived while quiesced before Borg starts. Avoid
        # also capturing its live config tree after the service restarts.
        "/var/lib/hass"
        # PostgreSQL is recovered from the consistent logical dump produced
        # immediately before Borg starts, never from live database files.
        "/var/lib/postgresql"
        # Metrics history and Grafana's local database are disposable; their
        # configuration and dashboards are provisioned from this repository.
        "/var/lib/prometheus2"
        "/var/lib/grafana"
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

    manifestMetadata = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      description = "Non-secret, versioned metadata written into every homelab archive.";
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
    custom.backup.manifestMetadata = manifestMetadata;

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
        backup_started_epoch=$(date +%s)
        backup_started_at=$(date --iso-8601=seconds)

        # Acquire this before generating artifacts or stopping applications.
        # Consistency checks use the same lock, so delayed timers and manual
        # starts cannot make Borg contend after services are already quiesced.
        exec 9>${lib.escapeShellArg borgOperationLockFile}
        ${flock} 9

        git_revision="$(${git} -c safe.directory=${lib.escapeShellArg "${homeDir}/nix-config"} -C ${lib.escapeShellArg "${homeDir}/nix-config"} rev-parse HEAD 2>/dev/null || printf unavailable)"
        git_dirty=false
        if [ "$git_revision" != unavailable ] && [ -n "$(${git} -c safe.directory=${lib.escapeShellArg "${homeDir}/nix-config"} -C ${lib.escapeShellArg "${homeDir}/nix-config"} status --porcelain 2>/dev/null)" ]; then
          git_dirty=true
        fi
        manifest_tmp=${lib.escapeShellArg "${homelabBackupDir}/manifest.json.tmp"}
        printf '%s\n' ${lib.escapeShellArg manifestStatic} \
          | ${jq} \
            --arg backupStartTimestamp "$backup_started_at" \
            --arg gitRevision "$git_revision" \
            --argjson gitDirty "$git_dirty" \
            '. + {backupStartTimestamp: $backupStartTimestamp, gitRevision: $gitRevision, gitDirty: $gitDirty}' \
          > "$manifest_tmp"
        chmod 0600 "$manifest_tmp"
        mv -f "$manifest_tmp" ${lib.escapeShellArg "${homelabBackupDir}/manifest.json"}

        # The coordinator persists the pre-existing active set before stopping
        # anything. Its cleanup phase can therefore recover services after a
        # preparation failure or Borg failure without starting units that were
        # already inactive.
        ${lib.getExe coordinator} prepare
      '';

      # Recover file-backed services as soon as Borg has captured and finalized
      # the archive. Repository pruning and compaction do not need an outage.
      postCreate = ''
        ${lib.getExe coordinator} cleanup
      '';

      postHook = ''
        # The upstream Borg unit invokes this from an EXIT trap. The helper
        # always retries cleanup and returns the final status for that trap.
        set +e
        ${lib.getExe postHookRunner} "$exitStatus" "''${backup_started_epoch:-0}"
        exitStatus=$?
      '';

      extraArgs = "--lock-wait 60";
      readWritePaths = [
        homeAssistantBackupDir
        homelabBackupDir
        backupMetricsDir
        "/run/homelab-backup"
      ];
    };

    services.postgresqlBackup = {
      enable = true;
      backupAll = true;
      compression = "zstd";
      location = homelab.infrastructure.postgresqlBackup.archivePath;
      # Borg starts this oneshot directly after quiescing the applications.
      startAt = [];
    };

    systemd = {
      # The upstream Borg unit uses ProtectSystem=strict. Declare both the
      # directory and its write exception so the pre-hook can atomically replace
      # Home Assistant's quiesced config archive.
      tmpfiles.rules = [
        "d ${homeAssistantBackupDir} 0700 root root -"
        "d ${homelabBackupDir} 0700 root root -"
        "d ${backupMetricsDir} 0755 root root -"
        "d /run/homelab-backup 0700 root root -"
      ];

      services = {
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
            ReadWritePaths = [backupMetricsDir];
          };
          environment = {
            BORG_REPO = cfg.repo;
            BORG_PASSCOMMAND = "cat ${config.sops.secrets.borg-backup-passphrase.path}";
          };
          script = ''
            exec 9>${lib.escapeShellArg borgOperationLockFile}
            ${flock} 9
            check_started_epoch=$(date +%s)
            ${borg} check --lock-wait 60 --repository-only --max-duration 3600
            ${borg} check --lock-wait 60 --archives-only --last 1
            check_finished_epoch=$(date +%s)
            metrics_tmp=${lib.escapeShellArg "${backupMetricsDir}/homelab-borg-check.prom.tmp"}
            {
              printf 'homelab_borg_check_last_success_timestamp_seconds %s\n' "$check_finished_epoch"
              printf 'homelab_borg_check_last_duration_seconds %s\n' "$((check_finished_epoch - check_started_epoch))"
            } > "$metrics_tmp"
            chmod 0644 "$metrics_tmp"
            mv -f "$metrics_tmp" ${lib.escapeShellArg "${backupMetricsDir}/homelab-borg-check.prom"}
          '';
        };
      };

      timers.borgbackup-check-main = {
        description = "Weekly Borg repository consistency check";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "Sun *-*-* 05:00:00";
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
      };
    };

    environment.systemPackages = [
      config.services.borgbackup.package
      coordinator
      inspectMain
      postHookRunner
      restoreMain
    ];
  };
}
