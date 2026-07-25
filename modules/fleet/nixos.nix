{
  config,
  lib,
  pkgs,
  ...
}: {
  # Mesh-networked development nodes: ssh-access.nix owns authentication and
  # source policy; this adds private networking and resilient terminal transport.
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
    # Accept Ghostty clients without downgrading TERM to xterm-256color.
    pkgs.ghostty.terminfo
    pkgs.tmux
  ];
}
