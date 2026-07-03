{
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

  networking.firewall.trustedInterfaces = lib.mkDefault ["tailscale0"];

  programs.mosh = {
    enable = lib.mkDefault true;
    openFirewall = lib.mkDefault true;
  };

  environment.systemPackages = [
    pkgs.tmux
  ];
}
