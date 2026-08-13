{
  config,
  lib,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit ((homelab.endpoints config.homelab.tailnet.domain)) actual;
in {
  services.actual = {
    enable = true;
    openFirewall = false;
    settings = {
      hostname = "127.0.0.1";
      inherit (actual) port;
      loginMethod = "password";
      allowedLoginMethods = ["password"];
    };
  };
}
