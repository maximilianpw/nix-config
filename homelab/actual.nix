{
  config,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit (homelab.endpoints) actual;
in {
  custom.backup.applicationVersions.actual = config.services.actual.package.version;

  services.actual = {
    enable = true;
    # Track releases through nixpkgs-unstable, refreshed by make update and CI.
    package = pkgs.unstable.actual-server;
    openFirewall = false;
    settings = {
      hostname = "127.0.0.1";
      inherit (actual) port;
      loginMethod = "password";
      allowedLoginMethods = ["password"];
    };
  };
}
