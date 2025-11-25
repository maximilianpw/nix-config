{
  pkgs,
  currentSystemUser,
  ...
}: {
  imports = [
    ../modules/core/nix-settings.nix
  ];

  wsl = {
    enable = true;
    wslConf.automount.root = "/mnt";
    defaultUser = currentSystemUser;
    startMenuLaunchers = true;
  };

  nix.package = pkgs.nixUnstable;

  system.stateVersion = "24.05";
}
