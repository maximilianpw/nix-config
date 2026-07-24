{
  config,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../../lib/homelab.nix {inherit lib;};
  inherit ((homelab.endpoints config.homelab.tailnet.domain)) buzz;
  healthPort = 19004;
  pairingPort = homelab.privateServices.buzz.pathBackends."/pair";
  docker = lib.getExe config.virtualisation.docker.package;
  composeFormat = pkgs.formats.yaml {};

  images = {
    relay = "ghcr.io/block/buzz@sha256:a0f67203d71d15d237fa7517788799957c30c8acdb81cbcff711e07e951c2710"; # 0.2.0
    # v0.4.23 (sha-acfbb1b). The stable 0.2.0 relay image predates this
    # stateless binary, so keep the database-backed relay pinned separately.
    pairingRelay = "ghcr.io/block/buzz@sha256:29fe13981a726fe43642fe03cbd6cc87142579a90bbf9897e3c1b370d1037428";
    postgres = "docker.io/library/postgres@sha256:742f40ea20b9ff2ff31db5458d127452988a2164df9e17441e191f3b72252193"; # 17.10-alpine3.24
    redis = "docker.io/library/redis@sha256:6ab0b6e7381779332f97b8ca76193e45b0756f38d4c0dcda72dbb3c32061ab99"; # 7.4.9-alpine
    minio = "docker.io/minio/minio@sha256:14cea493d9a34af32f524e538b8346cf79f3321eff8e708c1e2960462bd8936e"; # RELEASE.2025-09-07T16-13-09Z
    minioClient = "docker.io/minio/mc@sha256:a7fe349ef4bd8521fb8497f55c6042871b2ae640607cf99d9bede5e9bdf11727"; # RELEASE.2025-08-13T08-35-41Z
  };

  secretNames = [
    "buzz-relay-private-key"
    "buzz-owner-public-key"
    "buzz-git-hook-hmac-secret"
    "buzz-postgres-password"
    "buzz-redis-password"
    "buzz-s3-access-key"
    "buzz-s3-secret-key"
  ];

  envFile = config.sops.templates."buzz.env".path;
  lockFile = "/run/lock/buzz-compose.lock";
  passEnvironment = names: lib.genAttrs names (_: null);
  composeFile = composeFormat.generate "buzz-compose.yml" {
    name = "buzz-prod";

    services = {
      relay = {
        image = images.relay;
        environment =
          passEnvironment [
            "BUZZ_DOMAIN"
            "RELAY_URL"
            "BUZZ_MEDIA_BASE_URL"
            "BUZZ_MEDIA_SERVER_DOMAIN"
            "BUZZ_CORS_ORIGINS"
            "BUZZ_REQUIRE_AUTH_TOKEN"
            "BUZZ_REQUIRE_RELAY_MEMBERSHIP"
            "BUZZ_ALLOW_NIP_OA_AUTH"
            "BUZZ_AUTO_MIGRATE"
            "BUZZ_GIT_CONFORMANCE_PROBE"
            "RUST_LOG"
            "RELAY_OWNER_PUBKEY"
            "BUZZ_RELAY_PRIVATE_KEY"
            "BUZZ_GIT_HOOK_HMAC_SECRET"
            "DATABASE_URL"
            "REDIS_URL"
            "BUZZ_S3_ACCESS_KEY"
            "BUZZ_S3_SECRET_KEY"
            "BUZZ_S3_BUCKET"
          ]
          // {
            BUZZ_BIND_ADDR = "0.0.0.0:3000";
            BUZZ_HEALTH_PORT = "8080";
            BUZZ_METRICS_PORT = "9102";
            BUZZ_S3_ENDPOINT = "http://minio:9000";
            BUZZ_GIT_REPO_PATH = "/data/git";
          };
        ports = [
          "127.0.0.1:${toString buzz.port}:3000"
          "127.0.0.1:${toString healthPort}:8080"
        ];
        volumes = ["buzz-git-cache:/data/git"];
        depends_on = {
          postgres.condition = "service_healthy";
          redis.condition = "service_healthy";
          minio.condition = "service_healthy";
          minio-init.condition = "service_completed_successfully";
        };
        healthcheck = {
          test = [
            "CMD-SHELL"
            ''bash -ec 'exec 3<>/dev/tcp/127.0.0.1/8080; printf "GET /_readiness HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n" >&3; grep -q "200 OK" <&3' ''
          ];
          interval = "10s";
          timeout = "3s";
          retries = 12;
          start_period = "30s";
        };
        restart = "unless-stopped";
        networks = ["buzz-net"];
      };

      pairing-relay = {
        image = images.pairingRelay;
        command = ["/usr/local/bin/buzz-pair-relay"];
        environment.BUZZ_PAIR_RELAY_BIND_ADDR = "0.0.0.0:5000";
        ports = ["127.0.0.1:${toString pairingPort}:5000"];
        healthcheck = {
          test = [
            "CMD-SHELL"
            "bash -ec 'exec 3<>/dev/tcp/127.0.0.1/5000'"
          ];
          interval = "10s";
          timeout = "3s";
          retries = 12;
          start_period = "5s";
        };
        restart = "unless-stopped";
        networks = ["buzz-net"];
      };

      postgres = {
        image = images.postgres;
        environment =
          passEnvironment [
            "POSTGRES_DB"
            "POSTGRES_USER"
            "POSTGRES_PASSWORD"
          ]
          // {
            PGDATA = "/var/lib/postgresql/data/pgdata";
          };
        volumes = ["buzz-postgres-data:/var/lib/postgresql/data"];
        healthcheck = {
          test = ["CMD-SHELL" "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"];
          interval = "5s";
          timeout = "5s";
          retries = 12;
          start_period = "10s";
        };
        restart = "unless-stopped";
        networks = ["buzz-net"];
      };

      redis = {
        image = images.redis;
        environment = passEnvironment ["REDIS_PASSWORD"];
        command = [
          "/bin/sh"
          "-euc"
          ''exec redis-server --appendonly yes --requirepass "$${REDIS_PASSWORD}"''
        ];
        volumes = ["buzz-redis-data:/data"];
        healthcheck = {
          test = ["CMD-SHELL" ''redis-cli -a "$${REDIS_PASSWORD}" ping | grep -q PONG''];
          interval = "5s";
          timeout = "3s";
          retries = 12;
          start_period = "5s";
        };
        restart = "unless-stopped";
        networks = ["buzz-net"];
      };

      minio = {
        image = images.minio;
        environment = passEnvironment [
          "MINIO_ROOT_USER"
          "MINIO_ROOT_PASSWORD"
        ];
        command = [
          "server"
          "/data"
          "--console-address"
          ":9001"
        ];
        volumes = ["buzz-minio-data:/data"];
        healthcheck = {
          test = ["CMD" "curl" "-f" "http://127.0.0.1:9000/minio/health/live"];
          interval = "5s";
          timeout = "5s";
          retries = 12;
          start_period = "10s";
        };
        restart = "unless-stopped";
        networks = ["buzz-net"];
      };

      minio-init = {
        image = images.minioClient;
        environment = passEnvironment [
          "BUZZ_S3_ACCESS_KEY"
          "BUZZ_S3_SECRET_KEY"
          "BUZZ_S3_BUCKET"
        ];
        depends_on.minio.condition = "service_healthy";
        entrypoint = [
          "/bin/sh"
          "-euc"
          ''
            mc alias set local http://minio:9000 "$${BUZZ_S3_ACCESS_KEY}" "$${BUZZ_S3_SECRET_KEY}"
            mc mb --ignore-existing "local/$${BUZZ_S3_BUCKET}"
            mc anonymous set none "local/$${BUZZ_S3_BUCKET}"
          ''
        ];
        restart = "no";
        networks = ["buzz-net"];
      };
    };

    volumes = {
      buzz-postgres-data.labels."com.buzz.volume" = "postgres";
      buzz-redis-data.labels."com.buzz.volume" = "redis";
      buzz-minio-data.labels."com.buzz.volume" = "minio";
      # Current Buzz stores authoritative Git objects in S3. This volume is
      # only a disposable hydration/cache path and is intentionally not backed up.
      buzz-git-cache.labels."com.buzz.volume" = "git-cache";
    };

    networks.buzz-net = {
      driver = "bridge";
      labels."com.buzz.network" = "production";
    };
  };

  composeArgs = "--env-file ${lib.escapeShellArg envFile} -f ${lib.escapeShellArg composeFile}";
  compose = "${docker} compose ${composeArgs}";

  startScript = pkgs.writeShellScript "buzz-start" ''
    exec ${lib.getExe' pkgs.util-linux "flock"} ${lockFile} ${compose} up --detach --wait --remove-orphans
  '';
  stopScript = pkgs.writeShellScript "buzz-stop" ''
    exec ${lib.getExe' pkgs.util-linux "flock"} ${lockFile} ${compose} stop
  '';

  backupScript = pkgs.writeShellScript "buzz-backup-export" ''
    set -euo pipefail
    umask 077

    export_root=/var/backup/buzz
    staging=/var/backup/.buzz-staging
    relay_was_running=0

    exec 9>${lockFile}
    ${lib.getExe' pkgs.util-linux "flock"} 9

    cleanup() {
      status=$?
      trap - EXIT INT TERM
      set +e
      rm -rf "$staging"
      if [ "$relay_was_running" -eq 1 ]; then
        if ! ${compose} up --detach --wait relay; then
          echo "Failed to restart the Buzz relay after export" >&2
          status=1
        fi
      fi
      exit "$status"
    }
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    relay_container="$(${compose} ps --all --quiet relay)"
    if [ -n "$relay_container" ]; then
      relay_state="$(${docker} inspect --format '{{.State.Status}}' "$relay_container")"
      case "$relay_state" in
        running|restarting|paused) relay_was_running=1 ;;
      esac
      ${compose} stop relay
    fi

    rm -rf "$staging"
    install -d -m 0700 "$staging/minio"

    ${compose} exec -T postgres /bin/sh -euc \
      'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --format custom' \
      >"$staging/postgresql.dump.tmp"
    mv "$staging/postgresql.dump.tmp" "$staging/postgresql.dump"

    ${compose} run --rm --no-deps \
      --entrypoint /bin/sh \
      --volume "$staging/minio:/backup" \
      minio-init -euc '
        mc alias set local http://minio:9000 "$BUZZ_S3_ACCESS_KEY" "$BUZZ_S3_SECRET_KEY"
        mc mirror --overwrite "local/$BUZZ_S3_BUCKET" /backup
      '

    cat >"$staging/images.txt" <<'EOF'
    relay=${images.relay}
    pairing-relay=${images.pairingRelay}
    postgres=${images.postgres}
    redis=${images.redis}
    minio=${images.minio}
    minio-client=${images.minioClient}
    EOF

    chmod -R u=rwX,go= "$staging"
    install -d -m 0700 "$export_root"
    ${lib.getExe' pkgs.coreutils "mv"} --exchange --no-copy --no-target-directory "$staging" "$export_root"
    rm -rf "$staging"
  '';

  buzzctl = pkgs.writeShellApplication {
    name = "buzzctl";
    runtimeInputs = [config.virtualisation.docker.package];
    text = ''
      case "''${1:-status}" in
        status|ps)
          exec ${compose} ps
          ;;
        logs)
          shift || true
          exec ${compose} logs --follow "''${@:-relay}"
          ;;
        restart)
          exec ${lib.getExe' pkgs.util-linux "flock"} ${lockFile} ${compose} up --detach --wait --force-recreate relay pairing-relay
          ;;
        add-member)
          pubkey="''${2:?Usage: buzzctl add-member <npub-or-hex> [--role member|admin]}"
          exec ${compose} exec relay /usr/local/bin/buzz-admin add-member --pubkey "$pubkey" "''${@:3}"
          ;;
        remove-member)
          pubkey="''${2:?Usage: buzzctl remove-member <npub-or-hex> [--role member|admin]}"
          exec ${compose} exec relay /usr/local/bin/buzz-admin remove-member --pubkey "$pubkey" "''${@:3}"
          ;;
        list-members)
          exec ${compose} exec relay /usr/local/bin/buzz-admin list-members
          ;;
        *)
          echo "Usage: buzzctl {status|logs [service]|restart|add-member|remove-member|list-members}" >&2
          exit 2
          ;;
      esac
    '';
  };
