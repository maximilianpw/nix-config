# Hjem-owned application files for hosts with `hjem = true` in lib/hosts.nix.
#
# Sources live under ./files at their $HOME-relative path. Hjem owns individual
# files, never whole directories: several of these apps write state, logs or
# sockets beside their config (e.g. ~/.config/herdr). Each path deployed here
# must also be in the host's .chezmoiignore block, so exactly one tool owns it. See
# docs/nixvim-hjem-ledger.md for the ownership ledger and recovery procedure.
{
  config,
  currentSystemUser,
  lib,
  ...
}: let
  home = config.users.users.${currentSystemUser}.home;

  # Every file under ./files is deployed at the same $HOME-relative path.
  paths = map (file: lib.removePrefix "${toString ./files}/" (toString file)) (lib.filesystem.listFilesRecursive ./files);
  # Amp discovers plugins by scanning its plugin directory; copy them as real
  # files rather than relying on it to follow symlinks. Everything else is a
  # read-only link into the store.
  isCopied = lib.hasPrefix ".config/amp/plugins/";

  hmTargets = map (file: file.target) (builtins.filter (file: file.enable) (builtins.attrValues config.home-manager.users.${currentSystemUser}.home.file));
  hjemTargets = builtins.attrNames config.hjem.users.${currentSystemUser}.files;
in {
  # One owner per destination: Home Manager (including the writable links in
  # modules/app-config.nix) must not also manage a path Hjem links.
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
          {source = ./files + "/${path}";}
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
