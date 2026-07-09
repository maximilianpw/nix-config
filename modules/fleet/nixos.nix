{
  config,
  lib,
  pkgs,
  ...
}: {
  # Mesh-networked development nodes: SSH stays in core/security.nix; this adds
  # the private network and resilient terminal transport used by the fleet workflow.
  services.tailscale = {
    enable = lib.mkDefault true;
    openFirewall = lib.mkDefault true;
    useRoutingFeatures = lib.mkDefault "client";
  };

  # Keep administrative services reachable from the tailnet without exposing
  # them on the host's physical interfaces. Tailscale's own UDP listener still
  # needs `services.tailscale.openFirewall` for peer-to-peer connectivity.
  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = config.services.openssh.ports;
    allowedUDPPortRanges = [
      {
        from = 60000;
        to = 61000;
      }
    ];
  };

  services.openssh.openFirewall = lib.mkForce false;

  programs.mosh = {
    enable = lib.mkDefault true;
    openFirewall = lib.mkForce false;
  };

  environment.systemPackages = [
    pkgs.tmux
  ];
}
