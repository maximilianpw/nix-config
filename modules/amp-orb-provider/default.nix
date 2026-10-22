{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.amp-orb-provider;
  dispatch = pkgs.writeShellApplication {
    name = "amp-orb-dispatch";
    runtimeInputs = [pkgs.coreutils pkgs.util-linux];
    text = ''
      export DOCKER_BIN=${config.virtualisation.docker.package}/bin/docker
      export ORB_STATE_DIRECTORY=/var/lib/amp-orb-provider
      export ORB_CPUS=${lib.escapeShellArg cfg.cpus}
      export ORB_MEMORY=${lib.escapeShellArg cfg.memory}
      export ORB_PIDS_LIMIT=${toString cfg.pidsLimit}
      export ORB_MAX_RUNNING=${toString cfg.maxRunning}
      exec timeout --kill-after=5s 280s ${pkgs.bash}/bin/bash ${../../scripts/agents/amp-orb-dispatch.sh}
    '';
  };
  provider = pkgs.writeShellApplication {
    name = "amp-orb-provider";
    runtimeInputs = [cfg.package];
    text = ''
      AMP_ORB_PROVIDER_TOKEN=$(< "$CREDENTIALS_DIRECTORY/provider-token")
      if [[ -z "$AMP_ORB_PROVIDER_TOKEN" ]]; then
        echo 'Amp orb provider: provider token is empty' >&2
        exit 1
      fi
      export AMP_ORB_PROVIDER_TOKEN
      exec amp orb provider ${dispatch}/bin/amp-orb-dispatch
    '';
  };
in {
  options.services.amp-orb-provider = {
    enable = lib.mkEnableOption "Amp self-hosted orbs backed by Docker";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.amp-cli;
      defaultText = lib.literalExpression "pkgs.amp-cli";
      description = "Amp CLI package with the orb provider subcommand.";
    };
    tokenFile = lib.mkOption {
      type = lib.types.strMatching "/.*";
      default = "/run/secrets/amp-orb-provider-token";
      description = ''
        Absolute runtime path to the raw provider token, normally decrypted by
        sops-nix. Never use a Nix path literal or a store file for this secret.
        The service stays stopped until this file exists.
      '';
    };
    image = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional Linux amd64 glibc orb image; null uses Amp's default image.";
    };
    cpus = lib.mkOption {
      type = lib.types.strMatching "([1-9][0-9]*(\\.[0-9]+)?|0\\.[0-9]*[1-9][0-9]*)";
      default = "4";
      description = "Docker CPU quota per orb (fractional CPUs supported).";
    };
    memory = lib.mkOption {
      type = lib.types.strMatching "[1-9][0-9]*[kKmMgG]";
      default = "8g";
      description = "Docker memory limit per orb; swap is disabled for these containers.";
    };
    pidsLimit = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2048;
      description = "Maximum number of tasks in each orb.";
    };
    maxRunning = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = "Maximum simultaneously running orbs; stopped orbs retain their disks.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
        message = "Amp self-hosted orbs require an x86_64-linux host.";
      }
      {
        assertion = !(lib.hasPrefix "/nix/store/" cfg.tokenFile);
        message = "Amp orb provider tokens must not be stored in the Nix store.";
      }
    ];

    virtualisation.docker.enable = true;
    users.groups.amp-orb-provider = {};
    users.users.amp-orb-provider = {
      isSystemUser = true;
      group = "amp-orb-provider";
      home = "/var/lib/amp-orb-provider";
    };

    systemd.services.amp-orb-provider = {
      description = "Amp self-hosted orb provider (Docker)";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      requires = ["docker.service"];
      after = ["network-online.target" "docker.service"];
      unitConfig.ConditionPathExists = cfg.tokenFile;
      environment =
        {
          HOME = "/var/lib/amp-orb-provider";
          # Keep CLI data and logs in the service's private state directory.
          XDG_CONFIG_HOME = "/var/lib/amp-orb-provider/config";
          XDG_CACHE_HOME = "/var/lib/amp-orb-provider/cache";
        }
        // lib.optionalAttrs (cfg.image != null) {ORB_IMAGE = cfg.image;};
      serviceConfig = {
        User = "amp-orb-provider";
        Group = "amp-orb-provider";
        # Docker socket access is root-equivalent, despite the dedicated user.
        SupplementaryGroups = ["docker"];
        StateDirectory = "amp-orb-provider";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/amp-orb-provider";
        LoadCredential = ["provider-token:${cfg.tokenFile}"];
        ExecStart = "${provider}/bin/amp-orb-provider";
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStopSec = "30s";
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
      };
    };
  };
}
