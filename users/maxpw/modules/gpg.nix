# GPG and gpg-agent configuration
{
  isDarwin,
  isLinuxDesktop,
  pkgs,
  lib,
  ...
}: let
  isLinux = pkgs.stdenv.isLinux;
in {
  # Nix owns GnuPG on Linux. On Darwin the binaries and pinentry-mac are
  # intentionally owned together by Homebrew in darwin.nix.
  programs.gpg.enable = !isDarwin;

  services.gpg-agent = lib.mkIf isLinux {
    enable = true;
    pinentry.package =
      if isLinuxDesktop
      then pkgs.pinentry-gnome3
      else pkgs.pinentry-curses;

    # cache the keys forever so we don't get asked for a password
    defaultCacheTtl = 31536000;
    maxCacheTtl = 31536000;
  };

  # Keep only the user-level agent policy in Home Manager on macOS.
  home.file.".gnupg/gpg-agent.conf" = lib.mkIf isDarwin {
    text = ''
      pinentry-program /opt/homebrew/bin/pinentry-mac
      default-cache-ttl 31536000
      max-cache-ttl 31536000
    '';
  };
}
