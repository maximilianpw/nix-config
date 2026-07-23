{
  config,
  lib,
  pkgs,
}: let
  composeFile = config.systemd.services.buzz.restartTriggers;
  backup = config.services.borgbackup.jobs.main;
  hasBuzzExport = builtins.elem "/var/backup/buzz" backup.paths;
  runsExporter = lib.hasInfix "systemctl start buzz-backup-export.service" backup.preHook;
  usesGeneratedCompose = lib.hasSuffix "-buzz-compose.yml" (toString (builtins.head composeFile));
in
  assert lib.assertMsg (builtins.length composeFile == 1)
  "Buzz must restart when its generated Compose configuration changes";
  assert lib.assertMsg usesGeneratedCompose
  "Buzz must start through the generated Compose configuration";
  assert lib.assertMsg hasBuzzExport
  "Borg must archive the application-level Buzz export";
  assert lib.assertMsg runsExporter
  "Borg must refresh the quiesced Buzz export before creating an archive";
    pkgs.runCommand "buzz-config-regression" {} ''
      touch "$out"
    ''
