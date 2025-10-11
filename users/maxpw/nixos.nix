{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [../../modules/desktop/hyprland.nix];
  # --- Base (yours) ---
  networking.networkmanager = {
    enable = true;
    plugins = with pkgs; [
      networkmanager-openvpn
    ];
  };
  # Timezone (France)
  time.timeZone = "Europe/Paris";
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

  # Default to disabling X if no desktop module overrides; GNOME module will set true.
  services.xserver.enable = lib.mkDefault false; # no X11 unless desktop enables it
  # Provide XKB layout info (used by Wayland compositors like Hyprland)
  services.xserver.xkb = {
    layout = "us";
    variant = "colemak"; # Colemak variant of US
  };
  services.printing.enable = false;

  hardware.graphics.enable = true;

  services.pulseaudio.enable = false;
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
    extraGroups = ["networkmanager" "wheel" "seat" "input" "video"];
    home = "/home/maxpw";
    hashedPassword = "$6$rkBFUGv5LjTDnhTx$kka47zG6AOyu51sDL/M6mg.vmsMqlto.OS.dond5N2o5.1LkLRENxQPcSSEsm0444YAE85BN.H/rzjutypgm2/";
  };

  programs.firefox.enable = true;
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    helium
  ];

  services.openssh = {
    enable = true;
    # If using keys, harden this:
    # settings.PasswordAuthentication = false;
    # settings.KbdInteractiveAuthentication = false;
    # settings.PermitRootLogin = "no";
  };

  # Keep the stateVersion at the initial install release; don't bump later.
  system.stateVersion = lib.mkDefault "24.05";

  # Console (TTY) keymap for Colemak
  console.keyMap = "colemak";

  services.dbus.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
    config.common.default = ["hyprland" "gtk"];
  };
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Disable command-not-found (doesn't work with flakes)
  programs.command-not-found.enable = false;
}
