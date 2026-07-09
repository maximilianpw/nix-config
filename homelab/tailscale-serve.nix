{
  config,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  tailscale = lib.getExe config.services.tailscale.package;
  serveConfig = pkgs.writeText "tailscale-serve.json" (builtins.toJSON {
    version = "0.0.1";
    services =
      lib.mapAttrs'
      (name: service:
        lib.nameValuePair "svc:${name}" {
          endpoints."tcp:443" = homelab.loopbackUrl service.port;
        })
      homelab.privateServices;
  });
  serveScript = pkgs.writeShellScript "tailscale-serve-apply" ''
    set -eu

    attempt=1
    delay=2
    while [ "$attempt" -le 8 ]; do
      if ${tailscale} serve set-config --all ${serveConfig}; then
        exit 0
      fi

      if [ "$attempt" -eq 8 ]; then
        break
      fi

      echo "tailscaled is not ready for Serve config (attempt $attempt/8); retrying in ''${delay}s" >&2
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
