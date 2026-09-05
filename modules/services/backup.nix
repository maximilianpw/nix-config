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
  git = lib.getExe pkgs.git;
  jq = lib.getExe pkgs.jq;
  flock = lib.getExe' pkgs.util-linux "flock";
  systemctl = lib.getExe' pkgs.systemd "systemctl";
  borgOperationLockFile = "/run/homelab-backup/borg-operation.lock";
  homeAssistantBackupDir = "/var/backup/home-assistant";
  homelabBackupDir = "/var/backup/homelab";
  backupMetricsDir = "/var/lib/prometheus-node-exporter-text-files";
  homelab = import ../../lib/homelab.nix {inherit lib;};
  t3codeSourceDir = builtins.head homelab.services.t3code.state.paths;
  t3codeBackupArtifact = builtins.head homelab.services.t3code.backup.artifacts;
  t3codeBackupDir = builtins.dirOf t3codeBackupArtifact;
  # Lifecycle ownership is declarative; service-specific export and archive
  # commands remain in this coordinator.
  databaseApplicationUnits = homelab.backup.dumpUnits;
  fileApplicationUnits = homelab.backup.archiveUnits;
  userDatabaseApplicationUnits = homelab.backup.userDumpUnits;
  userFileApplicationUnits = homelab.backup.userArchiveUnits;
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
  inherit (cfg) applicationVersions;
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
  t3codeBackup = pkgs.writeShellApplication {
    name = "t3code-backup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnutar
      pkgs.rsync
      pkgs.sqlite
    ];
    text = ''
      export T3CODE_SOURCE_DIR=${lib.escapeShellArg t3codeSourceDir}
      export T3CODE_BACKUP_DIR=${lib.escapeShellArg t3codeBackupDir}
      export SQLITE_BIN=${lib.getExe pkgs.sqlite}
      export RSYNC_BIN=${lib.getExe pkgs.rsync}
      export TAR_BIN=${tar}
      exec ${lib.getExe pkgs.bash} ${../../scripts/t3code-backup.sh}
    '';
  };
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
      export T3CODE_BACKUP_BIN=${lib.getExe t3codeBackup}
      exec ${lib.getExe pkgs.bash} ${../../scripts/homelab-backup-coordinator.sh} "$@"
    '';
  };
  healthcheckPing = pkgs.writeShellApplication {
    name = "homelab-backup-healthcheck";
    runtimeInputs = [pkgs.curl];
    text = ''
      export CURL_BIN=${lib.getExe pkgs.curl}
      export HOMELAB_HEALTHCHECK_URL_FILE=${lib.escapeShellArg cfg.healthcheckUrlFile}
      exec ${lib.getExe pkgs.bash} ${../../scripts/healthcheck-ping.sh} "$@"
    '';
  };
  postHookRunner = pkgs.writeShellApplication {
    name = "homelab-backup-posthook";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      export HOMELAB_COORDINATOR_BIN=${lib.getExe coordinator}
      export HOMELAB_BACKUP_METRICS_DIR=${lib.escapeShellArg backupMetricsDir}
      export DATE_BIN=${lib.getExe' pkgs.coreutils "date"}
      ${lib.optionalString (cfg.healthcheckUrlFile != null) "export HOMELAB_HEARTBEAT_BIN=${lib.getExe healthcheckPing}"}
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
      pkgs.sqlite
    ];
    text = ''
      export BORG_BIN=${borg}
      export JQ_BIN=${jq}
      export SQLITE_BIN=${lib.getExe pkgs.sqlite}
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
      export BORG_BIN=${borg}
      export FIND_BIN=${lib.getExe pkgs.findutils}
      export BORG_REPO=${lib.escapeShellArg cfg.repo}
      export BORG_PASSCOMMAND=${lib.escapeShellArg "cat ${config.sops.secrets.borg-backup-passphrase.path}"}
      ${builtins.readFile ../../scripts/borg-restore-main.sh}
    '';
  };
