{lib, ...}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit (homelab.publicEndpoints) executor;
in {
  virtualisation.oci-containers = {
    backend = "docker";
    containers.executor = {
      # v1.6.8, pinned to the reviewed multi-platform image index.
      # UsefulSoftwareCo is the canonical upstream namespace after the org move.
      image = "ghcr.io/usefulsoftwareco/executor-selfhost@sha256:200315d519a8c19685de05e88aa9a3cf1e1cb9869a2b0aecf604f6ebf47c6ea1";
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
