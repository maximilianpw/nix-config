{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../modules/core/nix-settings.nix
  ];

  # Set in Sept 2024 as part of the macOS Sequoia release.
  system.stateVersion = 6;

  # This makes it work with the Determinate Nix installer
  ids.gids.nixbld = 30000;

  nix = {
    # We use the determinate-nix installer which manages Nix for us,
    # so we don't want nix-darwin to do it.
    enable = false;

    # Enable the Linux builder so we can run Linux builds on our Mac.
    # This can be debugged by running `sudo ssh linux-builder`
    linux-builder = {
      enable = false;
      ephemeral = true;
      maxJobs = 4;
      config = {pkgs, ...}: {
        # Make our builder beefier since we're on a beefy machine.
        virtualisation = {
          cores = 6;
          darwin-builder = {
            diskSize = 50 * 1024; # 50GB
            memorySize = 16 * 1024; # 16GB
          };
        };

        # Add some common debugging tools we can see whats up.
        environment.systemPackages = [
          pkgs.htop
        ];
      };
    };

    settings = {
      trusted-users = ["@admin" "root" "max-vev"];
    };
  };

  # zsh is the default shell on Mac and we want to make sure that we're
  # configuring the rc correctly with nix-darwin paths.
  programs.zsh.enable = true;

  environment.shells = [pkgs.bashInteractive pkgs.zsh];
  environment.systemPackages = [
    pkgs.cachix
  ];
}
