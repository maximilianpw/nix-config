{
  config,
  pkgs,
  lib,
  ...
}: let
  agentAliases = {
    c = "codex --yolo";
    ccc = "DISABLE_ZOXIDE=1 claude --dangerously-skip-permissions";
    oc = "opencode";
    p = "pi";
  };
  source = path: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/users/maxpw/agents/${path}";

  globalSkills = [
    "mattpocock/skills@tdd"
    "mattpocock/skills@grill-me"
    "mattpocock/skills@write-a-prd"
    "mattpocock/skills@improve-codebase-architecture"
    "vercel-labs/skills@find-skills"
  ];
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
    ".pi/AGENTS.md".source = source "shared/AGENTS.md";

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

    ".pi/agent/settings.json".source = source "pi/settings.json";
  };

  home.activation.installGlobalSkills = lib.hm.dag.entryAfter ["writeBoundary"] ''
    set -euo pipefail

    export PATH=${lib.makeBinPath [pkgs.git pkgs.openssh]}:$PATH
    export GIT_TERMINAL_PROMPT=0
    export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh"

    install_skill() {
      local skill="$1"
      local skill_name="''${skill##*@}"
      local skill_path="$HOME/.agents/skills/$skill_name/SKILL.md"

      if [ -e "$skill_path" ]; then
        return 0
      fi

      if ! ${pkgs.skills}/bin/skills add "$skill" -g -y 2>&1; then
        echo "installGlobalSkills: warning: failed to install $skill" >&2
        return 0
      fi
    }

    ${lib.concatMapStringsSep "\n    " (s: ''install_skill "${s}"'') globalSkills}
  '';

  programs.bash.shellAliases = agentAliases;
  programs.zsh.shellAliases = agentAliases;
  programs.fish.shellAliases = agentAliases;
  programs.nushell = {
    shellAliases = {
      c = "codex --yolo";
      oc = "opencode";
      p = "pi";
    };
    extraConfig = ''
      def --wrapped ccc [...args: string] {
        with-env {DISABLE_ZOXIDE: "1"} { claude --dangerously-skip-permissions ...$args }
      }
    '';
  };
}
