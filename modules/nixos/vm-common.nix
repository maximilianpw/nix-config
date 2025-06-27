{
  config,
  pkgs,
  lib,
  ...
}: {
  # VM-specific optimizations and configurations
  
  # Enable guest additions and optimizations for VMs
  services.spice-vdagentd.enable = true;
  services.qemuGuest.enable = true;
  
  # VM-specific kernel parameters
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200"
  ];
  
  # Enable serial console
  systemd.services."serial-getty@ttyS0".enable = true;
  
  # VM optimizations
  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
  ];
  
  # Faster boot for VMs
  boot.initrd.systemd.enable = true;
  boot.plymouth.enable = false;
  
  # VM-specific services
  services.getty.autologinUser = "maxpw";
  
  # Reduce journal size for VMs
  services.journald.extraConfig = ''
    SystemMaxUse=100M
    RuntimeMaxUse=50M
  '';
  
  # VM networking optimizations
  networking.useDHCP = lib.mkDefault true;
  
  # Enable VMware tools if running on VMware (x86_64 only)
  virtualisation.vmware.guest.enable = lib.mkIf (pkgs.stdenv.isx86_64) (lib.mkDefault true);
}