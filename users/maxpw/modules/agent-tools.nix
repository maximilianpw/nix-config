{
  config,
  currentSystemUserDir,
  pkgs,
  lib,
  ...
}: let
  homeFiles = import ../../../lib/home-files.nix {
    inherit lib;
    mkOutOfStoreSymlink = config.lib.file.mkOutOfStoreSymlink;
  };

  agentAliases = {
    c = "codex --yolo";
    ccc = "DISABLE_ZOXIDE=1 claude --dangerously-skip-permissions";
    oc = "opencode";
    p = "pi";
  };
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
  piAgentsText =
    sharedAgentsText
    + "\n\n---\n\n"
    + (builtins.readFile ../agents/pi/AGENTS.md);
  sharedPromptClaudeLinks = {
    ".claude/commands/nix-config-health.md".source = source "shared/prompts/nix-config-health.md";
    ".claude/commands/prompt-debt-audit.md".source = source "shared/prompts/prompt-debt-audit.md";
  };

  # Shared skills are fixed-output Nix sources, so activation never fetches
  # mutable repository heads. Update rev and hash together when upgrading.
  mattSkills = pkgs.fetchFromGitHub {
    owner = "mattpocock";
    repo = "skills";
    rev = "d574778f94cf620fcc8ce741584093bc650a61d3";
    hash = "sha256-XqF709Y9GMKINzZITlbCTyatG9AxRZh0qn2vcv1Z8yo=";
  };
  superpowers = pkgs.fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = "d884ae04edebef577e82ff7c4e143debd0bbec99";
    hash = "sha256-kHdQ9e44doBk2yYW88tMSCqVG8ycYcvJSZlrIziXhpA=";
  };
  vercelAgentSkills = pkgs.fetchFromGitHub {
    owner = "vercel-labs";
    repo = "agent-skills";
    rev = "f8a72b9603728bb92a217a879b7e62e43ad76c81";
    hash = "sha256-LSFC0Zxc4Lgisu5/r6qBF1R0X36hePkVPfbvbx48YdY=";
  };
  vercelSkills = pkgs.fetchFromGitHub {
    owner = "vercel-labs";
    repo = "skills";
    rev = "4ce6d48ac44c8b637db87b2102fea3baca719df1";
    hash = "sha256-dMz4M7WAtjlKVrEePsPbS6v4EV6VpG5wBKUrysAIhYw=";
  };
  shadcnImprove = pkgs.fetchFromGitHub {
    owner = "shadcn";
    repo = "improve";
    rev = "03369ee6d7cafbfcecc4346539b05b3dc0a603bb";
    hash = "sha256-m0a1n8xguDI2nooJ856sWPofh+tZI5VvIrVZrQH6XgY=";
  };

  # Preserve the familiar local invocation names while following upstream's
  # renamed implementations.
  mkRenamedSkill = {
    source,
    path,
    upstreamName,
    localName,
  }:
    pkgs.runCommand "agent-skill-${localName}" {} ''
      cp -R "${source}/${path}" "$out"
      chmod -R u+w "$out"
      substituteInPlace "$out/SKILL.md" \
        --replace-fail "name: ${upstreamName}" "name: ${localName}"
    '';

  pinnedSkills = [
    {
      name = "tdd";
      source = "${mattSkills}/skills/engineering/tdd";
    }
    {
      name = "grill-me";
      source = "${mattSkills}/skills/productivity/grill-me";
    }
    {
      name = "improve-codebase-architecture";
      source = "${mattSkills}/skills/engineering/improve-codebase-architecture";
    }
    {
      name = "to-issues";
      source = mkRenamedSkill {
        source = mattSkills;
        path = "skills/engineering/to-tickets";
        upstreamName = "to-tickets";
        localName = "to-issues";
      };
    }
    {
      name = "diagnose";
      source = mkRenamedSkill {
        source = mattSkills;
        path = "skills/engineering/diagnosing-bugs";
        upstreamName = "diagnosing-bugs";
        localName = "diagnose";
      };
    }
    {
      name = "verification-before-completion";
      source = "${superpowers}/skills/verification-before-completion";
    }
    {
      name = "receiving-code-review";
      source = "${superpowers}/skills/receiving-code-review";
    }
    {
      name = "vercel-react-best-practices";
      source = "${vercelAgentSkills}/skills/react-best-practices";
    }
    {
      name = "find-skills";
      source = "${vercelSkills}/skills/find-skills";
    }
    {
      name = "improve";
      source = "${shadcnImprove}/skills/improve";
    }
  ];

  pinnedSkillFiles = lib.listToAttrs (lib.concatMap (skill:
    map (prefix: {
      name = "${prefix}/${skill.name}";
      value = {
        inherit (skill) source;
        force = true;
      };
    }) [
      ".agents/skills"
      ".claude/skills"
      ".pi/agent/skills"
    ])
  pinnedSkills);
in {
  home = {
    packages = [
      pkgs.claude-code
      pkgs.codex
      pkgs.opencode
      pkgs.amp-cli
      pkgs.pi
      pkgs.skills
    ];

    file =
      {
        ".codex/AGENTS.md".text = codexAgentsText;
        ".codex/prompts" = {
          source = source "shared/prompts";
          recursive = true;
        };
        ".codex/skills/add-fleet-host" = {
          source = source "codex/skills/add-fleet-host";
          recursive = true;
        };
        ".agents/prompts" = {
          source = source "shared/prompts";
          recursive = true;
        };
        ".claude/CLAUDE.md".text = claudeAgentsText;
        ".config/opencode/AGENTS.md".source = source "shared/AGENTS.md";
        # Compose Pi context from shared cross-agent policy plus Pi-only guidance.
        ".pi/agent/AGENTS.md".text = piAgentsText;
        # Small Pi-specific system prompt nudge. Larger operating policy belongs in
        # the composed AGENTS.md above.
        ".pi/agent/APPEND_SYSTEM.md".source = piConfigSource "APPEND_SYSTEM.md";

        ".claude/settings.json".source = source "claude/settings.json";
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
      }
      // sharedPromptClaudeLinks
      // pinnedSkillFiles;
  };

  programs = {
    bash.shellAliases = agentAliases;
    zsh.shellAliases = agentAliases;
    fish.shellAliases = agentAliases;
    nushell = {
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
  };
}
