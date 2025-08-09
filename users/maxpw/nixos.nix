{
  config,
  pkgs,
  lib,
  ...
}: {
  # Shared system configuration across all hosts

  # Networking
  networking.networkmanager.enable = true;

  # Locale and timezone
  time.timeZone = lib.mkDefault "America/New_York";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  i18n.extraLocaleSettings = lib.mkDefault {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Hyprland replaces X11 GNOME stack; keep minimal XKB config via input method if needed.
  services.xserver.enable = false;
  services.printing.enable = false; # disable printing unless required

  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  users.users.maxpw = {
    isNormalUser = true;
    description = lib.mkDefault "Maximilian PINDER-WHITE";
    extraGroups = ["networkmanager" "wheel"];
    hashedPassword = "$6$rkBFUGv5LjTDnhTx$kka47zG6AOyu51sDL/M6mg.vmsMqlto.OS.dond5N2o5.1LkLRENxQPcSSEsm0444YAE85BN.H/rzjutypgm2/";
    home = "/home/maxpw";
  };

  programs.firefox.enable = true; # Still available under Wayland (uses MOZ_ENABLE_WAYLAND=1 by default in recent builds)
  nixpkgs.config.allowUnfree = true;

  services.openssh.enable = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];
  system.stateVersion = lib.mkDefault "25.05";
}
