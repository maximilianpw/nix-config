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
  channels = config.systemd.services.buzz-channels;
  generatedCompose = builtins.head composeFile;
in
  assert lib.assertMsg (builtins.length composeFile == 1)
  "Buzz must restart when its generated Compose configuration changes";
  assert lib.assertMsg usesGeneratedCompose
  "Buzz must start through the generated Compose configuration";
  assert lib.assertMsg hasBuzzExport
  "Borg must archive the application-level Buzz export";
  assert lib.assertMsg runsExporter
  "Borg must refresh the quiesced Buzz export before creating an archive";
  assert lib.assertMsg (channels.serviceConfig.Type == "oneshot")
  "Declarative Buzz channel reconciliation must be short-lived";
  assert lib.assertMsg (channels.serviceConfig.User == "root")
  "Only root may read the channel reconciliation signing credential";
  assert lib.assertMsg (config.sops.secrets.buzz-owner-private-key.mode == "0400")
  "The Buzz owner signing key must remain root-only";
  assert lib.assertMsg (config.sops.templates."buzz-channels.env".restartUnits == ["buzz-channels.service"])
  "Signing-key rotation must rerun channel reconciliation";
  assert lib.assertMsg (!(config.systemd.services ? buzz-nix-architect))
  "Declarative channels must not restore the removed architect agent";
  assert lib.assertMsg (!(config.systemd.services ? buzz-nix-builder))
  "Declarative channels must not restore the removed builder agent";
    pkgs.runCommand "buzz-config-regression" {} ''
      if ! grep -Fq '/usr/local/bin/buzz-pair-relay' ${generatedCompose}; then
        echo "Buzz Compose must run the dedicated mobile pairing relay" >&2
        exit 1
      fi
      if ! grep -Fq '127.0.0.1:19005:5000' ${generatedCompose}; then
        echo "Buzz pairing relay must remain bound to the declared loopback port" >&2
        exit 1
      fi
      if grep -Eq 'channels (add-member|remove-member)' ${channels.serviceConfig.ExecStart}; then
        echo "Declarative channel reconciliation must not manage membership or roles" >&2
        exit 1
      fi
      touch "$out"
    ''
