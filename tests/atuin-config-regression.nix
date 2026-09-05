{
  config,
  joyce,
  cuno,
  lib,
  pkgs,
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  endpoint = (homelab.endpoints config.homelab.tailnet.domain).atuin;
  server = config.services.atuin;
  clients = [config.home-manager.users.maxpw.programs.atuin joyce.home-manager.users.max-vev.programs.atuin];
  manifest = config.custom.backup.manifestMetadata;
in
  assert lib.assertMsg (
    server.enable
    && server.host == "127.0.0.1"
    && server.port == endpoint.port
    && !server.openFirewall
    && !server.openRegistration
    && !(builtins.elem server.port config.networking.firewall.allowedTCPPorts)
  ) "Atuin must use private loopback ingress with registration closed";
  assert lib.assertMsg (
    server.database.createLocally
    && server.database.uri == "postgresql:///atuin?host=/run/postgresql"
    && config.services.postgresql.settings.listen_addresses == ""
    && builtins.elem "atuin" config.services.postgresql.ensureDatabases
    && builtins.elem "atuin" manifest.expectedDatabases
    && builtins.elem "atuin.service" homelab.backup.dumpUnits
    && manifest.applicationVersions.atuin == server.package.version
  ) "Atuin must use and back up the local socket-only PostgreSQL database";
  assert lib.assertMsg (lib.all (client:
    client.enable
    && client.enableNushellIntegration
    && client.enableBashIntegration
    && client.enableFishIntegration
    && client.settings.sync_address == endpoint.url
    && client.settings.auto_sync
    && client.settings.sync_frequency == "5m"
    && client.settings.filter_mode == "global"
    && client.settings.secrets_filter
    && builtins.elem "^ " client.settings.history_filter
    && builtins.elem "--disable-ai" client.flags
    && builtins.elem "--disable-up-arrow" client.flags)
  clients) "Kim and Joyce must share private automatic history sync while preserving up-arrow";
  assert lib.assertMsg (!cuno.home-manager.users.maxpw.programs.atuin.enable)
  "Atuin enrollment must remain limited to Kim and Joyce";
    pkgs.runCommand "atuin-config-regression" {} ''
      touch "$out"
    ''
