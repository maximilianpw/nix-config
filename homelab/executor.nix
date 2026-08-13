{
  config,
  lib,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit ((homelab.endpoints config.homelab.tailnet.domain)) executor;
in {
  virtualisation.oci-containers = {
    backend = "docker";
    containers.executor = {
      image = "ghcr.io/rhyssullivan/executor-selfhost@sha256:125123681a14e44d679f22d259ce178bf605886e54c10b5b08b09b19c09f4695";
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
