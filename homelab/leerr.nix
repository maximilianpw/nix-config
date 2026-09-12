{
  config,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit ((homelab.endpoints config.homelab.tailnet.domain)) leerr;
  package = pkgs.callPackage ../packages/leerr.nix {};
in {
  sops.secrets.leerr-encryption-key = {
    sopsFile = ../secrets/leerr.yaml;
    owner = "leerr";
    mode = "0400";
    restartUnits = ["leerr.service"];
  };

  users.users.leerr = {
    isSystemUser = true;
    group = "leerr";
  };
  users.groups.leerr = {};

  systemd.services.leerr = {
    description = "Leerr music library and requests";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target" "sops-nix.service"];
    environment = {
      NODE_ENV = "production";
      HOST = "127.0.0.1";
      PORT = toString leerr.port;
      LEERR_ORIGIN = leerr.url;
      LEERR_DATA = "/var/lib/leerr";
      LEERR_KEY_FILE = config.sops.secrets.leerr-encryption-key.path;
      # Tailscale Serve is the only proxy; do not trust forwarded client IPs.
      LEERR_TRUST_PROXY = "127.0.0.1";
    };
    serviceConfig = {
      ExecStart = lib.getExe package;
      User = "leerr";
      Group = "leerr";
      StateDirectory = "leerr";
      StateDirectoryMode = "0700";
      WorkingDirectory = "/var/lib/leerr";
      UMask = "0077";
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
