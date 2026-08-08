{
  config,
  lib,
  pkgs,
}: let
  raw = import ../lib/homelab-services.nix;
  homelab = import ../lib/homelab.nix {inherit lib;};
  evaluate = services:
    builtins.tryEval (
      builtins.deepSeq (import ../lib/homelab-inventory.nix {inherit lib services;}) true
    );
  rejects = services: !(evaluate services).success;
  withService = name: update:
    raw
    // {
      ${name} = lib.recursiveUpdate raw.${name} update;
    };
  systemQuiesceUnits = lib.concatMap (
    service:
      map (entry: entry.unit) (lib.filter (entry: entry.scope == "system") service.backup.quiesce)
  ) (builtins.attrValues homelab.services);
  storageUnits = lib.concatMap (service: service.storage.units) (builtins.attrValues homelab.services);
  declaredSystemUnits = lib.unique (homelab.importantSystemdUnits ++ systemQuiesceUnits ++ storageUnits);
  unitExists = unit:
    if lib.hasSuffix ".service" unit
    then builtins.hasAttr (lib.removeSuffix ".service" unit) config.systemd.services
    else if lib.hasSuffix ".timer" unit
    then builtins.hasAttr (lib.removeSuffix ".timer" unit) config.systemd.timers
    else if lib.hasSuffix ".socket" unit
    then builtins.hasAttr (lib.removeSuffix ".socket" unit) config.systemd.sockets
    else false;
  realService = unit: let
    service = config.systemd.services.${lib.removeSuffix ".service" unit};
  in
    unitExists unit && (service.serviceConfig.ExecStart or null) != null;
  userQuiesceEntries = lib.concatMap (
    service: lib.filter (entry: entry.scope == "user") service.backup.quiesce
  ) (builtins.attrValues homelab.services);
  userUnitExists = entry:
    builtins.hasAttr entry.user config.home-manager.users
    && builtins.hasAttr (lib.removeSuffix ".service" entry.unit) config.home-manager.users.${entry.user}.systemd.user.services;
in
  assert lib.assertMsg (evaluate raw).success
  "the canonical homelab service inventory must validate";
  assert lib.assertMsg (rejects (withService "vaultwarden" {typo = true;}))
  "unknown service record fields must fail evaluation";
  assert lib.assertMsg (rejects (withService "vaultwarden" {endpoint.exposure = "private";}))
  "unknown exposure values must fail evaluation";
  assert lib.assertMsg (rejects (withService "vaultwarden" {state.kind = "files";}))
  "derived state kinds must not be configurable";
  assert lib.assertMsg (rejects (withService "vaultwarden" {
    backup.quiesce = [
      {
        unit = "vaultwarden.service";
        until = "copy";
      }
    ];
  }))
  "unknown quiesce phases must fail evaluation";
  assert lib.assertMsg (rejects (withService "vaultwarden" {endpoint.port = raw.kuma.endpoint.port;}))
  "endpoint port collisions must fail evaluation";
  assert lib.assertMsg (rejects (withService "vaultwarden" {backup.strategy = "snapshot";}))
  "unknown backup strategies must fail evaluation";
  assert lib.assertMsg (rejects (withService "vaultwarden" {
    backup = {
      strategy = "archive-transform";
      artifacts = [];
      transformedPaths = raw.vaultwarden.state.paths;
    };
  }))
  "transformed state without a generated archive artifact must fail evaluation";
  assert lib.assertMsg (rejects (withService "nextcloud" {storage.units = [];}))
  "/srv state without fail-closed service dependencies must fail evaluation";
  assert lib.assertMsg (rejects (withService "grafana" {state.paths = ["/var/lib/grafana"];}))
  "disposable services must not claim required recovery paths";
  assert lib.assertMsg (rejects (withService "vaultwarden" {recovery.acceptance = [];}))
  "stateful services must declare functional recovery acceptance checks";
  assert lib.assertMsg (rejects (withService "vaultwarden" {endpoint.authorizationOwner = null;}))
  "externally exposed services must declare their authorization owner";
  assert lib.assertMsg (rejects (withService "t3code" {
    backup.quiesce = [
      {
        scope = "user";
        user = null;
        unit = "t3code.service";
        until = "archive";
      }
    ];
  }))
  "user-scoped backup quiesce entries must declare their user";
  assert lib.assertMsg (lib.all unitExists declaredSystemUnits)
  "every declared homelab systemd unit must exist in Kim's evaluated configuration";
  assert lib.assertMsg (lib.all realService storageUnits)
  "every /srv dependency must target a real service rather than a generated empty unit";
  assert lib.assertMsg (lib.all userUnitExists userQuiesceEntries)
  "every user-scoped backup unit must exist in the declared user's Home Manager configuration";
  assert lib.assertMsg (homelab.services.paperless.state.kind == "database+files")
  "state kind must derive from Paperless's declared files and database";
  assert lib.assertMsg (homelab.services.homeassistant.backup.archivePaths == ["/var/backup/home-assistant/config.tar"])
  "archive-transform services must replace live state with their generated artifacts";
  assert lib.assertMsg (builtins.elem homelab.infrastructure.postgresqlBackup.archivePath homelab.backup.archivePaths)
  "the shared PostgreSQL dump must be included once whenever databases are declared";
    pkgs.runCommand "homelab-inventory-regression" {} ''
      touch "$out"
    ''
