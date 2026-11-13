{inputs, ...}: {
  imports = [inputs.stylix.homeModules.stylix];

  stylix = {
    enable = true;
    autoEnable = false;
    # home-manager.useGlobalPkgs ignores HM-level nixpkgs.overlays, and
    # stylix's package overlays (on by default) trip HM's nixpkgs deprecation
    # warning on every profile.
    overlays.enable = false;
    base16Scheme = "${inputs.stylix.inputs.tinted-schemes}/base16/gruvbox-material-dark-hard.yaml";
    targets.ghostty.enable = true;
    targets.waybar.enable = true;
  };
}
