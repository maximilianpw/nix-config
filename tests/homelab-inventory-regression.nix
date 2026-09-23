{
  config,
  lib,
  pkgs,
}: let
  expect = import ./lib/expect.nix {inherit lib;};
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
  quiesceUnits = lib.concatMap (
    service: map (entry: entry.unit) service.backup.quiesce
  ) (builtins.attrValues homelab.services);
  storageUnits = lib.concatMap (service: service.storage.units) (builtins.attrValues homelab.services);
  declaredSystemUnits = lib.unique (homelab.importantSystemdUnits ++ quiesceUnits ++ storageUnits);
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
in
  assert lib.assertMsg (evaluate raw).success
  "the canonical homelab service inventory must validate";
  assert lib.assertMsg (rejects (withService "vaultwarden" {endpoint.port = raw.kuma.endpoint.port;}))
  "endpoint port collisions must fail evaluation";
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
  assert lib.assertMsg (lib.all unitExists declaredSystemUnits)
  "every declared homelab systemd unit must exist in Kim's evaluated configuration";
  assert lib.assertMsg (lib.all realService storageUnits)
  "every /srv dependency must target a real service rather than a generated empty unit";
  assert expect.all "endpoint bind scope must default to loopback with explicit host-bound exceptions" [
    (homelab.services.jellyfin.endpoint.bindScope == "host")
    (homelab.services.plex.endpoint.bindScope == "host")
    (homelab.services.bazarr.endpoint.bindScope == "loopback")
    (homelab.services.seerr.endpoint.bindScope == "loopback")
  ];
  assert lib.assertMsg (homelab.services.paperless.state.kind == "database+files")
  "state kind must derive from Paperless's declared files and database";
  assert lib.assertMsg (homelab.services.homeassistant.backup.archivePaths == ["/var/backup/home-assistant/config.tar"])
  "archive-transform services must replace live state with their generated artifacts";
  assert lib.assertMsg (
    homelab.services.t3code.backup.archivePaths
    == ["/var/backup/t3code/state.tar"]
    && homelab.services.t3code.backup.quiesce == []
  )
  "T3 Code must use an online archive transformation without service quiescing";
  assert lib.assertMsg (builtins.elem homelab.infrastructure.postgresqlBackup.archivePath homelab.backup.archivePaths)
  "the shared PostgreSQL dump must be included once whenever databases are declared";
    pkgs.runCommand "homelab-inventory-regression" {} ''
      touch "$out"
    ''
