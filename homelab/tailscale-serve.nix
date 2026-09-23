{
  config,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  template = import ../lib/template.nix {inherit lib;};
  tailscale = lib.getExe config.services.tailscale.package;
  # The Services config-file format cannot round-trip HTTPS termination to an
  # HTTP backend: set-config recreates these endpoints as HTTP listeners. Keep
  # the listener protocol explicit in the CLI invocation instead.
  serveCommand = name: service: "${tailscale} serve --yes --bg --service=svc:${name} --https=443 ${lib.escapeShellArg (homelab.loopbackUrl service.port)}";
  rootCommands = lib.mapAttrsToList serveCommand homelab.privateServices;
  advertiseCommands = lib.mapAttrsToList (name: _: "${tailscale} serve advertise ${lib.escapeShellArg "svc:${name}"}") homelab.privateServices;
  applyCommands = lib.concatStringsSep " &&\n" (rootCommands ++ advertiseCommands);
  desiredServicePattern = lib.concatMapStringsSep "|" (name: lib.escapeShellArg "svc:${name}") (builtins.attrNames homelab.privateServices);
  serveScriptText = template.render ../scripts/tailscale-serve-apply.sh {
    TAILSCALE_BIN = tailscale;
    JQ_BIN = lib.getExe pkgs.jq;
    SLEEP_BIN = lib.getExe' pkgs.coreutils "sleep";
    EXPECTED_DOMAIN = lib.escapeShellArg homelab.tailnetDomain;
    DESIRED_SERVICE_PATTERN = desiredServicePattern;
    APPLY_COMMANDS = applyCommands;
  };
  serveScript = pkgs.writeShellScript "tailscale-serve-apply" serveScriptText;
in {
  config = {
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