in {
  assertions = [
    {
      assertion = config.virtualisation.docker.enable;
      message = "Buzz requires virtualisation.docker.enable";
    }
    {
      assertion = config.services.tailscale.enable;
      message = "Buzz private ingress requires services.tailscale.enable";
    }
  ];

  sops = {
    secrets = lib.genAttrs secretNames (_: {});

    templates = {
      "buzz.env" = {
        mode = "0400";
        restartUnits = ["buzz.service"];
        content = let
          placeholder = config.sops.placeholder;
        in ''
          BUZZ_DOMAIN=${buzz.host}
          RELAY_URL=wss://${buzz.host}
          BUZZ_MEDIA_BASE_URL=https://${buzz.host}/media
          BUZZ_MEDIA_SERVER_DOMAIN=${buzz.host}
          BUZZ_CORS_ORIGINS=https://${buzz.host}
          BUZZ_REQUIRE_AUTH_TOKEN=true
          BUZZ_REQUIRE_RELAY_MEMBERSHIP=true
          BUZZ_ALLOW_NIP_OA_AUTH=true
          BUZZ_AUTO_MIGRATE=true
          BUZZ_GIT_CONFORMANCE_PROBE=true
          RUST_LOG=buzz_relay=info,buzz_db=info,buzz_auth=info,buzz_pubsub=info,tower_http=info
          RELAY_OWNER_PUBKEY=${placeholder.buzz-owner-public-key}
          BUZZ_RELAY_PRIVATE_KEY=${placeholder.buzz-relay-private-key}
          BUZZ_GIT_HOOK_HMAC_SECRET=${placeholder.buzz-git-hook-hmac-secret}
          POSTGRES_DB=buzz
          POSTGRES_USER=buzz
          POSTGRES_PASSWORD=${placeholder.buzz-postgres-password}
          PGPASSWORD=${placeholder.buzz-postgres-password}
          DATABASE_URL=postgres://buzz:${placeholder.buzz-postgres-password}@postgres:5432/buzz
          REDIS_PASSWORD=${placeholder.buzz-redis-password}
          REDIS_URL=redis://:${placeholder.buzz-redis-password}@redis:6379
          BUZZ_S3_ACCESS_KEY=${placeholder.buzz-s3-access-key}
          BUZZ_S3_SECRET_KEY=${placeholder.buzz-s3-secret-key}
          BUZZ_S3_BUCKET=buzz-media
          MINIO_ROOT_USER=${placeholder.buzz-s3-access-key}
          MINIO_ROOT_PASSWORD=${placeholder.buzz-s3-secret-key}
        '';
      };
    };
  };

  systemd.services = {
    buzz = {
      description = "Buzz private workspace";
      after = ["docker.service" "network-online.target"];
      requires = ["docker.service"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      restartTriggers = [composeFile];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = startScript;
        ExecStop = stopScript;
        TimeoutStartSec = "5min";
        TimeoutStopSec = "2min";
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };

    buzz-backup-export = {
      description = "Export authoritative Buzz state for Borg";
      after = ["buzz.service" "docker.service"];
      requires = ["docker.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = backupScript;
        TimeoutStartSec = "2h";
      };
    };
  };

  systemd.tmpfiles.rules = ["f ${lockFile} 0660 root docker -"];

  environment.systemPackages = [buzzctl];
}
