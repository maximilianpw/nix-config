{
  config,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  tailscale = lib.getExe config.services.tailscale.package;
  tailnetDomain = config.homelab.tailnet.domain;
  # The Services config-file format cannot round-trip HTTPS termination to an
  # HTTP backend: set-config recreates these endpoints as HTTP listeners. Keep
  # the listener protocol explicit in the CLI invocation instead.
  serveCommand = name: service: "${tailscale} serve --yes --bg --service=svc:${name} --https=443 ${lib.escapeShellArg (homelab.loopbackUrl service.port)}";
  servePathCommand = name: path: port: "${tailscale} serve --yes --bg --service=svc:${name} --https=443 --set-path=${lib.escapeShellArg path} ${lib.escapeShellArg (homelab.loopbackUrl port)}";
  rootCommands = lib.mapAttrsToList serveCommand homelab.privateServices;
  pathCommands = lib.concatLists (
    lib.mapAttrsToList (
      name: service:
        lib.mapAttrsToList (servePathCommand name) (service.pathBackends or {})
    )
    homelab.privateServices
  );
  advertiseCommands = lib.mapAttrsToList (name: _: "${tailscale} serve advertise ${lib.escapeShellArg "svc:${name}"}") homelab.privateServices;
  applyCommands = lib.concatStringsSep " &&\n" (rootCommands ++ pathCommands ++ advertiseCommands);
  desiredServicePattern = lib.concatMapStringsSep "|" (name: lib.escapeShellArg "svc:${name}") (builtins.attrNames homelab.privateServices);
  serveScriptMarkers = [
    "@TAILSCALE_BIN@"
    "@JQ_BIN@"
    "@SLEEP_BIN@"
    "@EXPECTED_DOMAIN@"
    "@DESIRED_SERVICE_PATTERN@"
    "@APPLY_COMMANDS@"
  ];
  serveScriptText = let
    rendered =
      lib.replaceStrings
      serveScriptMarkers
      [
        tailscale
        (lib.getExe pkgs.jq)
        (lib.getExe' pkgs.coreutils "sleep")
        (lib.escapeShellArg tailnetDomain)
        desiredServicePattern
        applyCommands
      ]
      (builtins.readFile ../scripts/tailscale-serve-apply.sh);
  in
    assert lib.assertMsg
    (lib.all (marker: !lib.hasInfix marker rendered) serveScriptMarkers)
    "scripts/tailscale-serve-apply.sh contains an unsubstituted template marker"; rendered;
  serveScript = pkgs.writeShellScript "tailscale-serve-apply" serveScriptText;
in {
  options.homelab.tailnet.domain = lib.mkOption {
    type = lib.types.str;
    default = homelab.defaultTailnetDomain;
    description = "MagicDNS suffix for private homelab Tailscale Serve endpoints.";
  };

  config = {
    assertions = [
      {
        assertion = config.services.tailscale.enable;
        message = "homelab Tailscale Serve requires services.tailscale.enable to be true";
      }
    ];

    systemd.services.tailscale-serve = {
      description = "Tailscale Serve Configuration";
      after = [
        "network-online.target"
        "tailscaled.service"
        "tailscaled-set.service"
      ];
      requires = ["tailscaled.service"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      restartTriggers = [serveScript];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = serveScript;
        ExecReload = serveScript;
        TimeoutStartSec = "4min";
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };
  };
}
