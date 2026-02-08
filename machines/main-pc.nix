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
    kernelParams = [
      "amd_pstate=guided"
      "mem_sleep_default=deep" # Force S3 deep sleep instead of s2idle
    ];
    loader = {
      systemd-boot.enable = lib.mkDefault true;
      efi.canTouchEfiVariables = lib.mkDefault true;
      grub.enable = lib.mkDefault false;
    };
  };

  # Sleep/suspend configuration
  systemd.sleep.extraConfig = ''
    AllowSuspend=yes
    AllowHibernation=yes
    AllowHybridSleep=yes
    SuspendMode=suspend
    SuspendState=mem
  '';

  # Disable wakeup sources to prevent immediate wake from sleep
  services.udev.extraRules = ''
    # Disable wakeup on ALL USB devices and controllers
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/wakeup}="disabled"
    ACTION=="add", SUBSYSTEM=="pci", DRIVER=="xhci_hcd", ATTR{power/wakeup}="disabled"
    # Disable wakeup on network interfaces
    ACTION=="add", SUBSYSTEM=="net", KERNEL=="enp*", RUN+="${pkgs.bash}/bin/bash -c 'echo disabled > /sys/class/net/%k/device/power/wakeup'"
  '';

  # Disable spurious GPE ACPI wakeups (common AMD Ryzen issue)
  systemd.services.disable-gpe-wakeup = {
    description = "Disable spurious GPE ACPI wakeups";
    wantedBy = ["multi-user.target"];
    serviceConfig.Type = "oneshot";
    script = ''
      for gpe in /sys/firmware/acpi/interrupts/gpe*; do
        echo "disable" > "$gpe" 2>/dev/null || true
      done
      # Re-enable power button wake
      if [ -f /proc/acpi/wakeup ]; then
        for dev in PWRB PWBN; do
          status=$(grep "^$dev" /proc/acpi/wakeup 2>/dev/null | awk '{print $3}')
          if [ "$status" = "*disabled" ]; then
            echo "$dev" > /proc/acpi/wakeup
          fi
        done
      fi
    '';
  };

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
