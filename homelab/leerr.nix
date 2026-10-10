{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit (homelab.publicEndpoints) leerr;
  package = inputs.leerr.packages.${pkgs.stdenv.hostPlatform.system}.default;
  # From the certificate Plex serves (`*.<id>.plex.direct`).
  plexCertificateID = "2fd6fe7229f64309be6c9e3013c0b19d";
  dataDir = "/var/lib/leerr";
  # Offline maintenance with the service's own data and key; run as leerr with Leerr stopped.
  operatorCli = pkgs.writeShellScriptBin "leerr-operator" ''
    export LEERR_DATA=${dataDir}
    export LEERR_KEY_FILE=${config.sops.secrets.leerr-encryption-key.path}
    exec ${package}/bin/leerr-operator "$@"
  '';
in {
  # The package version is generic; record the locked source revision too.
  custom.backup.applicationVersions.leerr = "${package.version}-${inputs.leerr.shortRev}";

  # Leerr only talks to Plex over HTTPS, by a name its certificate covers. Pinning
  # the loopback name keeps the library and playback working without public DNS.
  networking.hosts."127.0.0.1" = ["127-0-0-1.${plexCertificateID}.plex.direct"];

  environment.systemPackages = [operatorCli];

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
      LEERR_DATA = dataDir;
      LEERR_KEY_FILE = config.sops.secrets.leerr-encryption-key.path;
      # Cloudflare Tunnel is the only proxy; trust only its loopback connection.
      LEERR_TRUST_PROXY = "127.0.0.1";
    };
    serviceConfig = {
      ExecStart = lib.getExe package;
      User = "leerr";
      Group = "leerr";
      StateDirectory = "leerr";
      StateDirectoryMode = "0700";
      WorkingDirectory = dataDir;
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
