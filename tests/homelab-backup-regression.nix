{
  config,
  lib,
  pkgs,
}: let
  expect = import ./lib/expect.nix {inherit lib;};
  homelab = import ../lib/homelab.nix {inherit lib;};
  backup = config.services.borgbackup.jobs.main;
  backupUnit = config.systemd.services.borgbackup-job-main;
  verifyUnit = config.systemd.services.borgbackup-verify-main;
  initialVerifyUnit = config.systemd.services.borgbackup-verify-main-initial;
  exporter = config.systemd.services.paperless-exporter;
  backsUpPaperlessConsume = builtins.elem "/srv/paperless/consume" backup.paths;
  canWriteHomeAssistantArchive = builtins.elem "/var/backup/home-assistant" backupUnit.serviceConfig.ReadWritePaths;
  t3codeSource = "/home/maxpw/.local/share/t3code";
  t3codeArtifact = "/var/backup/t3code/state.tar";
  archivesT3CodeArtifact = builtins.elem t3codeArtifact backup.paths;
  excludesLiveT3CodeState = builtins.elem t3codeSource backup.exclude;
  canWriteT3CodeArtifact = builtins.elem "/var/backup/t3code" backupUnit.serviceConfig.ReadWritePaths;
  manifest = config.custom.backup.manifestMetadata;
  contributedVersions = config.custom.backup.applicationVersions;
  statefulServiceNames = builtins.attrNames (
    lib.filterAttrs (_: service: service.state.kind != "none") homelab.services
  );
  nixosOwnedVersionNames = lib.sort builtins.lessThan (
    ["homepage"] ++ builtins.filter (name: name != "t3code") statefulServiceNames
  );
  missingVersionFixture = lib.evalModules {
    specialArgs = {inherit pkgs;};
    modules = [
      ../modules/services/backup.nix
      {
        _module.check = false;
        custom.backup.applicationVersions = builtins.removeAttrs contributedVersions ["vaultwarden"];
        system.nixos.version = config.system.nixos.version;
        services.postgresql.package = config.services.postgresql.package;
      }
    ];
  };
  rejectsMissingVersion =
    !(builtins.tryEval (
      builtins.deepSeq missingVersionFixture.config.custom.backup.manifestMetadata true
    )).success;
  conflictingVersionFixture = lib.evalModules {
    specialArgs = {inherit pkgs;};
    modules = [
      ../modules/services/backup.nix
      {_module.check = false;}
      {custom.backup.applicationVersions.actual = "first";}
      {custom.backup.applicationVersions.actual = "second";}
    ];
  };
  rejectsConflictingVersion =
    !(builtins.tryEval (
      builtins.deepSeq conflictingVersionFixture.config.custom.backup.applicationVersions.actual true
    )).success;
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
  quiescesImmichWrites = builtins.elem "immich-server.service" homelab.backup.archiveUnits;
  quiescesForgejo = lib.all (unit: builtins.elem unit homelab.backup.archiveUnits) [
    "forgejo-runner.service"
    "forgejo.service"
  ];
  quiescesUptimeKuma = builtins.elem "uptime-kuma.service" homelab.backup.archiveUnits;
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
  assert expect.all "the archive manifest must identify versions, databases, primary state, and accepted disposable state" [
    (manifest.schemaVersion == 1)
    (builtins.attrNames contributedVersions == nixosOwnedVersionNames)
    (manifest.expectedDatabases == ["atuin" "forgejo" "hass" "immich" "miniflux" "nextcloud" "paperless" "vaultwarden"])
    (builtins.hasAttr "uptimeKuma" manifest.applicationVersions)
    (manifest.postgresql.majorVersion != "")
    (builtins.elem "/srv/nextcloud" manifest.expectedPrimaryStatePaths)
    (builtins.elem "/srv/immich" manifest.expectedPrimaryStatePaths)
    (builtins.elem "/srv/forgejo" manifest.expectedPrimaryStatePaths)
    (builtins.elem "/var/lib/forgejo-runner-registration" manifest.expectedPrimaryStatePaths)
    (builtins.elem "/var/lib/private/uptime-kuma" manifest.expectedPrimaryStatePaths)
    (builtins.elem t3codeSource manifest.expectedPrimaryStatePaths)
    (builtins.elem t3codeArtifact manifest.expectedArchivePaths)
    (!(builtins.elem t3codeSource manifest.expectedArchivePaths))
    (manifest.applicationVersions.t3code != "")
    (manifest.recovery.t3code.runbook == "docs/homelab-recovery.md#t3-code")
    (builtins.elem "grafana" manifest.disposableState)
  ];
  assert lib.assertMsg rejectsMissingVersion
  "an enabled stateful service without a version contribution must fail evaluation";
  assert lib.assertMsg rejectsConflictingVersion
  "conflicting application-version contributions must fail evaluation";
  assert lib.assertMsg writesSuccessMetrics
  "the Borg post-hook must delegate final cleanup/status metrics with permission to write them";
  assert lib.assertMsg recoversBeforeRepositoryMaintenance
  "file-backed services must recover before Borg prune and compact";
  assert lib.assertMsg quiescesNextcloudUpdates
  "the backup must prevent mutable Nextcloud app updates while copying store-apps";
  assert lib.assertMsg quiescesPaperlessIngestion
  "Paperless ingestion must remain quiesced until pending consume files are copied";
  assert lib.assertMsg quiescesImmichWrites
  "Immich must remain quiesced while its matching database and media are backed up";
  assert lib.assertMsg quiescesForgejo
  "Forgejo and its Actions runner must stay stopped through the database dump and repository archive";
  assert lib.assertMsg quiescesUptimeKuma
  "the backup must quiesce Uptime Kuma's mutable local database";
  assert lib.assertMsg (config.custom.backup.prepareStepOrder
    == [
      "online:t3code-snapshot"
      "quiesced:nextcloud-app-updates"
      "quiesced:paperless-export"
      "quiesced:home-assistant-archive"
      "quiesced:postgresql-dump"
    ])
  "backup preparation must snapshot T3 Code online, then finish app updates, export, archive, and dump while applications are stopped";
  assert lib.assertMsg usesPersistentCoordinator
  "backup preparation and cleanup must share the failure-safe persisted coordinator";
  assert lib.assertMsg serializesBorgOperations
  "backup creation and all consistency checks must acquire the same lock before touching applications or Borg";
  assert expect.all "the newest Borg archive must receive a serialized monthly cryptographic data verification" [
    (lib.hasInfix "--archives-only --verify-data --last 1" verifyUnit.script)
    (config.systemd.timers.borgbackup-verify-main.wantedBy == ["timers.target"])
    (config.systemd.timers.borgbackup-verify-main.timerConfig.OnCalendar == "*-*-01 06:00:00")
    (builtins.elem "/var/lib/prometheus-node-exporter-text-files" verifyUnit.serviceConfig.ReadWritePaths)
    (builtins.elem "borgbackup-verify-main.service" homelab.importantSystemdUnits)
    (builtins.elem "borgbackup-verify-main.timer" homelab.importantSystemdUnits)
  ];
  assert expect.all "a new deployment must seed its first Borg verification instead of alerting until the next month" [
    (initialVerifyUnit.unitConfig.ConditionPathExists == ["!/var/lib/prometheus-node-exporter-text-files/homelab-borg-verify.prom"])
    (lib.hasInfix "systemctl start borgbackup-verify-main.service" initialVerifyUnit.script)
    (config.systemd.timers.borgbackup-verify-main-initial.wantedBy == ["timers.target"])
    (config.systemd.timers.borgbackup-verify-main-initial.timerConfig.OnBootSec == "30m")
  ];
  assert lib.assertMsg operationLockWritable
  "the shared operation lock must be writable inside the sandboxed Borg backup service";
  assert lib.assertMsg exporterIsSynchronous
  "the backup must wait for the Paperless exporter to finish";
  assert lib.assertMsg (!exporterRestartsApplications)
  "the backup hook, not the exporter, must own application recovery ordering";
    pkgs.runCommand "homelab-backup-regression" {} ''
      touch "$out"
    ''
