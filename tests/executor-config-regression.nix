{
  config,
  lib,
  pkgs,
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  endpoint = homelab.publicEndpoints.executor;
  ingress = config.services.cloudflared.tunnels.${homelab.infrastructure.cloudflare.tunnelId}.ingress;
  container = config.virtualisation.oci-containers.containers.executor;
  image = "ghcr.io/rhyssullivan/executor-selfhost@sha256:3fb4e7fdcd639dd5c8d3de51d168e6d3b78654a156a4f5f323a2f986565cb4dc";
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
    == "https://executor.maximilian.pw"
    && ingress.${endpoint.host}.service == homelab.loopbackUrl endpoint.port
    && ingress.${endpoint.host}.originRequest.httpHostHeader == endpoint.host
  )
  "Cloudflare must route executor.maximilian.pw to Executor's loopback endpoint";
  assert lib.assertMsg (config.virtualisation.oci-containers.backend == "docker")
  "Executor must use Kim's existing Docker backend";
  assert lib.assertMsg (container.image == image)
  "Executor must use the reviewed immutable image digest";
  assert lib.assertMsg (container.ports == ["127.0.0.1:${toString endpoint.port}:4788"])
  "Executor must only publish its HTTP endpoint on loopback";
  assert lib.assertMsg (container.volumes == ["/var/lib/executor:/data"])
  "Executor must persist its database and generated encryption keys outside Docker";
  assert lib.assertMsg (
    container.environment.EXECUTOR_WEB_BASE_URL
    == endpoint.url
    && container.environment.EXECUTOR_ALLOW_LOCAL_NETWORK == "false"
  )
  "Executor must use its exact public URL and deny sandbox access to private networks";
  assert lib.assertMsg (
    builtins.elem "docker-executor.service" homelab.backup.archiveUnits
    && builtins.elem "/var/lib" config.services.borgbackup.jobs.main.paths
    && builtins.elem "/var/lib/executor" config.custom.backup.manifestMetadata.expectedPrimaryStatePaths
    && config.custom.backup.manifestMetadata.applicationVersions.executor == image
  )
  "Executor state must be quiesced, archived, and tied to its image in the recovery manifest";
    pkgs.runCommand "executor-config-regression" {} ''
      touch "$out"
    ''
