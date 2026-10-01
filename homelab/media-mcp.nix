{
  config,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  package = pkgs.callPackage ../packages/homelab-mcp.nix {};
in {
  custom.backup.applicationVersions.homelab-mcp = package.version;

  sops.secrets.homelab-mcp-access-token = {
    sopsFile = ../secrets/homelab-mcp.yaml;
    restartUnits = ["homelab-mcp.service"];
  };

  systemd.services.homelab-mcp = {
    description = "Homelab media MCP for Executor";
    wantedBy = ["multi-user.target"];
    after = ["network.target" "sops-nix.service" "sonarr.service" "radarr.service" "lidarr.service" "prowlarr.service" "seerr.service" "plex.service"];
    environment = {
      HOMELAB_MCP_HOST = "127.0.0.1";
      HOMELAB_MCP_PORT = toString homelab.services.homelab-mcp.endpoint.port;
    };
    serviceConfig = {
      ExecStart = lib.getExe package;
      DynamicUser = true;
      StateDirectory = "homelab-mcp";
      StateDirectoryMode = "0700";
      UMask = "0077";
      LoadCredential = [
        "mcp-access-token:${config.sops.secrets.homelab-mcp-access-token.path}"
        "sonarr-config.xml:/var/lib/sonarr/.config/NzbDrone/config.xml"
        "radarr-config.xml:/var/lib/radarr/.config/Radarr/config.xml"
        "lidarr-config.xml:/var/lib/lidarr/.config/Lidarr/config.xml"
        "prowlarr-config.xml:/var/lib/prowlarr/config.xml"
        "seerr-settings.json:/var/lib/jellyseerr/config/settings.json"
        "plex-preferences.xml:/var/lib/plex/Plex Media Server/Preferences.xml"
      ];
      Restart = "on-failure";
      RestartSec = "5s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      CapabilityBoundingSet = "";
      RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
    };
  };
}