in {
  options.custom.backup = {
    enable = lib.mkEnableOption "borgbackup to external drive";

    applicationVersions = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Service-owned application versions included in the recovery manifest.";
    };

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
        # T3 Code remains online while its SQLite database and surrounding
        # state are transformed into a consistent archive artifact.
        t3codeSourceDir
        # PostgreSQL is recovered from the consistent logical dump produced
        # immediately before Borg starts, never from live database files.
        "/var/lib/postgresql"
        # Metrics history, Alertmanager state, and Grafana's local database are
        # disposable; their configuration and dashboards are provisioned from
        # this repository.
        "/var/lib/prometheus2"
        "/var/lib/alertmanager"
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

    healthcheckUrlFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/homelab-backup-healthcheck-url";
      description = "Runtime file containing an external dead-man ping URL for backup start, success, and failure signals.";
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
        export DATE_BIN=${lib.getExe' pkgs.coreutils "date"}
        export FLOCK_BIN=${flock} GIT_BIN=${git} JQ_BIN=${jq}
        export BORG_OPERATION_LOCK_FILE=${lib.escapeShellArg borgOperationLockFile}
        export NIX_CONFIG_DIR=${lib.escapeShellArg "${homeDir}/nix-config"}
        export HOMELAB_MANIFEST_STATIC=${lib.escapeShellArg manifestStatic}
        export HOMELAB_MANIFEST_TMP=${lib.escapeShellArg "${homelabBackupDir}/manifest.json.tmp"}
        export HOMELAB_MANIFEST_PATH=${lib.escapeShellArg "${homelabBackupDir}/manifest.json"}
        export HOMELAB_BACKUP_COORDINATOR_BIN=${lib.getExe coordinator}
        ${lib.optionalString (cfg.healthcheckUrlFile != null) "export HOMELAB_HEARTBEAT_BIN=${lib.getExe healthcheckPing}"}
        ${builtins.readFile ../../scripts/homelab-backup-pre-hook.sh}
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
        t3codeBackupDir
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
        "d ${t3codeBackupDir} 0700 root root -"
        "d /run/homelab-backup 0700 root root -"
      ];
      tmpfiles.settings."10-homelab-metrics"."${backupMetricsDir}".d = {
        user = "root";
        group = "root";
        mode = "0755";
      };

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
            export BORG_BIN=${borg}
            export DATE_BIN=${lib.getExe' pkgs.coreutils "date"}
            export FLOCK_BIN=${flock}
            export BORG_OPERATION_LOCK_FILE=${lib.escapeShellArg borgOperationLockFile}
            export HOMELAB_BACKUP_METRICS_DIR=${lib.escapeShellArg backupMetricsDir}
            ${builtins.readFile ../../scripts/homelab-borg-check.sh}
          '';
        };

        borgbackup-verify-main = {
          description = "Cryptographically verify the latest main Borg archive";
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
            verify_started_epoch=$(date +%s)
            ${borg} check --lock-wait 60 --archives-only --verify-data --last 1
            verify_finished_epoch=$(date +%s)
            metrics_tmp=${lib.escapeShellArg "${backupMetricsDir}/homelab-borg-verify.prom.tmp"}
            {
              printf 'homelab_borg_verify_last_success_timestamp_seconds %s\n' "$verify_finished_epoch"
              printf 'homelab_borg_verify_last_duration_seconds %s\n' "$((verify_finished_epoch - verify_started_epoch))"
            } > "$metrics_tmp"
            chmod 0644 "$metrics_tmp"
            mv -f "$metrics_tmp" ${lib.escapeShellArg "${backupMetricsDir}/homelab-borg-verify.prom"}
          '';
        };

        borgbackup-verify-main-initial = {
          description = "Seed Kim's first Borg data-verification result";
          unitConfig.ConditionPathExists = [
            "!${backupMetricsDir}/homelab-borg-verify.prom"
          ];
          serviceConfig.Type = "oneshot";
          script = ''
            ${systemctl} start borgbackup-verify-main.service
          '';
        };
      };

      timers = {
        borgbackup-check-main = {
          description = "Weekly Borg repository consistency check";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "Sun *-*-* 05:00:00";
            Persistent = true;
            RandomizedDelaySec = "30m";
          };
        };

        borgbackup-verify-main = {
          description = "Monthly cryptographic verification of the latest Borg archive";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "*-*-01 06:00:00";
            Persistent = true;
            RandomizedDelaySec = "30m";
          };
        };

        borgbackup-verify-main-initial = {
          description = "Run the first Borg data verification after activation";
          wantedBy = ["timers.target"];
          timerConfig.OnBootSec = "30m";
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
