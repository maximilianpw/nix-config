{
  pkgs,
  lib,
  isWSL ? false,
  ...
}: let
  isLinux = pkgs.stdenv.isLinux && !isWSL;
in {
  programs.nushell.plugins = with pkgs.nushellPlugins;
    [
      gstat
      query
      skim
      hcl
      semver
    ]
    ++ lib.optionals isLinux [
      desktop_notifications
    ];
}
