# App-written config files, linked straight to the nix-config checkout
# (users/maxpw/app-config) instead of the Nix store. The apps rewrite these
# files, so a read-only store link would break them. Writing through the link
# edits the checkout, and `git diff` shows the app's changes for review.
#
# Hjem owns the static files (users/maxpw/hjem); this module owns only these
# writable ones, and the Hjem module asserts that no path has both owners.
# Applies to hosts migrated off chezmoi (`hjem = true` in lib/hosts.nix), whose
# .chezmoiignore excludes the same paths. Contents are not pinned by a Nix
# generation: recovery is from Git. If an app replaces the link with a regular
# file when it saves, take that file out of this list rather than fighting it.
{
  config,
  currentSystemUserDir,
  hostRecord,
  isDarwin,
  lib,
  ...
}: let
  homeFiles = import ../../../lib/home-files.nix {
    inherit lib;
    inherit (config.lib.file) mkOutOfStoreSymlink;
  };

  shared = [
    ".cursor/permissions.json"
    ".cursor/sandbox.json"
    ".plannotator/config.json"
  ];
  darwinOnly = [
    "Library/Application Support/Cursor/User/keybindings.json"
    "Library/Application Support/Cursor/User/settings.json"
  ];
in
  lib.mkIf hostRecord.hjem {
    home.file = lib.genAttrs (shared ++ lib.optionals isDarwin darwinOnly) (path: {
      source = homeFiles.mkRepoSource config.home.homeDirectory "users/${currentSystemUserDir}/app-config/${path}";
    });
  }
