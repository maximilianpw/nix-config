{
  config,
  lib,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit ((homelab.endpoints config.homelab.tailnet.domain)) executor;
in {
  custom.backup.applicationVersions.executor = config.virtualisation.oci-containers.containers.executor.image;

  virtualisation.oci-containers = {
    backend = "docker";
    containers.executor = {
      # v1.5.42, pinned to the reviewed multi-platform image index.
      image = "ghcr.io/rhyssullivan/executor-selfhost@sha256:3fb4e7fdcd639dd5c8d3de51d168e6d3b78654a156a4f5f323a2f986565cb4dc";
      ports = ["127.0.0.1:${toString executor.port}:4788"];
      volumes = ["/var/lib/executor:/data"];
      environment = {
        PORT = "4788";
        EXECUTOR_HOST = "0.0.0.0";
        EXECUTOR_DATA_DIR = "/data";
        EXECUTOR_WEB_BASE_URL = executor.url;
        EXECUTOR_ALLOW_LOCAL_NETWORK = "false";
      };
    };
  };

  systemd.tmpfiles.settings."10-executor"."/var/lib/executor".d = {
    user = "root";
    group = "root";
    mode = "0700";
  };
}
