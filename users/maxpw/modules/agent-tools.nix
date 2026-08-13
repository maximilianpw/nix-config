{
  config,
  currentSystemUserDir,
  hostname,
  pkgs,
  lib,
  ...
}: let
  homeFiles = import ../../../lib/home-files.nix {
    inherit lib;
    mkOutOfStoreSymlink = config.lib.file.mkOutOfStoreSymlink;
  };

  # Remote Plannotator sessions share one fixed forwarded port. Ignore non-plan
  # Stop events before locking so ordinary Codex turns never queue behind a review.
  plannotatorCodexHook = pkgs.writeShellScript "plannotator-codex-hook" ''
    payload="$(${pkgs.coreutils}/bin/cat)"
    if ! ${pkgs.jq}/bin/jq -e '.permission_mode == "plan"' >/dev/null <<<"$payload"; then
      printf '{}\n'
      exit 0
    fi

    lock_file="''${XDG_RUNTIME_DIR:-/tmp}/plannotator-codex-$UID.lock"
    exec ${pkgs.util-linux}/bin/flock --exclusive "$lock_file" ${pkgs.plannotator}/bin/plannotator <<<"$payload"
  '';
  source = path: homeFiles.mkRepoSource config.home.homeDirectory "users/${currentSystemUserDir}/agents/${path}";
  piConfigSource = path: homeFiles.mkHomeSource config.home.homeDirectory "pi-config/${path}";
in {
  home = {
    packages = [
      pkgs.claude-code
      pkgs.codex
      pkgs.opencode
      pkgs.grok
      pkgs.herdr
      pkgs.amp-cli
      pkgs.pi
      pkgs.skills
      pkgs.plannotator
    ];

    file =
      {
        ".config/amp/settings.json".source = source "amp/settings.json";
        ".codex/AGENTS.md".source = source "shared/AGENTS.md";
        ".claude/CLAUDE.md".source = source "shared/AGENTS.md";
        ".config/opencode/AGENTS.md".source = source "shared/AGENTS.md";
        ".pi/agent/AGENTS.md".source = source "shared/AGENTS.md";
        ".claude/settings.json".source = source "claude/settings.json";

        ".config/opencode/opencode.json".source = source "opencode/opencode.json";

        ".pi/agent/settings.json".source = piConfigSource "settings.json";
        ".pi/agent/mcp.json".source = piConfigSource "mcp.json";
        ".pi/agent/cloak.json".source = piConfigSource "cloak.json";
        ".pi/agent/extensions" = {
          source = piConfigSource "extensions";
          recursive = true;
        };
        ".pi/agent/prompts" = {
          source = piConfigSource "prompts";
          recursive = true;
        };
        ".pi/agent/themes" = {
          source = piConfigSource "themes";
          recursive = true;
        };
      }
      // lib.optionalAttrs (hostname == "kim") {
        # Codex reviews the final plan after a turn stops. The wrapper queues
        # concurrent reviews before they contend for the fixed remote port.
        ".codex/hooks.json".text = builtins.toJSON {
          hooks.Stop = [
            {
              hooks = [
                {
                  type = "command";
                  command = "${plannotatorCodexHook}";
                  statusMessage = "Checking for plan";
                  timeout = 345600;
                }
              ];
            }
          ];
        };
      };
  };
}
