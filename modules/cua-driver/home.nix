# Cua Driver drives a desktop session, so only desktop profiles import it.
# Agents on every host reach it through the `computer` MCP server in
# modules/agent-tools/home.nix.
{
  isDarwin,
  lib,
  pkgs,
  ...
}: let
  cuaDriverApp = "${pkgs.cua-driver}/Applications/CuaDriver.app";
in {
  home.packages = [pkgs.cua-driver];

  home.activation = lib.optionalAttrs isDarwin {
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
}
