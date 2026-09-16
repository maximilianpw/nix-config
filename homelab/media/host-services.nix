{
  config,
  lib,
  pkgs,
  ...
}: let
  common = import ./common.nix {inherit config lib pkgs;};
  inherit
    (common)
    downloadProxies
    endpoints
    homelab
    mediaGid
    mediaRoot
    mkContainerProxyService
    mkContainerProxySocket
    qbitUid
    sabnzbdUid
    usenetRoot
    ;
  prowlarrReconcile = pkgs.writeShellApplication {
    name = "prowlarr-reconcile";
    runtimeInputs = [pkgs.coreutils pkgs.curl pkgs.gnused pkgs.jq];
    text = ''
      export CURL_BIN=${lib.getExe pkgs.curl}
      export JQ_BIN=${lib.getExe pkgs.jq}
      export SED_BIN=${lib.getExe pkgs.gnused}
      export SLEEP_BIN=${lib.getExe' pkgs.coreutils "sleep"}
      export PROWLARR_CONFIG_FILE=/var/lib/prowlarr/config.xml
      export PROWLARR_URL=${lib.escapeShellArg (homelab.loopbackUrl endpoints.prowlarr.port)}
      exec ${lib.getExe pkgs.bash} ${../../scripts/prowlarr-reconcile.sh}
    '';
  };
  mediaDirectories = [
    mediaRoot
    "${mediaRoot}/torrents"
    "${mediaRoot}/torrents/incomplete"
    "${mediaRoot}/torrents/movies"
    "${mediaRoot}/torrents/music"
    "${mediaRoot}/torrents/tv"
    usenetRoot
    "${usenetRoot}/incomplete"
    "${usenetRoot}/complete"
    "${usenetRoot}/complete/movies"
    "${usenetRoot}/complete/music"
    "${usenetRoot}/complete/tv"
    "${mediaRoot}/library"
    "${mediaRoot}/library/movies"
    "${mediaRoot}/library/music"
    "${mediaRoot}/library/tv"
  ];
  sharedMediaDirectory = {
    mode = "2775";
    user = "root";
    group = "media";
  };
in {
  custom.backup.applicationVersions = {
    bazarr = config.services.bazarr.package.version;
    jellyfin = config.services.jellyfin.package.version;
    lidarr = config.services.lidarr.package.version;
    prowlarr = config.services.prowlarr.package.version;
    radarr = config.services.radarr.package.version;
    seerr = config.services.seerr.package.version;
    sonarr = config.services.sonarr.package.version;
  };

  # Download and library paths share one ext4 filesystem so the Servarr apps
  # can import by hardlink while qBittorrent keeps seeding originals.
  users = {
    groups.media.gid = mediaGid;
    users = {
      # Reserve the bind-mount owner on the host as well as inside the
      # container; otherwise an unrelated dynamically allocated host user
      # could receive the same numeric identity and gain owner access.
      qbittorrent = {
        uid = qbitUid;
        group = "media";
        isSystemUser = true;
      };
      sabnzbd = {
        uid = sabnzbdUid;
        group = "media";
        isSystemUser = true;
      };
      jellyfin.extraGroups = [
        "media"
        "render"
        "video"
      ];
    };
  };

  services = {
    bazarr = {
      enable = true;
      group = "media";
      openFirewall = false;
      listenPort = endpoints.bazarr.port;
    };

    jellyfin = {
      enable = true;
      openFirewall = false;
      hardwareAcceleration = {
        enable = true;
        type = "vaapi";
        device = "/dev/dri/renderD128";
      };
      # Kim's Radeon VCN supports these common decode paths. The NixOS module
      # always enables H.264 encoding; enable HEVC and AV1 explicitly as well.
      # Jellyfin writes this only on first boot so later dashboard changes are
      # not silently replaced. The deployment runbook verifies every profile.
      transcoding = {
        enableHardwareEncoding = true;
        hardwareDecodingCodecs = {
          h264 = true;
          hevc = true;
          hevc10bit = true;
          vp9 = true;
          av1 = true;
        };
        hardwareEncodingCodecs = {
          hevc = true;
          av1 = true;
        };
      };
    };

    lidarr = {
      enable = true;
      group = "media";
      openFirewall = false;
      settings.server = {
        bindaddress = "127.0.0.1";
        inherit (endpoints.lidarr) port;
      };
    };

    sonarr = {
      enable = true;
      group = "media";
      openFirewall = false;
      settings.server = {
        bindaddress = "127.0.0.1";
        inherit (endpoints.sonarr) port;
      };
    };

    radarr = {
      enable = true;
      group = "media";
      openFirewall = false;
      settings.server = {
        bindaddress = "127.0.0.1";
        inherit (endpoints.radarr) port;
      };
    };

    prowlarr = {
      enable = true;
      openFirewall = false;
      settings.server = {
        bindaddress = "127.0.0.1";
        inherit (endpoints.prowlarr) port;
      };
    };

    seerr = {
      enable = true;
      openFirewall = false;
      inherit (endpoints.seerr) port;
    };
  };

  # Headless Kim still needs Mesa's userspace stack for VA-API.
  hardware.graphics.enable = true;
  systemd = {
    tmpfiles.settings = {
      "10-media" = lib.genAttrs mediaDirectories (_: {d = sharedMediaDirectory;});
      # This is both SABnzbd's private state and the pre-created host source
      # for the container bind mount, preserving the existing deployment.
      "10-sabnzbd"."/var/lib/sabnzbd".d = {
        mode = "0700";
        user = "sabnzbd";
        group = "media";
      };
    };

    services =
      {
        bazarr = {
          environment.DYNACONF_GENERAL__IP = "127.0.0.1";
          serviceConfig.UMask = lib.mkForce "0002";
        };
        lidarr.serviceConfig.UMask = lib.mkForce "0002";
        sonarr.serviceConfig.UMask = lib.mkForce "0002";
        radarr.serviceConfig.UMask = lib.mkForce "0002";
        # Mutable-state reconciliation must report errors without taking the
        # search service down or causing an activation restart loop.
        prowlarr.serviceConfig.ExecStartPost = lib.mkAfter ["-${lib.getExe prowlarrReconcile}"];
        seerr.environment.HOST = "127.0.0.1";
        # Jellyfin can manage the shared group-writable library but cannot see
        # active downloads.
        jellyfin.serviceConfig = {
          InaccessiblePaths = [
            "${mediaRoot}/torrents"
            usenetRoot
          ];
          UMask = lib.mkForce "0002";
        };
      }
      // lib.mapAttrs mkContainerProxyService downloadProxies;

    # Socket activation exposes each downloader WebUI only on host loopback.
    # Tailscale Serve and the library managers use these guarded endpoints.
    sockets = lib.mapAttrs mkContainerProxySocket downloadProxies;
  };

  # Playback is available on the physical LAN and through Cloudflare. Other
  # administrative services remain closed on every host interface.
  networking.firewall.interfaces.enp194s0 = {
    allowedTCPPorts = [endpoints.jellyfin.port];
    allowedUDPPorts = [7359];
  };

  # Only the downloader veths are NATed to the physical uplink. Mullvad runs
  # inside each namespace, so it cannot replace Kim's routes or affect Tailscale.
  networking.nat = {
    enable = true;
    externalInterface = "enp194s0";
    internalInterfaces = [
      "ve-qbt"
      "ve-sab"
    ];
  };
}
