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
    # Fleet authenticates through OpenSSH, not tailscaled's embedded server.
    extraSetFlags = ["--ssh=false"];
  };

  # Defense in depth if embedded SSH is enabled outside the configuration.
  # This does not restrict OpenSSH forwarding used by Fleet tunnels.
  systemd.services.tailscaled.environment.TS_SSH_DISABLE_FORWARDING = "1";

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
