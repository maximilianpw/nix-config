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
    ];

    file = {
      ".config/amp/settings.json".source = source "amp/settings.json";
      ".codex/AGENTS.md".source = source "shared/AGENTS.md";
      ".claude/CLAUDE.md".source = source "shared/AGENTS.md";
      ".config/opencode/AGENTS.md".source = source "shared/AGENTS.md";
      ".pi/agent/AGENTS.md".source = source "shared/AGENTS.md";
      ".claude/settings.json".source = source "claude/settings.json";
      ".grok/config.toml" = {
        source = source "grok/config.toml";
        force = true;
      };

      # Pi is maintained in a separate repository and linked out of the Nix
      # store so extension development does not require a system rebuild.
      ".pi/agent/settings.json".source = piConfigSource "settings.json";
      ".pi/agent/models.json".source = piConfigSource "models.json";
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
  };
}
