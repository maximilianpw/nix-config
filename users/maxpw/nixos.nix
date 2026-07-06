{
  config,
  pkgs,
  lib,
  currentSystemUser,
  isLinuxDesktop,
  ...
}: let
  settings = import ./settings.nix {inherit pkgs;};
  loginShellPath = lib.getExe settings.loginShell;
in {
  imports = [
    ../../modules/core/nix-settings.nix
    ../../modules/fleet/nixos.nix
    ../../modules/core/security.nix
    ../../modules/core/sops.nix
    ../../modules/core/shells.nix
    ../../modules/desktop/hyprland.nix
    ./modules/linux-common.nix
  ];

  custom.hyprland.enable = lib.mkDefault isLinuxDesktop;
  # --- Base (yours) ---
  networking.networkmanager = {
    enable = true;
    dns = "systemd-resolved";
    plugins = [
      pkgs.networkmanager-openvpn
    ];
  };

  hardware.graphics.enable = lib.mkDefault isLinuxDesktop;

  services = {
    # Default to disabling X if no desktop module overrides; GNOME module will set true.
    xserver = {
      enable = lib.mkDefault false; # no X11 unless desktop enables it
      # Provide XKB layout info (used by Wayland compositors like Hyprland)
      xkb = {
        layout = "us";
        variant = "colemak"; # Colemak variant of US
      };
    };
    printing.enable = false;

    pulseaudio.enable = false;
    pipewire = lib.mkIf isLinuxDesktop {
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

    resolved.enable = true;
    ollama.enable = true;
    dbus.enable = true;
  };

  users = {
    defaultUserShell = settings.loginShell;

    users.${currentSystemUser} = {
      isNormalUser = true;
      description = lib.mkDefault "Maximilian PINDER-WHITE";
      extraGroups = ["networkmanager" "wheel"] ++ lib.optionals isLinuxDesktop ["seat" "input" "video"];
      home = "/home/${currentSystemUser}";
      shell = settings.loginShell;
      openssh.authorizedKeys.keys = [
        settings.sshKeys.mainPcUser
        settings.sshKeys.fleetMacbookToMainPc
      ];
      # Password is managed via sops-nix (see secrets/README.md)
      hashedPasswordFile = config.sops.secrets.maxpw-password.path;
    };
  };

  system.activationScripts.ensureUserLoginShell = {
    deps = ["users"];
    # mutableUsers can preserve a stale passwd shell across rebuilds.
    text = ''
      ${pkgs.shadow}/bin/usermod --shell ${loginShellPath} ${lib.escapeShellArg currentSystemUser}
    '';
  };

  # 3) Ensure /etc/resolv.conf points at resolved's stub
  networking.resolvconf.enable = lib.mkForce false;

  environment = {
    systemPackages = lib.optionals isLinuxDesktop [
      pkgs.helium
    ];

    # Allow Helium (Chromium fork) to talk to the 1Password desktop app via
    # native messaging. 1Password verifies browsers against a built-in list
    # plus this file; it must be owned by root with mode 0755 or it's ignored.
    etc = lib.mkIf isLinuxDesktop {
      "1password/custom_allowed_browsers" = {
        text = ''
          helium
          .helium-wrapped
        '';
        mode = "0755";
      };
    };

    sessionVariables = lib.mkIf isLinuxDesktop {
      NIXOS_OZONE_WL = "1";
    };
  };

  # Keep the stateVersion at the initial install release; don't bump later.
  system.stateVersion = lib.mkDefault "24.05";

  # Console (TTY) keymap for Colemak
  console.keyMap = "colemak";

  # The op CLI is useful headless too; only the GUI is desktop-gated.
  programs._1password.enable = true;
  programs._1password-gui = lib.mkIf isLinuxDesktop {
    enable = true;
    polkitPolicyOwners = [currentSystemUser];
  };

  xdg.portal = lib.mkIf isLinuxDesktop {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
    config.common.default = ["hyprland" "gtk"];
  };
}
