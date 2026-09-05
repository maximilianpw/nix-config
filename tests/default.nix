# Explicit regression registration lives beside the tests. Keep the plain
# nixpkgs and host-overlaid package sets distinct: some checks need the latter.
{
  lib,
  nixpkgs,
  nixosConfigurations,
  darwinConfigurations,
  hosts,
}: let
  common = {
    inherit lib;
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  };
  kim = common // {config = nixosConfigurations.kim.config;};
  configuredKim = kim // {pkgs = nixosConfigurations.kim.pkgs;};
in {
  x86_64-linux = {
    actual-config-regression = import ./actual-config-regression.nix kim;
    executor-config-regression = import ./executor-config-regression.nix kim;
    homelab-ingress-regression = import ./homelab-ingress-regression.nix kim;
    homelab-inventory-regression = import ./homelab-inventory-regression.nix kim;
    immich-config-regression = import ./immich-config-regression.nix kim;
    media-stack-regression = import ./media-stack-regression.nix configuredKim;
    tailscale-serve-regression = import ./tailscale-serve-regression.nix common;
    homelab-backup-regression = import ./homelab-backup-regression.nix kim;
    paperless-config-regression = import ./paperless-config-regression.nix kim;
    homepage-calendar-regression = import ./homepage-calendar-regression.nix kim;
    monitoring-regression = import ./monitoring-regression.nix kim;
    fleet-agent-forwarding-regression = import ./fleet-agent-forwarding-regression.nix common;
    fleet-ssh-regression = import ./fleet-ssh-regression.nix common;
    fleet-ghostty-regression = import ./fleet-ghostty-regression.nix configuredKim;
    fleet-trust-regression = import ./fleet-trust-regression.nix (common
      // {
        inherit hosts;
        configs =
          lib.mapAttrsToList (name: host: {
            config =
              if host.darwin
              then darwinConfigurations.${name}.config
              else nixosConfigurations.${name}.config;
            inherit (host) user;
            isDarwin = host.darwin;
          })
          hosts;
      });
  };
  aarch64-darwin = {
    fleet-ssh-regression = import ./fleet-ssh-regression.nix {
      inherit lib;
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
    };
  };
}
