{config, ...}: {
  sops.secrets.miniflux-admin-credentials = {
    restartUnits = ["miniflux.service"];
  };

  services.miniflux = {
    enable = true;
    createDatabaseLocally = true;
    adminCredentialsFile = config.sops.secrets.miniflux-admin-credentials.path;
    config = {
      LISTEN_ADDR = "127.0.0.1:3002";
      BASE_URL = "https://miniflux.maximilian.pw";
    };
  };
}
