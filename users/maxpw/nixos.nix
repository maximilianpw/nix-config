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
    ./modules/linux-common.nix
  ];
  # --- Base (yours) ---
  networking.networkmanager = {
    enable = true;
    dns = "systemd-resolved";
    plugins = [
      pkgs.networkmanager-openvpn
    ];
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
    shell = pkgs.fish;
    # Password is managed via sops-nix (see secrets/README.md)
    hashedPasswordFile = config.sops.secrets.maxpw-password.path;
  };

  services.resolved.enable = true;

  # 3) Ensure /etc/resolv.conf points at resolved's stub
  networking.resolvconf.enable = lib.mkForce false;

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
}
