# GPG and gpg-agent configuration
{
  isDarwin,
  isWSL ? false,
  ...
}: {
  pkgs,
  lib,
  ...
}: let
  isLinux = pkgs.stdenv.isLinux;
in {
  programs.gpg.enable = !isDarwin;

  services.gpg-agent = lib.mkIf isLinux {
    enable = true;
    pinentry.package =
      if isWSL
      then pkgs.pinentry-curses
      else pkgs.pinentry-gnome3;

    # cache the keys forever so we don't get asked for a password
    defaultCacheTtl = 31536000;
    maxCacheTtl = 31536000;
  };
}
