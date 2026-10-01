{
  config,
  lib,
  pkgs,
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  endpoint = homelab.publicEndpoints.executor;
  ingress = config.services.cloudflared.tunnels.${homelab.infrastructure.cloudflare.tunnelId}.ingress;
  container = config.virtualisation.oci-containers.containers.executor;
  image = "ghcr.io/usefulsoftwareco/executor-selfhost@sha256:200315d519a8c19685de05e88aa9a3cf1e1cb9869a2b0aecf604f6ebf47c6ea1";
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
    && container.environment.EXECUTOR_HOST == "127.0.0.1"
    && container.environment.PORT == toString endpoint.port
  )
  "Executor must only publish its HTTP endpoint on loopback";
  assert lib.assertMsg (container.volumes == ["/var/lib/executor:/data"])
  "Executor must persist its database and generated encryption keys outside Docker";
  assert lib.assertMsg (
    container.environment.EXECUTOR_WEB_BASE_URL
    == endpoint.url
    && container.environment.EXECUTOR_ALLOW_LOCAL_NETWORK == "true"
  )
  "Executor must use its exact public URL and allow the local homelab MCP";
  assert lib.assertMsg (
    builtins.elem "docker-executor.service" homelab.backup.archiveUnits
    && builtins.elem "/var/lib" config.services.borgbackup.jobs.main.paths
    && builtins.elem "/var/lib/executor" config.custom.backup.manifestMetadata.expectedPrimaryStatePaths
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
