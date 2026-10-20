{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit (homelab.services.portfolio-tracker) endpoint;
  system = pkgs.stdenv.hostPlatform.system;
  sopsFile = ../secrets/portfolio-tracker.yaml;
in {
  # The package version is generic; record the locked source revision too.
  custom.backup.applicationVersions.portfolio-tracker = "${config.services.portfolio-tracker.package.version}-${inputs.portfolio-tracker.shortRev}";

  # The corrections list holdings, and this repository is public: keep them in sops,
  # never as a plain file that would land in Git and the world-readable store.
  sops.secrets = {
    portfolio-tracker-token = {
      inherit sopsFile;
      key = "token";
      restartUnits = ["portfolio-tracker-api.service"];
    };
    portfolio-tracker-corrections = {
      inherit sopsFile;
      key = "corrections";
      owner = "portfolio-tracker";
      mode = "0400";
      restartUnits = ["portfolio-tracker-api.service"];
    };
  };

  services.portfolio-tracker = {
    enable = true;
    # nixos-26.05 ships pytr 0.4.9; the tracker was verified against 0.4.10.
    pytrPackage = inputs.nixpkgs-unstable.legacyPackages.${system}.pytr;
    listen = "127.0.0.1:${toString endpoint.port}";
    tokenFile = config.sops.secrets.portfolio-tracker-token.path;
    correctionsFile = config.sops.secrets.portfolio-tracker-corrections.path;
  };
}
