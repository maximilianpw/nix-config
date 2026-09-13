{
  config,
  hostname,
  inputs,
  lib,
  pkgs,
  ...
}: let
  defaultTunnels = (import ./default-tunnels.nix).${hostname} or [];
  fleet = import ../../lib/fleet.nix {
    inherit hostname lib pkgs;
    homeDirectory = config.home.homeDirectory;
    tunnels = config.fleet.tunnels.mappings;
  };
  localPorts = map (t: t.localPort) config.fleet.tunnels.mappings;
in {
  imports = [inputs.fleet.homeManagerModules.default];

  options.fleet.tunnels.mappings = lib.mkOption {
    type = lib.types.listOf (lib.types.submodule {
      options = {
        host = lib.mkOption {
          type = lib.types.strMatching "[A-Za-z0-9._-]+";
          description = "Remote Fleet host or alias used as the fleet-forward-* SSH target.";
        };
        localPort = lib.mkOption {
          type = lib.types.ints.between 1 65535;
          description = "Local IPv4 loopback port bound on this machine.";
        };
        remotePort = lib.mkOption {
          type = lib.types.ints.between 1 65535;
          description = "Port on the remote host to forward to.";
        };
        remoteHost = lib.mkOption {
          type = lib.types.strMatching "[A-Za-z0-9._-]+";
          default = "localhost";
          description = "Remote SSH -L target. localhost covers IPv4 and IPv6 loopback.";
        };
      };
    });
    default = defaultTunnels;
    description = ''
      Login-supervised localhost SSH forwards. On Darwin, Home Manager installs
      one user LaunchAgent per local port. Pause/resume uses launchctl disable,
      which is stored outside the plist, so Home Manager activation does not
      clear runtime pause intent.
    '';
  };

  config = {
    assertions = [
      {
        assertion = lib.length localPorts == lib.length (lib.unique localPorts);
        message = "fleet.tunnels.mappings local ports must be unique";
      }
    ];

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
  };
}
