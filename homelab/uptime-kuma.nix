{
  config,
  homelab,
  ...
}: let
  inherit (homelab.privateServices) kuma;
in {
  custom.backup.applicationVersions.kuma = config.services.uptime-kuma.package.version;

  services.uptime-kuma = {
    enable = true;
    appriseSupport = true;
    settings = {
      HOST = "127.0.0.1";
      PORT = toString kuma.port;
    };
  };
}
