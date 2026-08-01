{
  config,
  lib,
  pkgs,
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  backup = config.services.borgbackup.jobs.main;
  backupUnit = config.systemd.services.borgbackup-job-main;
  exporter = config.systemd.services.paperless-exporter;
  projectsPath = "/home/maxpw/Projects";
  hasProjectsPath = builtins.elem projectsPath backup.paths;
  backsUpPaperlessConsume = builtins.elem "/srv/paperless/consume" backup.paths;
  canWriteHomeAssistantArchive = builtins.elem "/var/backup/home-assistant" backupUnit.serviceConfig.ReadWritePaths;
  manifest = config.custom.backup.manifestMetadata;
  archivesManifest = builtins.elem "/var/backup/homelab" backup.paths;
  canWriteManifest = builtins.elem "/var/backup/homelab" backupUnit.serviceConfig.ReadWritePaths;
  canPersistRecoveryState = builtins.elem "/run/homelab-backup" backupUnit.serviceConfig.ReadWritePaths;
  writesSuccessMetrics =
    lib.hasInfix "homelab-backup-posthook" backup.postHook
    && builtins.elem "/var/lib/prometheus-node-exporter-text-files" backupUnit.serviceConfig.ReadWritePaths;
  recoversBeforeRepositoryMaintenance = lib.hasInfix "homelab-backup-coordinator" backup.postCreate;
  quiescesNextcloudUpdates = lib.all (unit: builtins.elem unit homelab.backup.archiveUnits) [
    "nextcloud-update-store-apps.timer"
    "nextcloud-cron.timer"
  ];
  quiescesPaperlessIngestion = lib.all (unit: builtins.elem unit homelab.backup.archiveUnits) [
    "paperless-consumer.service"
    "paperless-scheduler.service"
    "paperless-task-queue.service"
    "paperless-web.service"
  ];
  quiescesUptimeKuma = builtins.elem "uptime-kuma.service" homelab.backup.archiveUnits;
  quiescesT3Code = builtins.elem "maxpw:t3code.service" homelab.backup.userArchiveUnits;
  mutatesNextcloudMaintenance = lib.hasInfix "maintenance:mode" backup.preHook;
  exporterIsSynchronous = exporter.serviceConfig.Type or null == "oneshot";
  exporterRestartsApplications =
    (exporter.unitConfig.OnSuccess or [])
    != []
    || (exporter.unitConfig.OnFailure or []) != [];
  usesPersistentCoordinator =
    lib.hasInfix "homelab-backup-coordinator" backup.preHook
    && lib.hasInfix "homelab-backup-coordinator" backup.postCreate
    && lib.hasInfix "homelab-backup-posthook" backup.postHook;
  operationLockFile = "/run/lock/homelab-borg-operation.lock";
  serializesBorgOperations =
    lib.all (
      script:
        lib.hasInfix operationLockFile script
        && lib.hasInfix "/bin/flock" script
    ) [
      backup.preHook
      config.systemd.services.borgbackup-check-main.script
    ];
in
  assert lib.assertMsg (!hasProjectsPath)
  "the backup must not fail because the optional ~/Projects directory is absent";
  assert lib.assertMsg (backsUpPaperlessConsume && builtins.elem "/srv/paperless/media" backup.paths)
  "the backup must preserve Paperless pending inputs and database-route media";
  assert lib.assertMsg canWriteHomeAssistantArchive
  "the sandboxed Borg unit must be able to write the quiesced Home Assistant archive";
  assert lib.assertMsg (archivesManifest && canWriteManifest)
  "every archive must include a writable, runtime-generated recovery manifest";
  assert lib.assertMsg canPersistRecoveryState
  "the sandboxed Borg unit must persist unresolved service recovery state under /run";
  assert lib.assertMsg (
    manifest.schemaVersion
    == 1
    && manifest.expectedDatabases == ["hass" "miniflux" "nextcloud" "paperless" "vaultwarden"]
    && builtins.hasAttr "nextcloud" manifest.applicationVersions
    && builtins.hasAttr "kuma" manifest.applicationVersions
    && builtins.hasAttr "uptimeKuma" manifest.applicationVersions
    && manifest.postgresql.majorVersion != ""
    && builtins.elem "/srv/nextcloud" manifest.expectedPrimaryStatePaths
    && builtins.elem "/var/lib/private/uptime-kuma" manifest.expectedPrimaryStatePaths
    && builtins.elem "/home/maxpw/.local/share/t3code" manifest.expectedPrimaryStatePaths
    && builtins.elem "/home/maxpw/.local/share/t3code" manifest.expectedArchivePaths
    && manifest.applicationVersions.t3code != ""
    && manifest.recovery.t3code.runbook == "docs/homelab-recovery.md#t3-code"
    && builtins.elem "grafana" manifest.disposableState
  )
  "the archive manifest must identify versions, databases, primary state, and accepted disposable state";
  assert lib.assertMsg writesSuccessMetrics
  "the Borg post-hook must delegate final cleanup/status metrics with permission to write them";
  assert lib.assertMsg recoversBeforeRepositoryMaintenance
  "file-backed services must recover before Borg prune and compact";
  assert lib.assertMsg quiescesNextcloudUpdates
  "the backup must prevent mutable Nextcloud app updates while copying store-apps";
  assert lib.assertMsg quiescesPaperlessIngestion
  "Paperless ingestion must remain quiesced until pending consume files are copied";
  assert lib.assertMsg quiescesUptimeKuma
  "the backup must quiesce Uptime Kuma's mutable local database";
  assert lib.assertMsg quiescesT3Code
  "the backup must quiesce T3 Code's user-scoped SQLite and identity state";
  assert lib.assertMsg usesPersistentCoordinator
  "backup preparation and cleanup must share the failure-safe persisted coordinator";
  assert lib.assertMsg serializesBorgOperations
  "backup creation and consistency checks must acquire the same lock before touching applications or Borg";
  assert lib.assertMsg (!mutatesNextcloudMaintenance)
  "the backup must quiesce Nextcloud services instead of mutating its read-only config";
  assert lib.assertMsg exporterIsSynchronous
  "the backup must wait for the Paperless exporter to finish";
  assert lib.assertMsg (!exporterRestartsApplications)
  "the backup hook, not the exporter, must own application recovery ordering";
    pkgs.runCommand "paperless-backup-regression" {} ''
      touch "$out"
    ''
