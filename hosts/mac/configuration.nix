{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
  ];

  # VMware Fusion specific configuration for ARM64
  # Note: Traditional VMware guest tools are not available on ARM64
  # Using open-vm-tools package instead (defined in systemPackages)

  # VMware Fusion ARM optimizations for Linux LTS
  boot.kernelParams = [
    "elevator=mq-deadline" # Better I/O scheduler for modern kernels on ARM64
    "transparent_hugepage=madvise" # More conservative memory management for ARM64
    # "clocksource=tsc"      # TSC may not be available on ARM64, let kernel choose
    "mitigations=auto" # Enable security mitigations appropriate for platform
  ];

  # Bootloader.
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev"; # Indicates not to install to a specific device, as it's UEFI
    useOSProber = true; # To detect other OSes like Windows
  };
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # VMware network optimizations
  networking.interfaces = {
    # VMware typically uses ens160 or similar
    ens160.useDHCP = true;
  };

  # Set your time zone.
  time.timeZone = "Europe/Paris";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fr_FR.UTF-8";
    LC_IDENTIFICATION = "fr_FR.UTF-8";
    LC_MEASUREMENT = "fr_FR.UTF-8";
    LC_MONETARY = "fr_FR.UTF-8";
    LC_NAME = "fr_FR.UTF-8";
    LC_NUMERIC = "fr_FR.UTF-8";
    LC_PAPER = "fr_FR.UTF-8";
    LC_TELEPHONE = "fr_FR.UTF-8";
    LC_TIME = "fr_FR.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # VMware Fusion optimized graphics (ARM64 compatible)
  services.xserver.videoDrivers = ["fbdev" "vesa"];
  hardware.opengl = {
    enable = true;
    driSupport = true;
    # Note: driSupport32Bit is not available on ARM64
  };

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver = {
    layout = "us";
    xkbVariant = "colemak";
  };

  #fonts
  fonts = {
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      liberation_ttf
      fira-code
      fira-code-symbols
      mplus-outline-fonts.githubRelease
      dina-font
      proggyfonts
      # Support Nerd Fonts from Home Manager
      (nerdfonts.override {fonts = ["FiraCode" "JetBrainsMono" "Hack"];})
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = ["FiraCode"];
        sansSerif = ["FiraCode"];
        monospace = ["FiraCode Nerd Font"];
      };
    };
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire (ARM64 compatible)
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    # Note: 32-bit ALSA support not needed on ARM64
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.maxpw = {
    isNormalUser = true;
    description = "Maximilian Pinder-White";
    extraGroups = ["networkmanager" "wheel"];
    packages = with pkgs; [
      firefox
    ];
  };

  home-manager = {
    extraSpecialArgs = {inherit inputs;};
    users = {
      "maxpw" = import ./home.nix;
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    alejandra
    git
    gh
    neofetch
    rustup
    vscode
    # Note: 1Password apps may not be available on ARM64 Linux
    # _1password_cli  # Check availability
    # _1password-gui  # Check availability
    # Note: Ghostty may not be available on ARM64 Linux
    # ghostty  # Check availability
    # VMware Fusion specific tools (ARM64 compatible)
    open-vm-tools
    # Support for Home Manager dotfiles
    zsh
    # Additional ARM64-friendly alternatives
    firefox
  ];

  # Enable zsh system-wide to support Home Manager zsh config
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  nix.settings.experimental-features = ["nix-command" "flakes"];
  system.stateVersion = "23.11"; # Did you read the comment?
}
