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
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  cuaDriverApp = "${pkgs.cua-driver}/Applications/CuaDriver.app";
in {
  home = {
    packages = [
      pkgs.claude-code
      pkgs.codex
      pkgs.cua-driver
      pkgs.opencode
      pkgs.grok
      pkgs.herdr
      pkgs.amp-cli
      pkgs.pi
      pkgs.skills
    ];

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
              rm -rf "$backup_app"
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
      ".pi/agent/mcp.json".source = piConfigSource "mcp.json";
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
