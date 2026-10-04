{
  config,
  lib,
  pkgs,
  ...
}: let
  common = import ./common.nix {inherit config lib pkgs;};
  inherit (common) endpoints homelab mediaGid mediaRoot secondaryMediaRoot;
  managerConfigPaths = {
    sonarr = "/var/lib/sonarr/.config/NzbDrone/config.xml";
    radarr = "/var/lib/radarr/.config/Radarr/config.xml";
    lidarr = "/var/lib/lidarr/.config/Lidarr/config.xml";
  };
  managerCredentials = names: map (name: "${name}-config:${managerConfigPaths.${name}}") names;
  withManagerKeys = mappings: command: "${lib.getExe pkgs.python3} ${../../scripts/media-manager-api-env.py} ${lib.escapeShellArgs (lib.concatMap (mapping: ["--api-key" mapping]) mappings)} -- ${command}";
  privateService = stateDirectory: {
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectHome = true;
    ProtectSystem = "strict";
    RestrictSUIDSGID = true;
    StateDirectory = stateDirectory;
    StateDirectoryMode = "0700";
    UMask = "0077";
  };
  requiresSecondaryMedia = {
    requires = ["media-secondary-directories.service"];
    after = ["media-secondary-directories.service"];
    bindsTo = ["srv-media\\x2dsecondary.mount"];
    unitConfig.RequiresMountsFor = [secondaryMediaRoot];
  };
  # Recyclarr 8.6's progress display crops against a zero-height console in
  # systemd and redirected output. Let the table overflow instead of crashing.
  recyclarrPackage = pkgs.recyclarr.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace src/Recyclarr.Cli/Processors/Sync/Progress/SyncProgressRenderer.cs \
          --replace-fail '.AutoClear(false)' '.Overflow(VerticalOverflow.Visible).AutoClear(false)'
      '';
  });
  # API keys stay in systemd credentials and the child environment, never in
  # generated YAML, process arguments, or the Nix store.
  recyclarrConfig = pkgs.writeText "recyclarr.yml" ''
    sonarr:
      kim-sonarr:
        base_url: ${homelab.loopbackUrl endpoints.sonarr.port}
        api_key: !env_var SONARR_API_KEY
        quality_definition:
          type: series
        quality_profiles:
          - trash_id: 72dae194fc92bf828f32cde7744e51a1
            name: TRaSH WEB-1080p
    radarr:
      kim-radarr:
        base_url: ${homelab.loopbackUrl endpoints.radarr.port}
        api_key: !env_var RADARR_API_KEY
        quality_definition:
          type: movie
        quality_profiles:
          - trash_id: d1d67249d3890e49bc12e275d989a7e9
            name: TRaSH HD Bluray + WEB
  '';
  maintainerrImage = "ghcr.io/maintainerr/maintainerr@sha256:7487d374290e59add65407ec295629e489f9057dbf18e2a9dff70d6201ffb6f9";
  tdarrImage = "ghcr.io/haveagitgat/tdarr@sha256:b01f83c8b7d06c765422753d7b40f846ab7a227d2e792659d9f435315eaa31c4";
  kometaImage = "docker.io/kometateam/kometa@sha256:20388de48f0e088ad9feb9904f6a452fd9ef933a79c7b2bf186e388224e8f437";
