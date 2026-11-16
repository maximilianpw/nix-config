# users/maxpw/files/managed is linked by Hjem from the store: rebuild to apply.
# users/maxpw/files/editable is linked out of store to the checkout (edits apply
# live) by Home Manager; each destination has exactly one owner.
#
# Hjem owns individual files, never whole directories: several of these apps
# write state, logs or sockets beside their config (e.g. ~/.config/herdr-app).
# Handoff and hazards are described in tests/hjem-lifecycle-fixture.sh.
{
  config,
  currentSystemUser,
  lib,
  ...
}: let
  home = config.users.users.${currentSystemUser}.home;

  managed = ../../users/maxpw/files/managed;

  # Every managed file is deployed at the same $HOME-relative path, except
  # tests that live beside the code they cover.
  paths = builtins.filter (path: !(lib.hasSuffix ".test.mjs" path)) (
    map (file: lib.removePrefix "${toString managed}/" (toString file)) (lib.filesystem.listFilesRecursive managed)
  );

  # Amp discovers plugins by scanning its plugin directory, so copy them as
  # real files; everything else is a read-only link into the store.
  isCopied = lib.hasPrefix ".config/amp/plugins/";

  hmTargets = map (file: file.target) (builtins.filter (file: file.enable) (builtins.attrValues config.home-manager.users.${currentSystemUser}.home.file));
  hjemTargets = builtins.attrNames config.hjem.users.${currentSystemUser}.files;
in {
  # One owner per destination: Home Manager (including the editable links in
  # modules/agent-tools/home.nix and modules/plannotator/home.nix) must not
  # also manage a path Hjem links.
  assertions = [
    {
      assertion = lib.intersectLists hmTargets hjemTargets == [];
      message = "Paths owned by both Hjem and Home Manager: ${toString (lib.intersectLists hmTargets hjemTargets)}";
    }
  ];

  hjem.users.${currentSystemUser} = {
    enable = true;
    directory = home;
    # Unmanaged files at a target are moved to `.backup-<name>`; never clobber.
    clobberFiles = false;

    files =
      lib.genAttrs paths (
        path:
          {
            # Preserve sibling paths after symlink resolution: Bun resolves the
            # Herdr backend's relative imports and executable bridge in the store.
            source =
              if lib.hasPrefix ".config/herdr-app/" path
              then "${managed + "/.config/herdr-app"}/${lib.removePrefix ".config/herdr-app/" path}"
              else managed + "/${path}";
          }
          // lib.optionalAttrs (isCopied path) {
            type = "copy";
            permissions = "644";
          }
      )
      // {
        ".config/glow/glow.yml".text = ''
          # Catppuccin Mocha Glamour style managed alongside this file.
          style: "${home}/.config/glow/catppuccin-mocha.json"
          mouse: false
          pager: false
          width: 80
          all: false
        '';
      };
  };
}
