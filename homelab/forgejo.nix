{
  config,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  forge = homelab.endpoints.forgejo;
  forgejo = lib.getExe config.services.forgejo.package;
  runner = lib.getExe pkgs.forgejo-runner;
  registrationDir = "/var/lib/forgejo-runner-registration";
  runnerHome = "/srv/forgejo-runner";
  adminCli = pkgs.writeShellScriptBin "forgejo-admin" ''
    export HOME=${config.services.forgejo.stateDir}
    export FORGEJO_WORK_DIR=${config.services.forgejo.stateDir}
    export FORGEJO_CUSTOM=${config.services.forgejo.customDir}
    exec ${forgejo} "$@"
  '';
  runnerConfig = pkgs.writeText "forgejo-runner-base.json" (builtins.toJSON {
    runner = {
      capacity = 1;
      shutdown_timeout = "1m";
      labels = ["docker:docker://docker.io/library/node:22-bookworm"];
    };
    cache.enabled = false;
    container = {
      # The Podman socket stays outside job containers.
      docker_host = "-";
      privileged = false;
      valid_volumes = [];
      options = "--memory=4g --cpus=2";
      force_pull = true;
    };
    server.connections.kim = {
      inherit (forge) url;
      uuid = "";
      token_url = "file:$CREDENTIALS_DIRECTORY/token";
    };
  });
in {
  custom.backup.applicationVersions.forgejo = config.services.forgejo.package.version;

  environment.systemPackages = [adminCli];

  services.forgejo = {
    enable = true;
    stateDir = "/srv/forgejo";
    database.type = "postgres";
    lfs.enable = true;
    settings = {
      server = {
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = forge.port;
        DOMAIN = forge.host;
        ROOT_URL = "${forge.url}/";
        SSH_DOMAIN = "kim.${homelab.tailnetDomain}";
      };
      session.COOKIE_SECURE = true;
      service.DISABLE_REGISTRATION = true;
      repository.DEFAULT_PRIVATE = "private";
      actions.ENABLED = true;
    };
  };

  # Forgejo's SSH clone URLs use Kim's existing sshd, which the Fleet module
  # permits only through tailscale0. No extra listener or firewall port is added.

  virtualisation.podman.enable = true;
  users.groups.forgejo-runner = {};
  users.users = {
    forgejo.extraGroups = ["forgejo-runner"];
    forgejo-runner = {
      isSystemUser = true;
      group = "forgejo-runner";
      home = runnerHome;
      createHome = false;
      linger = true;
      subUidRanges = [
        {
          startUid = 2000000;
          count = 65536;
        }
      ];
      subGidRanges = [
        {
          startGid = 2000000;
          count = 65536;
        }
      ];
    };
  };

  systemd = {
    tmpfiles.rules = [
      "d ${registrationDir} 0750 forgejo forgejo-runner - -"
      "d ${runnerHome} 0700 forgejo-runner forgejo-runner - -"
    ];

    # A stable generated secret pairs both sides without putting a token into
    # the Nix store. Registration survives service restarts and restores.
    services.forgejo-runner-register = {
      description = "Register Kim's Forgejo Actions runner";
      requires = ["forgejo.service"];
      after = ["forgejo.service"];
      serviceConfig = {
        Type = "oneshot";
        User = "forgejo";
        Group = "forgejo";
        WorkingDirectory = config.services.forgejo.stateDir;
        UMask = "0077";
      };
      environment = {
        HOME = config.services.forgejo.stateDir;
        FORGEJO_WORK_DIR = config.services.forgejo.stateDir;
        FORGEJO_CUSTOM = config.services.forgejo.customDir;
      };
      script = ''
        set -euo pipefail
        secret_file=${registrationDir}/secret
        uuid_file=${registrationDir}/uuid

        if [ ! -s "$secret_file" ]; then
          secret="$(${forgejo} forgejo-cli actions generate-secret)"
          if [[ ! "$secret" =~ ^[0-9a-f]{40}$ ]]; then
            echo "Forgejo returned an invalid runner secret" >&2
            exit 1
          fi
          secret_tmp="$(mktemp ${registrationDir}/.secret.XXXXXX)"
          printf '%s' "$secret" > "$secret_tmp"
          chgrp forgejo-runner "$secret_tmp"
          chmod 0640 "$secret_tmp"
          mv "$secret_tmp" "$secret_file"
        fi
        chgrp forgejo-runner "$secret_file"
        chmod 0640 "$secret_file"

        uuid="$(${forgejo} forgejo-cli actions register --name kim --secret-file "$secret_file")"
        if [[ ! "$uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
          echo "Forgejo returned an invalid runner UUID" >&2
          exit 1
        fi
        uuid_tmp="$(mktemp ${registrationDir}/.uuid.XXXXXX)"
        printf '%s' "$uuid" > "$uuid_tmp"
        chgrp forgejo-runner "$uuid_tmp"
        chmod 0640 "$uuid_tmp"
        mv "$uuid_tmp" "$uuid_file"
      '';
    };

    # The lingered runner user gets NixOS's rootless Podman user socket. The
    # runner itself has no membership in Kim's rootful Docker group.
    services.forgejo-runner = {
      description = "Forgejo Actions runner on Kim";
      wantedBy = ["multi-user.target"];
      requires = ["forgejo-runner-register.service"];
      after = [
        "forgejo-runner-register.service"
        "network-online.target"
      ];
      wants = ["network-online.target"];
      path = [pkgs.coreutils pkgs.jq];
      environment = {
        HOME = runnerHome;
      };
      serviceConfig = {
        Type = "simple";
        User = "forgejo-runner";
        Group = "forgejo-runner";
        WorkingDirectory = runnerHome;
        LoadCredential = ["token:${registrationDir}/secret"];
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStopSec = "90s";
        UMask = "0077";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        InaccessiblePaths = ["/home" "/root"];
        PrivateTmp = true;
        ReadWritePaths = [runnerHome];
      };
      preStart = ''
        set -euo pipefail
        socket="/run/user/$(id -u)/podman/podman.sock"
        for _ in $(seq 1 30); do
          [ -S "$socket" ] && break
          sleep 1
        done
        [ -S "$socket" ] || { echo "rootless Podman socket is unavailable" >&2; exit 1; }
        uuid="$(cat ${registrationDir}/uuid)"
        jq --arg uuid "$uuid" '.server.connections.kim.uuid = $uuid' ${runnerConfig} > ${runnerHome}/config.json.tmp
        mv ${runnerHome}/config.json.tmp ${runnerHome}/config.json
      '';
      script = ''
        runner_uid="$(id -u)"
        export DOCKER_HOST="unix:///run/user/$runner_uid/podman/podman.sock"
        exec ${runner} daemon --config ${runnerHome}/config.json
      '';
    };
  };
}
