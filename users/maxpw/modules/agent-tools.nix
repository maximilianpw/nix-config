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

  # Remote Plannotator sessions share one fixed forwarded port. Serialize
  # Codex Stop hooks so concurrent agents queue instead of racing to bind it.
  plannotatorCodexHook = pkgs.writeShellScript "plannotator-codex-hook" ''
    lock_file="''${XDG_RUNTIME_DIR:-/tmp}/plannotator-codex-$UID.lock"
    exec ${pkgs.util-linux}/bin/flock --exclusive "$lock_file" ${pkgs.plannotator}/bin/plannotator
  '';
  source = path: homeFiles.mkRepoSource config.home.homeDirectory "users/${currentSystemUserDir}/agents/${path}";
  piConfigSource = path: homeFiles.mkHomeSource config.home.homeDirectory "pi-config/${path}";
  sharedAgentsText = builtins.readFile ../agents/shared/AGENTS.md;
  claudeAgentsText =
    sharedAgentsText
    + "\n\n---\n\n"
    + (builtins.readFile ../agents/claude/CLAUDE.md);
  codexAgentsText =
    sharedAgentsText
    + "\n\n---\n\n"
    + (builtins.readFile ../agents/codex/AGENTS.md);
in {
  home = {
    packages =
      [
        pkgs.claude-code
        pkgs.codex
        pkgs.opencode
        pkgs.grok
        pkgs.herdr
        pkgs.amp-cli
        pkgs.pi
      ]
      ++ lib.optionals (hostname == "kim") [pkgs.plannotator];

    file =
      {
        ".config/amp/settings.json".source = source "amp/settings.json";
        ".codex/AGENTS.md".text = codexAgentsText;
        ".claude/CLAUDE.md".text = claudeAgentsText;
        ".config/opencode/AGENTS.md".source = source "shared/AGENTS.md";
        # Pi uses the shared cross-agent policy directly.
        ".pi/agent/AGENTS.md".text = sharedAgentsText;
        ".claude/settings.json".source = source "claude/settings.json";

        ".config/opencode/opencode.json".source = source "opencode/opencode.json";

        ".pi/agent/settings.json".source = piConfigSource "settings.json";
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
                  timeout = 345600;
                }
              ];
            }
          ];
        };
      };
  };
}
