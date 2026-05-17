{
  # Roon Server + Tailscale mesh access.
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  networking.firewall.trustedInterfaces = ["tailscale0"];

  services.roon-server = {
    enable = true;
    openFirewall = true;
  };

  users.users.roon-server = {
    extraGroups = ["audio"];
    isSystemUser = true;
    group = "roon-server";
  };
  users.groups.roon-server = {};
}
