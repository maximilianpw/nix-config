{
  config,
  hostname,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../../../lib/homelab.nix {inherit lib;};
  endpoint = homelab.endpoints.plannotator;
  appConfig = builtins.fromJSON (builtins.readFile ../app-config/.plannotator/config.json);
  inboxEnvironment = {
    PLANNOTATOR_INBOX_CONNECT = "0";
    PLANNOTATOR_INBOX_NOTES = "0";
    PLANNOTATOR_INBOX_TAILSCALE =
      if hostname == "kim"
      then "1"
      else "0";
  };
  plannotator = pkgs.symlinkJoin {
    name = "plannotator-configured-${pkgs.plannotator.version}";
    paths = [pkgs.plannotator];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram "$out/bin/plannotator" ${lib.concatStringsSep " " (lib.mapAttrsToList (name: value: "--set ${name} ${lib.escapeShellArg value}") inboxEnvironment)}
    '';
  };
  inbox = pkgs.writeShellApplication {
    name = "inbox";
    text = ''
      export INBOX_HOST=${lib.escapeShellArg hostname}
      export PLANNOTATOR_BIN=${plannotator}/bin/plannotator
      export INBOX_KIM_URL=${lib.escapeShellArg endpoint.url}
      export INBOX_KIM_HOST=${lib.escapeShellArg "kim.${homelab.tailnetDomain}"}
      export INBOX_REDIRECT_PORT=${toString endpoint.port}
      export INBOX_ALLOWED_LOGINS=${lib.escapeShellArg (builtins.toJSON appConfig.inboxTailscaleAllow)}
      export INBOX_VERSION=${lib.escapeShellArg pkgs.plannotator.version}
      export FLEET_BIN=${lib.getExe config.programs.fleet.package}
      export INBOX_OPEN_BIN=${
        if pkgs.stdenv.hostPlatform.isDarwin
        then "/usr/bin/open"
        else lib.getExe' pkgs.xdg-utils "xdg-open"
      }
      exec ${lib.getExe pkgs.python3} ${../../../scripts/user/plannotator-inbox.py} "$@"
    '';
  };
  tailscaleReady = pkgs.writeShellScript "plannotator-tailscale-ready" ''
    set -euo pipefail
    ${lib.getExe pkgs.tailscale} status --json | ${lib.getExe pkgs.jq} -e '.BackendState == "Running"' >/dev/null
  '';
in {
  home = {
    packages = [plannotator inbox];
    # Native plugins can launch an embedded Inbox without going through the CLI.
    sessionVariables = inboxEnvironment;

    # Own the installer's usual path too: native plugins prefer it over PATH.
    # Preserve an existing installer binary before the first activation.
    file = {
      ".local/bin/plannotator".source = "${plannotator}/bin/plannotator";
      ".local/bin/inbox".source = "${inbox}/bin/inbox";
    };

    # Codex owns its mutable config (projects, trust and login settings).
    # Register just this server through its supported merger, not a home.file.
    activation.configurePlannotatorCodex = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run ${lib.getExe pkgs.codex} mcp add plannotator-inbox -- ${plannotator}/bin/plannotator inbox mcp
    '';
  };

  systemd.user.services = lib.mkIf (hostname == "kim") {
    plannotator-inbox = {
      Unit = {
        Description = "Plannotator Inbox (owner-only Tailscale UI)";
        After = ["network-online.target"];
        StartLimitIntervalSec = 0;
      };
      Service = {
        ExecStartPre = tailscaleReady;
        ExecStart = "${plannotator}/bin/plannotator inbox --no-open";
        # Retry if an on-demand instance won the startup race and this exits.
        Restart = "always";
        RestartSec = "10s";
        WorkingDirectory = "%h";
        Environment = ["PATH=${lib.makeBinPath [pkgs.tailscale pkgs.git pkgs.coreutils]}"];
        UMask = "0077";
        NoNewPrivileges = true;
      };
      Install.WantedBy = ["default.target"];
    };
    plannotator-inbox-redirect = {
      Unit = {
        Description = "Stable authenticated Plannotator Inbox bookmark";
        Wants = ["plannotator-inbox.service"];
        After = ["plannotator-inbox.service"];
      };
      Service = {
        ExecStart = "${inbox}/bin/inbox serve";
        Restart = "on-failure";
        RestartSec = "5s";
        UMask = "0077";
        NoNewPrivileges = true;
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
