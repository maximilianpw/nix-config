{
  config,
  pkgs,
  lib,
  ...
}: {
  # Common system configuration shared across all hosts
  
  # Networking
  networking.networkmanager.enable = true;
  
  # Time zone and locale
  time.timeZone = "Europe/Paris";
  
  i18n = {
    defaultLocale = "en_GB.UTF-8";
    extraLocaleSettings = {
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
  };
  
  # Audio configuration
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = lib.mkDefault true; # Can be overridden for ARM64
    pulse.enable = true;
  };
  
  # Desktop Environment
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
    xkb = {
      layout = "us";
      variant = "colemak";
    };
  };
  
  # Enable CUPS printing
  services.printing.enable = true;
  
  # User configuration
  users.users.maxpw = {
    isNormalUser = true;
    description = "Maximilian Pinder-White";
    extraGroups = ["networkmanager" "wheel"];
    shell = pkgs.zsh;
  };
  
  # Home Manager configuration
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {inherit config;};
    users.maxpw = import ../../modules/home-manager/dotfiles.nix;
  };
  
  # System packages
  environment.systemPackages = with pkgs; [
    alejandra
    git
    gh
    neofetch
    curl
    wget
    vim
  ];
  
  # Programs
  programs = {
    neovim = {
      enable = true;
      defaultEditor = true;
    };
    zsh.enable = true;
  };
  
  # Nix configuration
  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = true;
      trusted-users = ["root" "@wheel"];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
  
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  
  # Security improvements
  security = {
    sudo.wheelNeedsPassword = false; # For convenience in VMs
    polkit.enable = true;
  };
  
  # Performance tuning for VMs
  services.fstrim.enable = true; # SSD optimization
  
  system.stateVersion = "23.11";
}
