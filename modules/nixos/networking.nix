{
  currentSystemUser,
  lib,
  pkgs,
  ...
}: {
  networking = {
    networkmanager = {
      enable = true;
      dns = "systemd-resolved";
      plugins = [pkgs.networkmanager-openvpn];
    };
    # /etc/resolv.conf must point at resolved's stub.
    resolvconf.enable = lib.mkForce false;
  };

  services.resolved.enable = true;

  users.users.${currentSystemUser}.extraGroups = ["networkmanager"];
}
