{
  config,
  pkgs,
  lib,
  ...
}: let
  # Flags can be passed via specialArgs or by host config
  isQemu = config.virtualisation.qemuGuest.enable or false;
  isVmware = config.virtualisation.vmware.guest.enable or false;
in {
  # Shared VM tweaks
  services.spice-vdagentd.enable = isQemu;
  services.qemuGuest.enable = isQemu;

  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200"
  ];
  systemd.services."serial-getty@ttyS0".enable = true;
  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
  ];
  boot.initrd.systemd.enable = true;
  boot.plymouth.enable = false;

  services.getty.autologinUser = "maxpw";
  services.journald.extraConfig = ''
    SystemMaxUse=100M
    RuntimeMaxUse=50M
  '';
  networking.useDHCP = lib.mkDefault true;
}
