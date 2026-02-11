{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./hardware/main-pc.nix
    ../modules/services/backup.nix
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
    kernelModules = ["amd_pmc"];
    kernelParams = [
      "amd_pstate=guided"
      "resume=UUID=ba998885-222e-4dd5-963a-895933322128"
    ];
    resumeDevice = "/dev/disk/by-uuid/ba998885-222e-4dd5-963a-895933322128";
    loader = {
      systemd-boot.enable = lib.mkDefault true;
      efi.canTouchEfiVariables = lib.mkDefault true;
      grub.enable = lib.mkDefault false;
    };
  };

  # Use hibernate instead of suspend (Beelink SER9 has broken s2idle firmware)
  systemd.sleep.extraConfig = ''
    AllowSuspend=yes
    AllowHibernation=yes
    AllowHybridSleep=yes
    SuspendState=disk
    HibernateMode=shutdown
  '';

  # Restore networking and USB audio after hibernate resume
  systemd.services.network-resume = {
    description = "Restore services after hibernate";
    wantedBy = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
    after = ["systemd-suspend.service" "systemd-hibernate.service" "systemd-hybrid-sleep.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.kmod}/bin/modprobe -r snd_usb_audio && ${pkgs.kmod}/bin/modprobe snd_usb_audio && ${pkgs.systemd}/bin/systemctl restart NetworkManager && ${pkgs.systemd}/bin/systemctl restart mullvad-daemon'";
    };
  };

  # Disable Intel WiFi power saving to prevent connectivity loss after suspend
  boot.extraModprobeConfig = ''
    options iwlwifi power_save=0
    options iwlmvm power_scheme=1
  '';

  # Hardware enablement for a desktop workstation
  services = {
    fwupd.enable = true;
    blueman.enable = true;
    mullvad-vpn.enable = true;
  };
  hardware.bluetooth.enable = true;

  # Container & virtualization stack
  virtualisation = {
    docker.enable = true;
    libvirtd.enable = true;
  };
  programs.virt-manager.enable = true;
  users.users.maxpw.extraGroups = lib.mkAfter ["docker" "libvirtd" "kvm"];

  # System-scoped packages
  environment.systemPackages = [
    pkgs.cachix
    pkgs.lm_sensors
    pkgs.pciutils
    pkgs.usbutils
  ];
}
