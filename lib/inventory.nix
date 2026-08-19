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

  hostType = types.submodule ({
    config,
    name,
    ...
  }: {
    options = {
      system = mkOption {type = types.str;};
      user = mkOption {type = types.str;};
      userDir = mkOption {type = types.str;};
      darwin = mkOption {type = types.bool;};
      wsl = mkOption {type = types.bool;};
      linuxDesktop = mkOption {type = types.bool;};
      hardwareModules = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      profiles = mkOption {type = types.listOf types.str;};
      role = mkOption {type = types.str;};
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

      os = mkOption {
        type = types.enum ["darwin" "nixos" "nixos-wsl"];
        readOnly = true;
        default =
          if config.darwin
          then "darwin"
          else if config.wsl
          then "nixos-wsl"
          else "nixos";
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
  incompatiblePlatforms = lib.attrNames (lib.filterAttrs (_: host:
    (host.darwin && (host.wsl || host.linuxDesktop))
    || (host.wsl && host.linuxDesktop))
  hosts);
in
  assert lib.assertMsg (duplicateNames == [])
  "Fleet host names and aliases collide: ${lib.concatStringsSep ", " duplicateNames}";
  assert lib.assertMsg (incompatiblePlatforms == [])
  "Hosts declare incompatible platform flags: ${lib.concatStringsSep ", " incompatiblePlatforms}"; hosts
