{
  config,
  currentSystemName,
  hostRecord,
  inputs,
  lib,
  pkgs,
  ...
}: let
  fleet = import ../../lib/fleet.nix {
    inherit lib;
    hostname = currentSystemName;
    homeDirectory = config.home.homeDirectory;
    inherit (hostRecord) tunnels;
  };
in {
  imports = [inputs.fleet.homeManagerModules.default];

  home.file = {
    ".config/fleet/hosts.json".text = fleet.files.hostsJson;
    ".config/fleet/FLEET.md".text = fleet.files.contract;
    ".ssh/fleet_known_hosts".text = fleet.files.knownHosts;
  };

  programs = {
    fleet = {
      enable = true;
      package = inputs.fleet.packages.${pkgs.stdenv.hostPlatform.system}.fleet;
      inherit (fleet) settings;
    };

    ssh.settings = fleet.sshSettings;

    bash.shellAliases = fleet.aliases;
    fish.shellAliases = fleet.aliases;
    nushell.shellAliases = fleet.aliases;
  };
}
