{
  config,
  homeFiles,
  inputs,
  isDarwin,
  isWSL,
  pkgs,
  lib,
  ...
}: let
  source = path: homeFiles.mkRepoSource config.home.homeDirectory "users/maxpw/files/editable/agents/${path}";

  mcpServers = {
    # Joyce's real desktop: Cua Driver there, reached over SSH from other hosts.
    computer = {
      command = "fleet";
      args = ["computer" "joyce"];
    };
    executor.url = "https://executor.maximilian.pw/mcp";
  };
in {
  imports = [inputs.agent-tools.homeModules.default];

  agents = {
    # The overlay's builds, not llm-agents' own: some are re-signed for macOS.
    packageSet = pkgs;
    defaults = {
      instructions = source "shared/AGENTS.md";
      skills.sources = import ./skills.nix;
      inherit mcpServers;
    };

    amp = {
      enable = true;
      package = pkgs.amp-cli;
      files."settings.json" = source "amp/settings.json";
    };
    claude-code = {
      enable = true;
      # Pulls the shared policy in with an @-import of ~/.config/agent-policy.
      instructions = source "claude/CLAUDE.md";
      files = {
        "settings.json" = source "claude/settings.json";
        "rules/pstack-models.md" = source "claude/rules/pstack-models.md";
      };
    };
    codex = {
      enable = true;
      # Rendered at build time so the Codex-only part can be appended.
      instructions = ../../users/maxpw/files/editable/agents/shared/AGENTS.md;
      extraInstructions = builtins.readFile ../../users/maxpw/files/editable/agents/codex/AGENTS.md;
    };
    grok = {
      enable = true;
      files."config.toml" = {
        source = source "grok/config.toml";
        force = true;
      };
    };
    opencode = {
      enable = true;
      # modules/cliproxyapi/home.nix provides the `opencode` command.
      package = pkgs.opencode2;
    };
    pi = {
      enable = true;
      mcpServers = {
        computer =
          mcpServers.computer
          // {
            settings = {
              timeout = 60;
              # tool_search declares its tools when needed instead of every prompt carrying them.
              exposure = "deferred";
              description = "Inspect and operate native applications and browsers through Cua Driver, with screenshots, accessibility snapshots, exact-target input, and state verification.";
            };
          };
        executor =
          mcpServers.executor
          // {
            settings.description = "Remote executor MCP server; discover its current tool capabilities and instructions before use.";
          };
      };
      # Pi's configuration is its own repository, linked from the checkout so
      # extension development does not need a rebuild.
      configFrom = {
        path = "~/pi-config";
        fallback = pkgs.pi-config;
        # Pi keeps its model store under this name; the repository's copy
        # would make Pi write into the checkout.
        exclude = ["models-store.json"];
      };
    };
  };

  # Hosts without system-level sops decrypt the key through Home Manager sops;
  # modules/agent-tools/nixos.nix covers the others.
  sops.secrets.linear-api-key = lib.mkIf (isDarwin || isWSL) {mode = "0400";};

  home = {
    packages = [
      pkgs.cloudflared
      pkgs.executor
      pkgs.skills
    ];

    sessionVariables = {
      CFPASTE_PRIVATE_ORIGIN = "https://paste.maximilian.pw";
      CFPASTE_PUBLIC_ORIGIN = "https://p.maximilian.pw";
    };

    file = {
      # Claude's CLAUDE.md imports the shared policy from here.
      ".config/agent-policy/AGENTS.md".source = source "shared/AGENTS.md";
    };
  };
}