in {
  custom.backup = {
    applicationVersions = {
      recyclarr = recyclarrPackage.version;
      unpackerr = pkgs.unpackerr.version;
      autobrr = config.services.autobrr.package.version;
      cross-seed = config.services.cross-seed.package.version;
      maintainerr = maintainerrImage;
      tdarr = tdarrImage;
      kometa = kometaImage;
    };
  };

  users = {
    groups = {
      recyclarr = {};
      unpackerr = {};
    };
    users = {
      recyclarr = {
        isSystemUser = true;
        group = "recyclarr";
      };
      unpackerr = {
        isSystemUser = true;
        group = "unpackerr";
        extraGroups = ["media"];
      };
      maintainerr = {
        isSystemUser = true;
        uid = 974;
        group = "media";
      };
      tdarr = {
        isSystemUser = true;
        uid = 975;
        group = "media";
      };
      kometa = {
        isSystemUser = true;
        uid = 976;
        group = "media";
      };
    };
  };

  services = {
    autobrr = {
      enable = true;
      openFirewall = false;
      secretFile = "/var/lib/autobrr-session/secret";
      settings = {
        host = "127.0.0.1";
        inherit (endpoints.autobrr) port;
        checkForUpdates = false;
      };
    };
    cross-seed = {
      enable = true;
      useGenConfigDefaults = true;
      settingsFile = "/var/lib/cross-seed/integrations.json";
      settings = {
        host = "127.0.0.1";
        port = homelab.services.cross-seed.endpoint.port;
        action = "save";
        matchMode = "strict";
        useClientTorrents = true;
        seasonFromEpisodes = null;
      };
    };
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      maintainerr = {
        # v3.29.0. Host networking lets it reach the existing loopback APIs;
        # its own UI still binds only to loopback.
        image = maintainerrImage;
        user = "974:${toString mediaGid}";
        volumes = ["/var/lib/maintainerr:/opt/data"];
        environment = {
          TZ = config.time.timeZone;
          UI_HOSTNAME = "127.0.0.1";
          UI_PORT = toString endpoints.maintainerr.port;
          TELEMETRY = "off";
        };
        extraOptions = ["--network=host" "--cap-drop=ALL" "--security-opt=no-new-privileges"];
      };
      tdarr = {
        # 2.92.01. One health-check worker; library mounts prohibit media writes.
        image = tdarrImage;
        ports = ["127.0.0.1:${toString endpoints.tdarr.port}:8265"];
        volumes = [
          "/var/lib/tdarr/server:/app/server"
          "/var/lib/tdarr/configs:/app/configs"
          "/var/lib/tdarr/logs:/app/logs"
          "${mediaRoot}/.tdarr-cache:/temp"
          "${mediaRoot}/library:${mediaRoot}/library:ro"
          "${secondaryMediaRoot}/library:${secondaryMediaRoot}/library:ro"
        ];
        environment = {
          TZ = config.time.timeZone;
          PUID = "975";
          PGID = toString mediaGid;
          UMASK_SET = "002";
          serverIP = "0.0.0.0";
          serverPort = "8266";
          webUIPort = "8265";
          internalNode = "true";
          inContainer = "true";
          nodeName = "kim";
          openBrowser = "false";
          startPaused = "false";
          transcodecpuWorkers = "0";
          transcodegpuWorkers = "0";
          healthcheckcpuWorkers = "1";
          healthcheckgpuWorkers = "0";
          cronPluginUpdate = "";
          maxLogSizeMB = "10";
        };
        extraOptions = [
          "--device=/dev/dri:/dev/dri"
          "--group-add=${toString config.users.groups.render.gid}"
          "--group-add=${toString config.users.groups.video.gid}"
        ];
      };
      kometa = {
        # v2.5.1. A private config supplies Plex/TMDb tokens and collection rules.
        image = kometaImage;
        user = "976:${toString mediaGid}";
        volumes = ["/var/lib/kometa:/config"];
        environment = {
          TZ = config.time.timeZone;
          KOMETA_CONFIG = "/config/config.yml";
          KOMETA_TIMES = "03:15";
        };
        extraOptions = ["--network=host" "--cap-drop=ALL" "--security-opt=no-new-privileges"];
      };
    };
  };

  systemd = {
    tmpfiles.settings."10-media-companions" = {
      "/var/lib/maintainerr".d = {
        mode = "0700";
        user = "maintainerr";
        group = "media";
      };
      "/var/lib/kometa".d = {
        mode = "0700";
        user = "kometa";
        group = "media";
      };
      "/var/lib/tdarr".d = {
        mode = "0700";
        user = "tdarr";
        group = "media";
      };
      "/var/lib/tdarr/server".d = {
        mode = "0700";
        user = "tdarr";
        group = "media";
      };
      "/var/lib/tdarr/configs".d = {
        mode = "0700";
        user = "tdarr";
        group = "media";
      };
      "/var/lib/tdarr/logs".d = {
        mode = "0700";
        user = "tdarr";
        group = "media";
      };
      "${mediaRoot}/.tdarr-cache".d = {
        mode = "0700";
        user = "tdarr";
        group = "media";
      };
    };
    timers.recyclarr = {
      description = "Sync TRaSH profiles for Kim's media managers";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "10m";
      };
    };
    services = {
      recyclarr = {
        description = "Sync Sonarr and Radarr quality profiles";
        requires = ["sonarr.service" "radarr.service"];
        after = ["network-online.target" "sonarr.service" "radarr.service"];
        wants = ["network-online.target"];
        environment = {
          RECYCLARR_CONFIG_DIR = "/var/lib/recyclarr";
          RECYCLARR_DATA_DIR = "/var/lib/recyclarr";
        };
        serviceConfig =
          privateService "recyclarr"
          // {
            Type = "oneshot";
            User = "recyclarr";
            Group = "recyclarr";
            LoadCredential = managerCredentials ["sonarr" "radarr"];
            ExecStart = withManagerKeys ["SONARR_API_KEY=sonarr-config" "RADARR_API_KEY=radarr-config"] "${lib.getExe recyclarrPackage} sync --config ${recyclarrConfig}";
          };
      };
      unpackerr = lib.recursiveUpdate requiresSecondaryMedia {
        description = "Extract archived torrent downloads for the media managers";
        wantedBy = ["multi-user.target"];
        requires = requiresSecondaryMedia.requires ++ ["sonarr.service" "radarr.service" "lidarr.service"];
        after = requiresSecondaryMedia.after ++ ["sonarr.service" "radarr.service" "lidarr.service"];
        environment = {
          UN_SONARR_0_URL = homelab.loopbackUrl endpoints.sonarr.port;
          UN_RADARR_0_URL = homelab.loopbackUrl endpoints.radarr.port;
          UN_LIDARR_0_URL = homelab.loopbackUrl endpoints.lidarr.port;
          UN_SONARR_0_PROTOCOLS = "torrent,TorrentDownloadProtocol";
          UN_RADARR_0_PROTOCOLS = "torrent,TorrentDownloadProtocol";
          UN_LIDARR_0_PROTOCOLS = "torrent,TorrentDownloadProtocol";
          UN_SONARR_0_DELETE_ORIG = "false";
          UN_RADARR_0_DELETE_ORIG = "false";
          UN_LIDARR_0_DELETE_ORIG = "false";
        };
        serviceConfig =
          privateService "unpackerr"
          // {
            User = "unpackerr";
            Group = "unpackerr";
            UMask = "0002";
            LoadCredential = managerCredentials ["sonarr" "radarr" "lidarr"];
            ExecStart = withManagerKeys ["UN_SONARR_0_API_KEY=sonarr-config" "UN_RADARR_0_API_KEY=radarr-config" "UN_LIDARR_0_API_KEY=lidarr-config"] (lib.getExe pkgs.unpackerr);
            ReadWritePaths = ["${mediaRoot}/torrents" "${secondaryMediaRoot}/torrents"];
            Restart = "on-failure";
            RestartSec = "10s";
          };
      };
      autobrr-session = {
        description = "Create Autobrr's persistent session secret";
        before = ["autobrr.service"];
        serviceConfig =
          privateService "autobrr-session"
          // {
            Type = "oneshot";
            RemainAfterExit = true;
          };
        script = ''
          if [ ! -s /var/lib/autobrr-session/secret ]; then
            ${lib.getExe pkgs.openssl} rand -hex 32 > /var/lib/autobrr-session/secret
          fi
        '';
      };
      autobrr = {
        requires = ["autobrr-session.service"];
        after = ["autobrr-session.service"];
        serviceConfig = {
          StateDirectoryMode = "0700";
          UMask = "0077";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
        };
      };
      cross-seed = lib.recursiveUpdate requiresSecondaryMedia {
        # No tracker credentials exist in Nix. The operator installs this
        # root-readable JSON file before starting the daemon.
        unitConfig.ConditionPathExists = "/var/lib/cross-seed/integrations.json";
        serviceConfig = privateService "cross-seed";
      };
      docker-tdarr = requiresSecondaryMedia;
      docker-kometa.unitConfig.ConditionPathExists = "/var/lib/kometa/config.yml";
    };
  };
}
