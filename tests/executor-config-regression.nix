{
  config,
  lib,
  pkgs,
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  endpoint = homelab.publicEndpoints.executor;
  ingress = config.services.cloudflared.tunnels.${homelab.infrastructure.cloudflare.tunnelId}.ingress;
  container = config.virtualisation.oci-containers.containers.executor;
  image = "ghcr.io/usefulsoftwareco/executor-selfhost@sha256:df242f0242f4aa75ae091e39c8d1a9f0ad29c32e9b9d603122048f9106cf97e2";
in
  assert lib.assertMsg (
    homelab.services.executor.endpoint.exposure
    == "public"
    && homelab.services.executor.endpoint.authorizationOwner == "executor"
    && !(builtins.hasAttr "executor" homelab.privateServices)
  )
  "Executor must be public with application-owned authentication, not Tailscale-only";
  assert lib.assertMsg (
    endpoint.url
    == "https://${homelab.services.executor.endpoint.hostname}"
    && ingress.${endpoint.host}.service == homelab.loopbackUrl endpoint.port
    && ingress.${endpoint.host}.originRequest.httpHostHeader == endpoint.host
  )
  "Cloudflare must route Executor's public hostname to its loopback endpoint";
  assert lib.assertMsg (config.virtualisation.oci-containers.backend == "docker")
  "Executor must use Kim's existing Docker backend";
  assert lib.assertMsg (container.image == image)
  "Executor must use the reviewed immutable image digest";
  assert lib.assertMsg (
    container.ports
    == []
    && builtins.elem "--network=host" container.extraOptions
    && container.environment.HOST == "127.0.0.1"
    && container.environment.PORT == toString endpoint.port
  )
  "Executor must only publish its HTTP endpoint on loopback";
  assert lib.assertMsg (
    container.extraOptions
    == ["--network=host" "--init"]
    && container.volumes == ["/var/lib/executor-v2:/app/data"]
    && container.environment.EXECUTOR_DATA_DIR == "/app/data"
    && config.systemd.tmpfiles.settings."10-executor"."/var/lib/executor-v2".d.mode == "0700"
  )
  "Executor v2 must use separate persistent state, init, and its native image healthcheck without a shell override";
  assert lib.assertMsg (
    lib.hasInfix "test -s /var/lib/executor-v2/auth-secret.key" config.systemd.services.docker-executor.preStart
    && lib.hasInfix "test -s /var/lib/executor-v2/encryption.key" config.systemd.services.docker-executor.preStart
  )
  "Executor startup must reject missing key files instead of creating a fresh public owner";
  assert lib.assertMsg (
    container.environment.BETTER_AUTH_URL
    == endpoint.url
    && container.environment.EXECUTOR_APPS_ALLOW_PRIVATE_FETCH == "true"
    && builtins.fromJSON container.environment.EXECUTOR_URL_ALLOW_HTTP_ORIGINS
    == [
      "http://127.0.0.1:19200"
      "http://127.0.0.1:19014"
    ]
    && !(builtins.hasAttr "EXECUTOR_WEB_BASE_URL" container.environment)
    && !(builtins.hasAttr "EXECUTOR_ALLOW_LOCAL_NETWORK" container.environment)
  )
  "Executor v2 must use its public auth origin and separate private app-fetch and host-side MCP controls";
  assert lib.assertMsg (
    (container.environment.EXECUTOR_OAUTH_CLIENT_METADATA_URL or null) == "${endpoint.url}/oauth/client-metadata.json"
  )
  "Executor must publish its HTTPS client metadata document for OAuth providers such as Amp that support CIMD instead of dynamic registration";
  assert lib.assertMsg (
    builtins.elem "docker-executor.service" homelab.backup.archiveUnits
    && builtins.elem "/var/lib" config.services.borgbackup.jobs.main.paths
    && builtins.elem "/var/lib/executor-v2" config.custom.backup.manifestMetadata.expectedPrimaryStatePaths
  )
  "Executor state must be quiesced and archived";
  assert lib.assertMsg (
    config.systemd.services.homelab-mcp.environment.HOMELAB_MCP_HOST
    == "127.0.0.1"
    && config.systemd.services.homelab-mcp.environment.HOMELAB_MCP_PORT == "19200"
    && homelab.services.homelab-mcp.endpoint.exposure == "none"
    && builtins.elem "mcp-access-token:${config.sops.secrets.homelab-mcp-access-token.path}" config.systemd.services.homelab-mcp.serviceConfig.LoadCredential
    && builtins.elem "homelab-mcp.service" homelab.backup.archiveUnits
    && builtins.elem "/var/lib/private/homelab-mcp" config.custom.backup.manifestMetadata.expectedPrimaryStatePaths
  )
  "Homelab MCP must require a private credential, stay on loopback, and preserve its state in backups";
  assert lib.assertMsg (
    lib.all (credential: !(lib.hasInfix " " credential)) config.systemd.services.homelab-mcp.serviceConfig.LoadCredential
    && config.systemd.tmpfiles.settings."10-homelab-mcp-credentials"."/run/homelab-mcp-credentials".d.mode == "0700"
    && config.systemd.tmpfiles.settings."10-homelab-mcp-credentials"."/run/homelab-mcp-credentials/plex-preferences.xml"."L+".argument == "/var/lib/plex/Plex Media Server/Preferences.xml"
  )
  "Plex credentials must use a root-only path alias to avoid systemd 260's whitespace deserialization failure";
    pkgs.runCommand "executor-config-regression" {} ''
      touch "$out"
    ''
