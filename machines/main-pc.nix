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
      "mem_sleep_default=s2idle"
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
    SuspendState=freeze
  '';

  # Disable wakeup sources to prevent immediate wake from sleep
  services.udev.extraRules = ''
    # Disable wakeup on ALL USB devices and controllers
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/wakeup}="disabled"
    ACTION=="add", SUBSYSTEM=="pci", DRIVER=="xhci_hcd", ATTR{power/wakeup}="disabled"
    # Specifically disable wakeup on Intel AX200 Bluetooth
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0029", ATTR{power/wakeup}="disabled"
    # Disable wakeup on network interfaces
    ACTION=="add", SUBSYSTEM=="net", KERNEL=="enp*", RUN+="${pkgs.bash}/bin/bash -c 'echo disabled > /sys/class/net/%k/device/power/wakeup'"
  '';

  # Disable spurious GPE ACPI wakeups (common AMD Ryzen issue)
  systemd.services.disable-gpe-wakeup = {
    description = "Disable spurious GPE ACPI wakeups";
    wantedBy = ["multi-user.target"];
    path = [pkgs.gawk pkgs.gnugrep];
    serviceConfig.Type = "oneshot";
    script = ''
      for gpe in /sys/firmware/acpi/interrupts/gpe*; do
        echo "disable" > "$gpe" 2>/dev/null || true
      done
      # Disable ACPI wakeup devices that cause spurious wakes
      if [ -f /proc/acpi/wakeup ]; then
        for dev in GPP0 GPP1 GPP3 GPP5 GPP7 NHI0 NHI1; do
          status=$(grep "^$dev" /proc/acpi/wakeup 2>/dev/null | awk '{print $3}')
          if [ "$status" = "*enabled" ]; then
            echo "$dev" > /proc/acpi/wakeup
          fi
        done
        # Ensure power button wake stays enabled
        for dev in PWRB PWBN; do
          status=$(grep "^$dev" /proc/acpi/wakeup 2>/dev/null | awk '{print $3}')
          if [ "$status" = "*disabled" ]; then
            echo "$dev" > /proc/acpi/wakeup
          fi
        done
      fi
    '';
  };

  # Unload bluetooth driver before suspend to prevent wake, reload after resume
  powerManagement.powerDownCommands = ''
    ${pkgs.kmod}/bin/modprobe -r btusb
  '';
  powerManagement.resumeCommands = ''
    ${pkgs.kmod}/bin/modprobe btusb
  '';

  # Restart NetworkManager after resume to restore connectivity
  systemd.services.network-resume = {
    description = "Restart NetworkManager after suspend";
    wantedBy = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
    after = ["systemd-suspend.service" "systemd-hibernate.service" "systemd-hybrid-sleep.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart NetworkManager && ${pkgs.systemd}/bin/systemctl restart mullvad-daemon'";
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
