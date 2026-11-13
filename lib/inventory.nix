{lib}: let
  inherit (lib) mkOption types;
  rawHosts = import ./hosts.nix;

  clientType = types.submodule {
    options = {
      key = mkOption {
        type = types.str;
        description = "Public SSH client key; the private key never enters Nix.";
      };
      tailscaleIps = mkOption {
        type = types.nonEmptyListOf types.str;
        description = "Stable Tailscale source addresses allowed to present this key.";
      };
      identityFile = mkOption {
        type = types.str;
        description = "Client-side identity selector relative to the user's home directory.";
      };
      identityAgent = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional SSH agent socket used to resolve identityFile's public key.";
      };
    };
  };

  tunnelType = types.submodule {
    options = {
      host = mkOption {
        type = types.strMatching "[A-Za-z0-9._-]+";
        description = "Remote Fleet host or alias used as the fleet-forward-* SSH target.";
      };
      localPort = mkOption {
        type = types.ints.between 1 65535;
        description = "Local IPv4 loopback port bound on this machine.";
      };
      remotePort = mkOption {
        type = types.ints.between 1 65535;
        description = "Port on the remote host to forward to.";
      };
      remoteHost = mkOption {
        type = types.strMatching "[A-Za-z0-9._-]+";
        default = "localhost";
        description = "Remote SSH -L target. localhost covers IPv4 and IPv6 loopback.";
      };
    };
  };

  hostType = types.submodule ({
    config,
    name,
    ...
  }: {
    options = {
      system = mkOption {type = types.str;};
      user = mkOption {type = types.str;};
      os = mkOption {type = types.enum ["darwin" "nixos" "nixos-wsl"];};
      linuxDesktop = mkOption {
        type = types.bool;
        default = false;
        description = "Hyprland desktop profile; only valid when os is nixos.";
      };
      lockScreen = mkOption {
        type = types.bool;
        default = false;
        description = "Hyprlock binding and idle lock; only valid with linuxDesktop.";
      };
      hardwareModules = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      role = mkOption {type = types.enum ["nixos-homelab" "nixos-wsl" "darwin-workstation"];};
      longRunningAgents = mkOption {type = types.bool;};
      client = mkOption {
        type = types.nullOr clientType;
        description = "Outbound Fleet identity, or null until this host is enrolled.";
      };

      hostName = mkOption {
        type = types.str;
        default = name;
        description = "Tailscale MagicDNS target; defaults to the inventory key.";
      };
      aliases = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      hostKey = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      port = mkOption {
        type = types.port;
        default = 22;
      };
      t3codePort = mkOption {
        type = types.nullOr types.port;
        default = null;
      };
      atuinSync = mkOption {
        type = types.bool;
        default = false;
        description = "Atuin shell history synced through Kim's server.";
      };
      tunnels = mkOption {
        type = types.listOf tunnelType;
        default = [];
        description = "Login-supervised localhost SSH forwards; Darwin runs one LaunchAgent per local port.";
      };
      tmuxSession = mkOption {
        type = types.str;
        default = "main";
      };
      tmuxCommand = mkOption {
        type = types.str;
        default =
          if config.darwin
          then "/etc/profiles/per-user/${config.user}/bin/tmux"
          else "/run/current-system/sw/bin/tmux";
      };

      darwin = mkOption {
        type = types.bool;
        readOnly = true;
        default = config.os == "darwin";
      };
      wsl = mkOption {
        type = types.bool;
        readOnly = true;
        default = config.os == "nixos-wsl";
      };
      gui = mkOption {
        type = types.bool;
        readOnly = true;
        default = config.darwin || config.linuxDesktop;
      };
      accent = mkOption {
        type = types.strMatching "#[0-9a-fA-F]{6}";
        default =
          if config.darwin
          then "#7aa2f7"
          else if config.wsl
          then "#e0af68"
          else "#9ece6a";
      };
    };
  });

  hosts =
    (lib.evalModules {
      modules = [
        {
          options.hosts = mkOption {type = types.attrsOf hostType;};
          config.hosts = rawHosts;
        }
      ];
    }).config.hosts;

  allNames = lib.concatLists (lib.mapAttrsToList (name: host: [name] ++ host.aliases) hosts);
  duplicateNames = lib.filter (candidate: lib.count (name: name == candidate) allNames > 1) (lib.unique allNames);
  incompatiblePlatforms = lib.attrNames (lib.filterAttrs (_: host: host.linuxDesktop && host.os != "nixos") hosts);
  lockWithoutDesktop = lib.attrNames (lib.filterAttrs (_: host: host.lockScreen && !host.linuxDesktop) hosts);
in
  assert lib.assertMsg (duplicateNames == [])
  "Fleet host names and aliases collide: ${lib.concatStringsSep ", " duplicateNames}";
  assert lib.assertMsg (incompatiblePlatforms == [])
  "Only nixos hosts can enable linuxDesktop: ${lib.concatStringsSep ", " incompatiblePlatforms}";
  assert lib.assertMsg (lockWithoutDesktop == [])
  "Only linuxDesktop hosts can enable lockScreen: ${lib.concatStringsSep ", " lockWithoutDesktop}"; hosts
