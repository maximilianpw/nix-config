{
  config,
  pkgs,
  ...
}: let
  agentAliases = {
    c = "codex --yolo";
    ccc = "DISABLE_ZOXIDE=1 claude --dangerously-skip-permissions";
    oc = "opencode";
  };
  source = path: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/users/maxpw/agents/${path}";
in {
  home.packages = [
    pkgs.claude-code
    pkgs.codex
    pkgs.opencode
    pkgs.amp-cli
    pkgs.pi
    pkgs.agent-browser
    pkgs.skills
  ];

  home.file = {
    ".codex/AGENTS.md".source = source "shared/AGENTS.md";
    ".claude/CLAUDE.md".source = source "shared/AGENTS.md";
    ".config/opencode/AGENTS.md".source = source "shared/AGENTS.md";

    ".claude/settings.json".source = source "claude/settings.json";
    ".claude/commands" = {
      source = source "claude/commands";
      recursive = true;
    };
    ".claude/skills/lint-wiki" = {
      source = source "claude/skills/lint-wiki";
      recursive = true;
    };

    ".config/opencode/opencode.json".source = source "opencode/opencode.json";
  };

  programs.bash.shellAliases = agentAliases;
  programs.zsh.shellAliases = agentAliases;
  programs.fish.shellAliases = agentAliases;
  programs.nushell = {
    shellAliases = {
      c = "codex --yolo";
      oc = "opencode";
    };
    extraConfig = ''
      def --wrapped ccc [...args: string] {
        with-env {DISABLE_ZOXIDE: "1"} { claude --dangerously-skip-permissions ...$args }
      }
    '';
  };
}
