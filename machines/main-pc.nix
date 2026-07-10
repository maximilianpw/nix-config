{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./hardware/main-pc.nix
    ../homelab
    ../modules/services/backup.nix
  ];

  custom.backup.enable = true;

  # Core system identity
  # TODO: Consider renaming this host and flake config from main-pc to beest.
  networking.hostName = "main-pc";

  # Wake-on-LAN on the Realtek RTL8125, so the box can be powered back up
  # remotely after a manual shutdown.
  networking.interfaces.enp194s0.wakeOnLan.enable = true;

  # schedutil idles low under amd_pstate=guided but still clocks up for nix
  # builds and long-running agents; powersave would pin the box to min freq.
  powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";

  boot = {
    kernelModules = ["amd_pmc"];
    # Ethernet-only box: drop the AX200 Wi-Fi and Bluetooth radios; the AX200
    # was the source of the old iwlwifi power-save workarounds.
    blacklistedKernelModules = ["iwlwifi" "btusb"];
    kernelParams = [
      "amd_pstate=guided"
    ];
    loader = {
      systemd-boot.enable = lib.mkDefault true;
      efi.canTouchEfiVariables = lib.mkDefault true;
      grub.enable = lib.mkDefault false;
    };
  };

  # Always-on server: avoid accidental suspend or hibernation.
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  # Hardware watchdog (SP5100 TCO): auto-reboot if the kernel hard-hangs,
  # instead of staying down until someone walks over to the box.
  systemd.settings.Manager = {
    RuntimeWatchdogSec = "30s";
    RebootWatchdogSec = "10m";
  };

  hardware.bluetooth.enable = lib.mkDefault false;

  # Container stack for dev databases and ad-hoc services.
  virtualisation.docker = {
    enable = true;
    # Default docker (28.x) is unmaintained and marked insecure in nixpkgs 25.11
    package = pkgs.docker_29;
  };
  users.users.maxpw.extraGroups = lib.mkAfter ["docker"];

  # Start user services at boot instead of first SSH login.
  users.users.maxpw.linger = true;

  services = {
    # Firmware updates are still useful on a headless box.
    fwupd.enable = true;

    # Weekly TRIM; matters more than usual for the DRAM-less Micron 2550s.
    fstrim.enable = true;

    # SMART monitoring for both NVMe drives.
    smartd.enable = true;
  };

  # System-scoped packages
  environment.systemPackages = [
    pkgs.cachix
    pkgs.ethtool
    pkgs.hdparm
    pkgs.lm_sensors
    pkgs.nvme-cli
    pkgs.pciutils
    pkgs.smartmontools
    pkgs.usbutils
  ];
}
