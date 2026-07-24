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
  buzzStart = config.systemd.services.buzz.serviceConfig.ExecStart;
  buzzEnv = config.sops.templates."buzz.env".content;
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
  assert lib.assertMsg (lib.hasInfix "BUZZ_GIT_CONFORMANCE_PROBE=true" buzzEnv)
  "Buzz must keep the object-store correctness gate enabled";
    pkgs.runCommand "buzz-config-regression" {} ''
      awk '
        /^  pairing-relay:/ { in_pairing_relay = 1; next }
        in_pairing_relay && /^  [^ ]/ { exit }
        in_pairing_relay { print }
      ' ${generatedCompose} > pairing-relay.yml

      if ! grep -Fq 'entrypoint:' pairing-relay.yml ||
        ! grep -Fq '/usr/local/bin/buzz-pair-relay' pairing-relay.yml; then
        echo "Buzz Compose must replace the image entrypoint with the dedicated pairing relay" >&2
        exit 1
      fi
      if grep -Fq 'command:' pairing-relay.yml; then
        echo "Buzz pairing relay must not use Compose command; the image entrypoint is buzz-relay" >&2
        exit 1
      fi
      if ! grep -Fq '127.0.0.1:19005:5000' pairing-relay.yml; then
        echo "Buzz pairing relay must remain bound to the declared loopback port" >&2
        exit 1
      fi
      if ! grep -Fq 'if !' ${buzzStart} ||
        ! grep -Fq -- '--no-deps --force-recreate relay pairing-relay' ${buzzStart}; then
        echo "Buzz startup must retry only the stateless application services" >&2
        exit 1
      fi
      if grep -Eq 'channels (add-member|remove-member)' ${channels.serviceConfig.ExecStart}; then
        echo "Declarative channel reconciliation must not manage membership or roles" >&2
        exit 1
      fi
      touch "$out"
    ''
