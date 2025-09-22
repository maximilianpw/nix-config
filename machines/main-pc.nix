{
  config,
  pkgs,
  lib,
  ...
}: let
  withOptional = pkg:
    if pkg == null
    then []
    else [pkg];
  optionalPkg = attrPath: let
    pkg = lib.attrsets.attrByPath attrPath null pkgs;
  in
    withOptional pkg;
  optionalTopLevel = name:
    optionalPkg [name];
  optionalNested = attrPath:
    optionalPkg attrPath;
in {
  imports = [
    ./hardware/main-pc.nix
  ];

  # Core system identity
  networking.hostName = "main-pc";

  # Firmware & performance tuning for Ryzen
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";
  services.power-profiles-daemon.enable = lib.mkDefault true;

  # Modern kernel & AMD tuning
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    kernelParams = ["amd_pstate=guided"];
    loader = {
      systemd-boot.enable = lib.mkDefault true;
      efi.canTouchEfiVariables = lib.mkDefault true;
      grub.enable = lib.mkDefault false;
    };
  };

  # Hardware enablement for a desktop workstation
  services = {
    fwupd.enable = true;
    blueman.enable = true;
  };
  hardware.bluetooth.enable = true;

  # Container & virtualization stack
  virtualisation = {
    docker.enable = true;
    libvirtd.enable = true;
  };
  programs.virt-manager.enable = true;
  users.users.maxpw.extraGroups = lib.mkAfter ["docker" "libvirtd" "kvm"];

  # System-scoped packages mirroring software managed by Homebrew on macOS.
  # Each package is added only if it exists in the pinned nixpkgs to keep evaluation stable.
  environment.systemPackages = let
    base = with pkgs; [
      cachix
      lm_sensors
      pciutils
      usbutils
    ];
  in
    base
    ++ optionalTopLevel "_1password-gui"
    ++ optionalTopLevel "google-chrome"
    ++ optionalTopLevel "discord"
    ++ optionalTopLevel "postman"
    ++ optionalTopLevel "slack"
    ++ optionalTopLevel "mongodb-compass"
    ++ optionalTopLevel "ghostty"
    ++ optionalTopLevel "vscode"
    ++ optionalTopLevel "protonmail-bridge"
    ++ optionalTopLevel "protonvpn-gui"
    ++ optionalTopLevel "aws-vpn-client"
    ++ optionalTopLevel "termius"
    ++ optionalTopLevel "whatsapp-for-linux"
    ++ optionalTopLevel "figma-linux"
    ++ optionalTopLevel "zen-browser"
    ++ optionalNested ["jetbrains" "webstorm"];
}
