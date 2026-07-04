{
  config,
  lib,
  pkgs,
  hostname,
  ...
}: let
  fleet = import ../../lib/fleet.nix {
    inherit hostname lib pkgs;
    homeDirectory = config.home.homeDirectory;
  };
in {
  home = {
    packages = [fleet.package];

    file = {
      ".config/fleet/hosts.json".text = fleet.files.hostsJson;
      ".config/fleet/FLEET.md".text = fleet.files.contract;
      ".ssh/fleet_known_hosts".text = fleet.files.knownHosts;
    };
  };

  programs = {
    ssh.settings = fleet.sshSettings;

    bash.shellAliases = fleet.aliases;
    zsh.shellAliases = fleet.aliases;
    fish.shellAliases = fleet.aliases;
    nushell.shellAliases = fleet.aliases;
  };
}
