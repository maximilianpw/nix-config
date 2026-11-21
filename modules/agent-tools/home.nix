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
  cuaDriverApp = "${pkgs.cua-driver}/Applications/CuaDriver.app";
in {
  imports = [inputs.agent-tools.homeModules.default];

  agents = {
    # The overlay's builds, not llm-agents' own: some are re-signed for macOS.
    packageSet = pkgs;
    defaults = {
      instructions = source "shared/AGENTS.md";
      skills.sources = import ./skills.nix;
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
      # Pi's configuration is its own repository, linked from the checkout so
      # extension development does not need a rebuild.
      configFrom = {
        path = "~/pi-config";
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
      pkgs.cua-driver
      pkgs.executor
      pkgs.skills
    ];

    sessionVariables = {
      CFPASTE_PRIVATE_ORIGIN = "https://paste.maximilian.pw";
      CFPASTE_PUBLIC_ORIGIN = "https://p.maximilian.pw";
    };

    activation = lib.optionalAttrs isDarwin {
      # Cua Driver must be a real, stable /Applications bundle: its MCP mode
      # relaunches through LaunchServices, and macOS keys Accessibility and
      # Screen Recording grants to the signed app identity. A store symlink is
      # insufficient, so install the untouched upstream-signed bundle here.
      installCuaDriverApp = lib.hm.dag.entryAfter ["writeBoundary"] ''
        source_app="${cuaDriverApp}"
        target_app="/Applications/CuaDriver.app"
        desired_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$source_app/Contents/Info.plist")
        current_version=""
        if [ -e "$target_app/Contents/Info.plist" ]; then
          current_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$target_app/Contents/Info.plist" 2>/dev/null || true)
        fi

        if [ "$current_version" != "$desired_version" ]; then
          if [ -n "''${DRY_RUN_CMD:-}" ]; then
            echo "Would install CuaDriver.app $desired_version at $target_app"
          elif [ ! -w /Applications ]; then
            echo "Cannot install CuaDriver.app: /Applications is not writable." >&2
            exit 1
          else
            staged_app="/Applications/.CuaDriver.app.home-manager-new-$$"
            backup_app="/Applications/.CuaDriver.app.home-manager-backup-$$"
            rm -rf "$staged_app" "$backup_app"
            /usr/bin/ditto "$source_app" "$staged_app"
            /usr/bin/codesign --verify --deep --strict "$staged_app"

            # Stop an older daemon before replacing the executable it mapped.
            /usr/bin/pkill -x cua-driver 2>/dev/null || true

            had_previous=0
            if [ -e "$target_app" ]; then
              mv "$target_app" "$backup_app"
              had_previous=1
            fi
            if mv "$staged_app" "$target_app"; then
              # ditto preserves the store bundle's read-only directory modes.
              # Make the retired copy removable without touching the signed live app.
              if [ "$had_previous" = 1 ]; then
                chmod -R u+w "$backup_app"
                rm -rf "$backup_app"
              fi
            else
              if [ "$had_previous" = 1 ]; then
                mv "$backup_app" "$target_app"
              fi
              exit 1
            fi

            /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
              -f "$target_app"
            echo "Installed CuaDriver.app $desired_version at $target_app"
          fi
        fi
      '';
    };

    file = {
      # Claude's CLAUDE.md imports the shared policy from here.
      ".config/agent-policy/AGENTS.md".source = source "shared/AGENTS.md";
    };
  };
}
