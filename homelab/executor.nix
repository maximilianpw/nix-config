{lib, ...}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit (homelab.publicEndpoints) executor;
  image = "ghcr.io/usefulsoftwareco/executor-selfhost@sha256:3dff4d002d96a86b741a33af9560431b963961f024fff5fedb41db79396435c8";
in {
  custom.backup.applicationVersions.executor = image;

  virtualisation.oci-containers = {
    backend = "docker";
    containers.executor = {
      # Updated within the v2 release/beta line by make update-container-images.
      inherit image;
      # The homelab MCP and portfolio API listen only on host loopback.
      extraOptions = ["--network=host" "--init"];
      volumes = ["/var/lib/executor-v2:/app/data"];
      environment = {
        PORT = toString executor.port;
        HOST = "127.0.0.1";
        EXECUTOR_DATA_DIR = "/app/data";
        BETTER_AUTH_URL = executor.url;
        # Amp supports client-ID metadata documents, not dynamic registration.
        EXECUTOR_OAUTH_CLIENT_METADATA_URL = "${executor.url}/oauth/client-metadata.json";
        EXECUTOR_APPS_ALLOW_PRIVATE_FETCH = "true";
        EXECUTOR_URL_ALLOW_HTTP_ORIGINS = builtins.toJSON [
          "http://127.0.0.1:19200"
          "http://127.0.0.1:19014"
        ];
      };
    };
  };

  # Never expose a fresh first-admin setup at the production hostname.
  systemd.services.docker-executor.preStart = lib.mkBefore ''
    test -s /var/lib/executor-v2/auth-secret.key
    test -s /var/lib/executor-v2/encryption.key
  '';

  systemd.tmpfiles.settings."10-executor"."/var/lib/executor-v2".d = {
    user = "1000";
    group = "1000";
    mode = "0700";
  };
}
