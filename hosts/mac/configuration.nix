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

  # VMware Fusion specific configuration
  virtualisation.vmware.guest.enable = true;
  
  # VMware services for better integration
  services.vmware-guest = {
    enable = true;
    headless = false;  # Set to true if running headless
  };
  
  # VMware Fusion ARM optimizations
  boot.kernelParams = [
    "elevator=noop"        # Better I/O scheduler for VMs
    "transparent_hugepage=never"  # Better memory management in VMware
    "clocksource=tsc"      # Better timekeeping in VMware
    "nohz=off"            # Disable tickless kernel for better VMware performance
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
  
  # VMware Fusion network optimizations
  networking.interfaces = {
    # VMware typically uses ens160 or similar
    ens160.useDHCP = true;
  };
  
  # Enable VMware shared folders (if needed)
  fileSystems."/mnt/hgfs" = {
    device = ".host:/";
    fsType = "fuse./usr/bin/vmhgfs-fuse";
    options = [ 
      "umask=22,uid=1000,gid=1000,allow_other,auto_unmount,defaults"
    ];
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
  
  # VMware Fusion optimized graphics
  services.xserver.videoDrivers = ["vmware" "fbdev" "vesa"];
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
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
    ];
    fontconfig = {
      defaultFonts = {
        serif = ["FiraCode"];
        sansSerif = ["FiraCode"];
        monospace = ["FiraCode"];
      };
    };
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.maxpw = {
    isNormalUser = true;
    description = "Maximilian Pinder-White";
    extraGroups = ["networkmanager" "wheel"];
    packages = with pkgs; [
      firefox
      discord
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
  environment.systemPackages = with pkgs; [
    alejandra
    git
    gh
    neofetch
    rustup
    vscode
    _1password_cli
    _1password-gui
    ghostty
    # VMware Fusion specific tools
    open-vm-tools
    xf86-input-vmmouse
    xf86-video-vmware
  ];

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
