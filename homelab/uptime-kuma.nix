{lib, ...}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit (homelab.privateServices) kuma;
in {
  services.uptime-kuma = {
    enable = true;
    appriseSupport = true;
    settings = {
      HOST = "127.0.0.1";
      PORT = toString kuma.port;
    };
  };
}
