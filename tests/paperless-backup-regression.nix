{
  config,
  lib,
  pkgs,
}: let
  backup = config.services.borgbackup.jobs.main;
  exporter = config.systemd.services.paperless-exporter;
  projectsPath = "/home/maxpw/Projects";
  hasProjectsPath = builtins.elem projectsPath backup.paths;
  mutatesNextcloudMaintenance = lib.hasInfix "maintenance:mode" backup.preHook;
  exporterIsSynchronous = exporter.serviceConfig.Type or null == "oneshot";
  exporterRestartsApplications =
    (exporter.unitConfig.OnSuccess or [])
    != []
    || (exporter.unitConfig.OnFailure or []) != [];
in
  assert lib.assertMsg (!hasProjectsPath)
  "the backup must not fail because the optional ~/Projects directory is absent";
  assert lib.assertMsg (!mutatesNextcloudMaintenance)
  "the backup must quiesce Nextcloud services instead of mutating its read-only config";
  assert lib.assertMsg exporterIsSynchronous
  "the backup must wait for the Paperless exporter to finish";
  assert lib.assertMsg (!exporterRestartsApplications)
  "the backup hook, not the exporter, must own application recovery ordering";
    pkgs.runCommand "paperless-backup-regression" {} ''
      touch "$out"
    ''
