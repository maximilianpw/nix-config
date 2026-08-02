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
  serveScript = pkgs.writeShellScript "tailscale-serve-apply" ''
    set -eu

    expected_domain=${lib.escapeShellArg tailnetDomain}

    apply_config() {
      current_status="$(${tailscale} serve status --json)" || return 1
      current_services="$(printf '%s\n' "$current_status" | ${lib.getExe pkgs.jq} -r '.Services // {} | keys[]')" || return 1
      while IFS= read -r service; do
        [ -n "$service" ] || continue
        ${tailscale} serve drain "$service" || return 1
        case "$service" in
          ${desiredServicePattern}) ;;
          *) ${tailscale} serve clear "$service" || return 1 ;;
        esac
      done <<EOF
    $current_services
    EOF

      stale_services="$(printf '%s\n' "$current_status" | ${lib.getExe pkgs.jq} -r --arg suffix ".$expected_domain:443" '[.Services // {} | to_entries[] | .key as $service | (.value.Web // {} | keys[]) | select(endswith($suffix) | not) | $service] | unique[]')" || return 1
      while IFS= read -r service; do
        [ -n "$service" ] || continue
        case "$service" in
          ${desiredServicePattern}) ;;
          *) continue ;;
        esac
        ${tailscale} serve clear "$service" || return 1
      done <<EOF
    $stale_services
    EOF

      ${applyCommands}

      current_hosts="$(${tailscale} serve status --json | ${lib.getExe pkgs.jq} -r '.Services // {} | .[] | .Web // {} | keys[]')" || return 1
      while IFS= read -r host; do
        [ -n "$host" ] || continue
        case "$host" in
          *."$expected_domain":443) ;;
          *)
            echo "Tailscale Serve still advertises stale host $host; expected *.$expected_domain:443" >&2
            return 1
            ;;
        esac
      done <<EOF
    $current_hosts
    EOF
    }

    attempt=1
    delay=2
    while [ "$attempt" -le 8 ]; do
      if apply_config; then
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
