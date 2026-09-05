{
  config,
  lib,
  pkgs,
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  backup = config.services.borgbackup.jobs.main;
  backupUnit = config.systemd.services.borgbackup-job-main;
  verifyUnit = config.systemd.services.borgbackup-verify-main;
  initialVerifyUnit = config.systemd.services.borgbackup-verify-main-initial;
  exporter = config.systemd.services.paperless-exporter;
  projectsPath = "/home/maxpw/Projects";
  hasProjectsPath = builtins.elem projectsPath backup.paths;
  backsUpPaperlessConsume = builtins.elem "/srv/paperless/consume" backup.paths;
  canWriteHomeAssistantArchive = builtins.elem "/var/backup/home-assistant" backupUnit.serviceConfig.ReadWritePaths;
  t3codeSource = "/home/maxpw/.local/share/t3code";
  t3codeArtifact = "/var/backup/t3code/state.tar";
  archivesT3CodeArtifact = builtins.elem t3codeArtifact backup.paths;
  excludesLiveT3CodeState = builtins.elem t3codeSource backup.exclude;
  canWriteT3CodeArtifact = builtins.elem "/var/backup/t3code" backupUnit.serviceConfig.ReadWritePaths;
  manifest = config.custom.backup.manifestMetadata;
  expectedApplicationVersions = {
    actual = config.services.actual.package.version;
    bazarr = config.services.bazarr.package.version;
    executor = config.virtualisation.oci-containers.containers.executor.image;
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
    sabnzbd = config.containers.sab.config.services.sabnzbd.package.version;
    seerr = config.services.seerr.package.version;
    sonarr = config.services.sonarr.package.version;
    syncthing = config.services.syncthing.package.version;
    t3code = (import ../users/maxpw/settings.nix {inherit pkgs;}).t3codeRelease.version;
    tunarr = (pkgs.callPackage ../packages/tunarr.nix {}).version;
    vaultwarden = config.services.vaultwarden.package.version;
    uptimeKuma = config.services.uptime-kuma.package.version;
  };
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
  quiescesActual = builtins.elem "actual.service" homelab.backup.archiveUnits;
  quiescesImmichWrites = builtins.elem "immich-server.service" homelab.backup.archiveUnits;
  quiescesUptimeKuma = builtins.elem "uptime-kuma.service" homelab.backup.archiveUnits;
  quiescesExecutor = builtins.elem "docker-executor.service" homelab.backup.archiveUnits;
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
  operationLockFile = "/run/homelab-backup/borg-operation.lock";
  operationLockWritable =
    lib.any (
      path: operationLockFile == path || lib.hasPrefix "${path}/" operationLockFile
    )
    backupUnit.serviceConfig.ReadWritePaths;
  serializesBorgOperations =
    lib.all (
      script:
        lib.hasInfix operationLockFile script
        && lib.hasInfix "/bin/flock" script
    ) [
      backup.preHook
      config.systemd.services.borgbackup-check-main.script
      verifyUnit.script
    ];
in
  assert lib.assertMsg (!hasProjectsPath)
  "the backup must not fail because the optional ~/Projects directory is absent";
  assert lib.assertMsg (backsUpPaperlessConsume && builtins.elem "/srv/paperless/media" backup.paths)
  "the backup must preserve Paperless pending inputs and database-route media";
  assert lib.assertMsg canWriteHomeAssistantArchive
  "the sandboxed Borg unit must be able to write the quiesced Home Assistant archive";
  assert lib.assertMsg (archivesT3CodeArtifact && excludesLiveT3CodeState && canWriteT3CodeArtifact)
  "T3 Code must be backed up from its writable online snapshot artifact, never its live state tree";
  assert lib.assertMsg (archivesManifest && canWriteManifest)
  "every archive must include a writable, runtime-generated recovery manifest";
  assert lib.assertMsg canPersistRecoveryState
  "the sandboxed Borg unit must persist unresolved service recovery state under /run";
  assert lib.assertMsg (
    manifest.schemaVersion
    == 1
    && manifest.expectedDatabases == ["hass" "immich" "miniflux" "nextcloud" "paperless" "vaultwarden"]
    && config.custom.backup.applicationVersions == expectedApplicationVersions
    && manifest.applicationVersions == config.custom.backup.applicationVersions
    && manifest.postgresql.majorVersion != ""
    && builtins.elem "/var/lib/actual" manifest.expectedPrimaryStatePaths
    && builtins.elem "/var/lib/actual" manifest.expectedArchivePaths
    && builtins.elem "/srv/nextcloud" manifest.expectedPrimaryStatePaths
    && builtins.elem "/srv/immich" manifest.expectedPrimaryStatePaths
    && builtins.elem "/var/lib/executor" manifest.expectedPrimaryStatePaths
    && builtins.elem "/var/lib/executor" manifest.expectedArchivePaths
    && builtins.elem "/var/lib/private/uptime-kuma" manifest.expectedPrimaryStatePaths
    && builtins.elem t3codeSource manifest.expectedPrimaryStatePaths
    && builtins.elem t3codeArtifact manifest.expectedArchivePaths
    && !(builtins.elem t3codeSource manifest.expectedArchivePaths)
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
  assert lib.assertMsg quiescesActual
  "the backup must quiesce Actual Budget's account and synchronized budget state";
  assert lib.assertMsg quiescesImmichWrites
  "Immich must remain quiesced while its matching database and media are backed up";
  assert lib.assertMsg quiescesUptimeKuma
  "the backup must quiesce Uptime Kuma's mutable local database";
  assert lib.assertMsg quiescesExecutor
  "the backup must quiesce Executor's database and generated encryption keys";
  assert lib.assertMsg (!quiescesT3Code)
  "T3 Code must stay online while SQLite's backup API snapshots its state";
  assert lib.assertMsg usesPersistentCoordinator
  "backup preparation and cleanup must share the failure-safe persisted coordinator";
  assert lib.assertMsg serializesBorgOperations
  "backup creation and all consistency checks must acquire the same lock before touching applications or Borg";
  assert lib.assertMsg (
    lib.hasInfix "--archives-only --verify-data --last 1" verifyUnit.script
    && config.systemd.timers.borgbackup-verify-main.wantedBy == ["timers.target"]
    && config.systemd.timers.borgbackup-verify-main.timerConfig.OnCalendar == "*-*-01 06:00:00"
    && builtins.elem "/var/lib/prometheus-node-exporter-text-files" verifyUnit.serviceConfig.ReadWritePaths
    && builtins.elem "borgbackup-verify-main.service" homelab.importantSystemdUnits
    && builtins.elem "borgbackup-verify-main.timer" homelab.importantSystemdUnits
  )
  "the newest Borg archive must receive a serialized monthly cryptographic data verification";
  assert lib.assertMsg (
    initialVerifyUnit.unitConfig.ConditionPathExists
    == ["!/var/lib/prometheus-node-exporter-text-files/homelab-borg-verify.prom"]
    && lib.hasInfix "systemctl start borgbackup-verify-main.service" initialVerifyUnit.script
    && config.systemd.timers.borgbackup-verify-main-initial.wantedBy == ["timers.target"]
    && config.systemd.timers.borgbackup-verify-main-initial.timerConfig.OnBootSec == "30m"
  )
  "a new deployment must seed its first Borg verification instead of alerting until the next month";
  assert lib.assertMsg operationLockWritable
  "the shared operation lock must be writable inside the sandboxed Borg backup service";
  assert lib.assertMsg (!mutatesNextcloudMaintenance)
  "the backup must quiesce Nextcloud services instead of mutating its read-only config";
  assert lib.assertMsg exporterIsSynchronous
  "the backup must wait for the Paperless exporter to finish";
  assert lib.assertMsg (!exporterRestartsApplications)
  "the backup hook, not the exporter, must own application recovery ordering";
    pkgs.runCommand "homelab-backup-regression" {} ''
      touch "$out"
    ''
