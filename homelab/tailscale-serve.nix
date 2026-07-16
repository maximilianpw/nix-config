{
  config,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  tailscale = lib.getExe config.services.tailscale.package;
  # The Services config-file format cannot round-trip HTTPS termination to an
  # HTTP backend: set-config recreates these endpoints as HTTP listeners. Keep
  # the listener protocol explicit in the CLI invocation instead.
  serveCommand = name: service: "${tailscale} serve --yes --bg --service=svc:${name} --https=443 ${lib.escapeShellArg (homelab.loopbackUrl service.port)}";
  applyCommands = lib.concatStringsSep " &&\n" (lib.mapAttrsToList serveCommand homelab.privateServices);
  serveScript = pkgs.writeShellScript "tailscale-serve-apply" ''
    set -eu

    attempt=1
    delay=2
    while [ "$attempt" -le 8 ]; do
      if ${applyCommands}; then
        exit 0
      fi

      if [ "$attempt" -eq 8 ]; then
        break
      fi

      echo "failed to apply Tailscale Serve configuration (attempt $attempt/8); retrying in ''${delay}s" >&2
      ${lib.getExe' pkgs.coreutils "sleep"} "$delay"
      attempt=$((attempt + 1))
      if [ "$delay" -lt 30 ]; then
        delay=$((delay * 2))
      fi
    done

    echo "failed to apply Tailscale Serve configuration after 8 attempts" >&2
    exit 1
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
        "network-online.target"
        "tailscaled.service"
        "tailscaled-autoconnect.service"
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
