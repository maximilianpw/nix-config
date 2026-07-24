{pkgs, ...}: {
  networking = {
    hostName = "joyce";
    computerName = "joyce";
  };

  # Note: ../modules/core/nix-settings.nix is intentionally NOT imported here.
  # With `nix.enable = false` (Determinate manages the daemon), nix-darwin
  # ignores `nix.settings`, so caches/trusted-users must go through
  # Determinate's /etc/nix/nix.custom.conf instead (see environment.etc below).

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
  };

  # Determinate Nix includes this file from its generated /etc/nix/nix.conf.
  # This is the only way to get settings into the daemon while nix.enable = false.
  # One-time migration: if activation complains the file already exists, run
  #   sudo mv /etc/nix/nix.custom.conf /etc/nix/nix.custom.conf.before-nix-darwin
  environment.etc."nix/nix.custom.conf".text = ''
    trusted-users = root max-vev
    extra-substituters = https://devenv.cachix.org https://maximilianpw.cachix.org https://cache.numtide.com
    extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw= maximilianpw.cachix.org-1:RgUBJCLYTHNEeg67Pht2cf6VGG2NQnyxmn6jTCU+TsA= niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=
  '';

  # zsh is the default shell on Mac and we want to make sure that we're
  # configuring the rc correctly with nix-darwin paths.
  programs.zsh.enable = true;

  environment.systemPackages = [
    pkgs.cachix
  ];
}
