{
  config,
  currentSystemUser,
  lib,
  ...
}: {
  # Required for some settings like homebrew to know what user to apply to.
  system.primaryUser = currentSystemUser;

  # The user should already exist, but we need to set this up so Nix knows
  # what our home directory is (https://github.com/LnL7/nix-darwin/issues/423).
  users.users.${currentSystemUser} = {
    home = "/Users/${currentSystemUser}";
    shell = config.custom.shells.login;
  };

  # The primary admin is intentionally not in users.knownUsers, so nix-darwin
  # does not update its macOS account record. Keep the login shell on the stable
  # system profile path instead of a versioned store or removed Homebrew path.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    /usr/bin/dscl . -create /Users/${currentSystemUser} UserShell /run/current-system/sw${config.custom.shells.login.shellPath}
  '';
}
