{
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit (homelab.publicEndpoints) executor;
  image = "ghcr.io/usefulsoftwareco/executor-selfhost@sha256:200315d519a8c19685de05e88aa9a3cf1e1cb9869a2b0aecf604f6ebf47c6ea1";
in {
  custom.backup.applicationVersions.executor = image;

  virtualisation.oci-containers = {
    backend = "docker";
    containers.executor = {
      # v1.6.8, pinned to the reviewed multi-platform image index.
      # UsefulSoftwareCo is the canonical upstream namespace after the org move.
      inherit image;
      # Host networking gives the container access to the loopback-only homelab MCP.
      extraOptions = [
        "--network=host"
        # The image checks its default port (4788), but we configure PORT below.
        # Keep the inherited healthcheck timings and check the actual listener.
        ''--health-cmd=bun -e "fetch('http://127.0.0.1:${toString executor.port}/api/health').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"''
      ];
      volumes = [
        "/var/lib/executor:/data"
        # Docker's --health-cmd uses CMD-SHELL even though this image has no sh.
        # A static shell needs no host libraries; mount only that binary read-only.
        "${pkgs.pkgsStatic.busybox}/bin/busybox:/bin/sh:ro"
      ];
      environment = {
        PORT = toString executor.port;
        EXECUTOR_HOST = "127.0.0.1";
        EXECUTOR_DATA_DIR = "/data";
        EXECUTOR_WEB_BASE_URL = executor.url;
        EXECUTOR_ALLOW_LOCAL_NETWORK = "true";
      };
    };
  };

  systemd.tmpfiles.settings."10-executor"."/var/lib/executor".d = {
    user = "root";
    group = "root";
    mode = "0700";
  };
}
