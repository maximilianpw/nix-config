{
  config,
  lib,
  pkgs,
  hostname,
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

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = lib.length localPorts == lib.length (lib.unique localPorts);
          message = "fleet.tunnels.mappings local ports must be unique";
        }
      ];

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
        fish.shellAliases = fleet.aliases;
        nushell.shellAliases = fleet.aliases;
      };
    }
    (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      # Home Manager launchd.agents, not nix-darwin launchd.user.agents.
      # Labels are org.nix-community.home.fleet-tunnel-<port>. KeepAlive and
      # RunAtLoad start at login and retry; ThrottleInterval bounds respawn.
      # No dedicated stdout/stderr files: diagnostics probe current state
      # rather than accumulating an unbounded SSH retry log.
      launchd.agents = fleet.launchdAgents;
    })
  ];
}
