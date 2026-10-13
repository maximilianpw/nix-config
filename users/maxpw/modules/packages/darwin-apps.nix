# macOS GUI apps installed from Nix rather than Homebrew. Normally only
# self-contained, notarized bundles qualify; T3's upstream source-built bundle
# is an explicit exception. No installer, privileged helper, system extension,
# or self-update may rewrite the bundle. Everything else stays a Homebrew cask
# in users/maxpw/darwin.nix. Hjem's link-nix-apps agent exposes these in
# ~/Applications/Nix User Apps (users/maxpw/hjem/darwin.nix).
#
# Moving an app off Homebrew: install it here first and verify it, then run
# `brew uninstall --cask <app>` (no --zap) before deleting the cask line.
# Homebrew cleanup is "zap", so removing the line while the cask is still
# installed would delete the app's settings and data.
{
  isDarwin,
  lib,
  pkgs,
  ...
}: {
  home.packages = lib.optionals isDarwin [
    pkgs.obsidian
    # Upstream splits the CLI and desktop; keep both available on Joyce.
    pkgs.t3code
    pkgs.t3code-desktop
  ];
}
