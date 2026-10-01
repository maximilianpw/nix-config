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

  # systemd 260.4 fails to deserialize LoadCredential paths containing spaces.
  # A root-only alias avoids that bug without copying Plex's mutable credentials.
  systemd.tmpfiles.settings."10-homelab-mcp-credentials" = {
    "/run/homelab-mcp-credentials".d = {
      user = "root";
      group = "root";
      mode = "0700";
    };
    "/run/homelab-mcp-credentials/plex-preferences.xml"."L+".argument = "/var/lib/plex/Plex Media Server/Preferences.xml";
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
        "plex-preferences.xml:/run/homelab-mcp-credentials/plex-preferences.xml"
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
