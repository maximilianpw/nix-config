{
  config,
  lib,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit ((homelab.endpoints config.homelab.tailnet.domain)) atuin;
in {
  services.atuin = {
    enable = true;
    host = "127.0.0.1";
    inherit (atuin) port;
    openFirewall = false;
    # Open only for initial enrollment using the runbook's runtime override.
    openRegistration = false;
    database.createLocally = true;
  };
}
