{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../modules/core/nix-settings.nix
    ../../modules/core/security.nix
    ../../modules/core/sops.nix
    ../../modules/desktop/hyprland.nix
  ];
  # --- Base (yours) ---
  networking.networkmanager = {
    enable = true;
    plugins = [
      pkgs.networkmanager-openvpn
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

  # to download binaries that usually download to /bin
  programs.nix-ld = {
    enable = true;
    libraries = [
      # Common libraries that bun/node tools often need
      pkgs.stdenv.cc.cc
      pkgs.zlib
      pkgs.fuse3
      pkgs.icu
      pkgs.nss
      pkgs.openssl
      pkgs.curl
      pkgs.expat
    ];
  };

  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    extraConfig.pipewire."99-high-res" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.allowed-rates" = [44100 48000 88200 96000 176400 192000 352800 384000];
      };
    };
  };

  users.users.maxpw = {
    isNormalUser = true;
    description = lib.mkDefault "Maximilian PINDER-WHITE";
    extraGroups = ["networkmanager" "wheel" "seat" "input" "video"];
    home = "/home/maxpw";
    # Password is managed via sops-nix (see secrets/README.md)
    hashedPasswordFile = config.sops.secrets.maxpw-password.path;
  };

  # used for music
  services.roon-server = {
    enable = true;
    openFirewall = true; # opens the usual LAN ports for discovery/control
  };

  networking.firewall.allowedTCPPorts = [
    55000
  ];

  environment.systemPackages = [
    pkgs.helium
  ];

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

  # Disable command-not-found (doesn't work with flakes)
  programs.command-not-found.enable = false;
}
