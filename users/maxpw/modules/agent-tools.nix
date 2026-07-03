{
  config,
  pkgs,
  lib,
  isDarwin,
  ...
}: let
  agentAliases = {
    c = "codex --yolo";
    ccc = "DISABLE_ZOXIDE=1 claude --dangerously-skip-permissions";
    oc = "opencode";
    p = "pi";
  };
  source = path: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/users/maxpw/agents/${path}";
  piConfigSource = path: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/pi-config/${path}";
  piAgentsText =
    (builtins.readFile ../agents/shared/AGENTS.md)
    + "\n\n---\n\n"
    + (builtins.readFile ../agents/pi/AGENTS.md);

  globalSkills = [
    "mattpocock/skills@tdd"
    "mattpocock/skills@grill-me"
    "mattpocock/skills@improve-codebase-architecture"
    "mattpocock/skills@to-issues"
    "mattpocock/skills@diagnose"
    "obra/superpowers@verification-before-completion"
    "obra/superpowers@receiving-code-review"
    "vercel-labs/agent-skills@vercel-react-best-practices"
    "vercel-labs/skills@find-skills"
    "shadcn/improve"
  ];
in {
  home.packages = [
    pkgs.claude-code
    pkgs.codex
    pkgs.opencode
    pkgs.amp-cli
    pkgs.pi
    pkgs.skills
  ];

  home.file = {
    ".codex/AGENTS.md".source = source "shared/AGENTS.md";
    ".claude/CLAUDE.md".source = source "shared/AGENTS.md";
    ".config/opencode/AGENTS.md".source = source "shared/AGENTS.md";
    # Compose Pi context from shared cross-agent policy plus Pi-only guidance.
    ".pi/agent/AGENTS.md".text = piAgentsText;
    # Small Pi-specific system prompt nudge. Larger operating policy belongs in
    # the composed AGENTS.md above.
    ".pi/agent/APPEND_SYSTEM.md".source = piConfigSource "APPEND_SYSTEM.md";

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

    ".pi/agent/settings.json".source = piConfigSource "settings.json";
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
  };

  home.activation.installGlobalSkills = lib.hm.dag.entryAfter ["writeBoundary"] ''
    set -euo pipefail

    export PATH=${lib.makeBinPath [pkgs.git pkgs.openssh]}:$PATH
    export GIT_TERMINAL_PROMPT=0
    export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh"

    install_skill() {
      local skill="$1"
      local skill_name="''${skill##*@}"
      local shared_skill_path="$HOME/.agents/skills/$skill_name/SKILL.md"
      local claude_skill_path="$HOME/.claude/skills/$skill_name/SKILL.md"
      local pi_skill_path="$HOME/.pi/agent/skills/$skill_name/SKILL.md"

      if [ -e "$shared_skill_path" ] && [ -e "$claude_skill_path" ] && [ -e "$pi_skill_path" ]; then
        return 0
      fi

      if ! ${pkgs.skills}/bin/skills add "$skill" -g --agent claude-code pi codex amp -y 2>&1; then
        # Network fetch during activation; never abort the rebuild over it.
        echo "installGlobalSkills: warning: failed to install $skill (skipping)" >&2
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
