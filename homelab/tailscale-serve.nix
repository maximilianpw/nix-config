{
  config,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  tailscale = lib.getExe config.services.tailscale.package;
  # Use the CLI form because services.tailscale.serve's config-file path
  # represents these service proxies as HTTP on 443 instead of HTTPS
  # termination to a local HTTP backend.
  serveCommand = name: service: ''
    ${tailscale} serve --yes --bg --service=svc:${name} --https=443 ${lib.escapeShellArg (homelab.loopbackUrl service.port)}
  '';
  serveScript = pkgs.writeShellScript "tailscale-serve-apply" ''
    set -eu

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList serveCommand homelab.privateServices)}
  '';
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
        "tailscaled.service"
        "tailscaled-autoconnect.service"
        "tailscaled-set.service"
      ];
      wants = ["tailscaled.service"];
      wantedBy = ["multi-user.target"];
      restartTriggers = [serveScript];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = serveScript;
      };
    };
  };
}
