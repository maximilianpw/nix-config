{
  config,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  endpoints =
    homelab.endpoints config.homelab.tailnet.domain
    // homelab.publicEndpoints;
  hostTimeZone = config.time.timeZone;
  mediaRoot = "/srv/media";
  usenetRoot = "${mediaRoot}/usenet";
  mediaGid = 971;
  qbitUid = 970;
  sabnzbdUid = 973;
  qbitContainerAddress = "10.89.0.2";
  qbitContainerPort = 8080;
  qbitNetworkInterface = "wg0-mullvad";
  sabContainerAddress = "10.89.1.2";
  sabContainerHostAddress = "10.89.1.1";
  sabContainerPort = 8080;
  mullvadConnectionGate = application: ''
    # These settings persist in Mullvad's state. Reasserting them makes every
    # downloader start fail closed, including the first boot before login.
    mullvad lockdown-mode set on
    mullvad lan set allow
    mullvad auto-connect set on
    mullvad connect

    for _attempt in {1..30}; do
      if mullvad status | grep --quiet '^Connected'; then
        exit 0
      fi
      sleep 2
    done

    echo "Mullvad did not connect; refusing to start ${application}" >&2
    exit 1
  '';
  mkDeferredVpnService = {
    serviceName,
    description,
    environment ? {},
    extraServiceConfig ? {},
    vpnGate,
  }: {
    services.${serviceName} = {
      # Waiting for the first interactive Mullvad login must not prevent the
      # container from reaching multi-user.target and reporting ready.
      wantedBy = lib.mkForce [];
      requires = ["mullvad-daemon.service"];
      after = ["mullvad-daemon.service"];
      inherit environment;
      serviceConfig =
        {
          ExecStartPre = vpnGate;
          Restart = "on-failure";
          RestartSec = "30s";
          UMask = "0002";
        }
        // extraServiceConfig;
    };
    timers."${serviceName}-deferred-start" = {
      inherit description;
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "15s";
        # Re-arm after dependency-driven stops as well as initial boot. This
        # lets the downloader recover when mullvad-daemon comes back.
        OnUnitInactiveSec = "30s";
        Unit = "${serviceName}.service";
      };
    };
  };
  mkVpnContainer = {
    hostAddress,
    localAddress,
    bindMounts,
    port,
    applicationModule,
  }: {
    autoStart = true;
    privateNetwork = true;
    enableTun = true;
    inherit hostAddress localAddress bindMounts;
    config = {
      imports = [applicationModule];
      system.stateVersion = "24.05";
      time.timeZone = hostTimeZone;
      networking = {
        useDHCP = false;
        useHostResolvConf = false;
        firewall.allowedTCPPorts = [port];
      };
      users.groups.media.gid = mediaGid;
      services = {
        resolved.enable = true;
        mullvad-vpn = {
          enable = true;
          enableEarlyBootBlocking = true;
          enableExcludeWrapper = false;
        };
      };
    };
  };
  downloadProxies = {
    qbittorrent-proxy = {
      application = "qBittorrent";
      container = "qbt";
      address = qbitContainerAddress;
      targetPort = qbitContainerPort;
      listenPort = endpoints.qbittorrent.port;
    };
    sabnzbd-proxy = {
      application = "SABnzbd";
      container = "sab";
      address = sabContainerAddress;
      targetPort = sabContainerPort;
      listenPort = endpoints.sabnzbd.port;
    };
  };
  mkContainerProxyService = _: proxy: {
    description = "${proxy.application} container WebUI proxy";
    requires = ["container@${proxy.container}.service"];
    after = ["container@${proxy.container}.service"];
    serviceConfig = {
      DynamicUser = true;
      ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd ${proxy.address}:${toString proxy.targetPort}";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
    };
  };
  mkContainerProxySocket = _: proxy: {
    description = "${proxy.application} loopback proxy socket";
    wantedBy = ["sockets.target"];
    socketConfig.ListenStream = "127.0.0.1:${toString proxy.listenPort}";
  };
  tunarrReconcileSettings = let
    ffmpeg = lib.getExe pkgs.ffmpeg;
    ffprobe = lib.getExe' pkgs.ffmpeg "ffprobe";
  in
    pkgs.writeShellScript "tunarr-reconcile-settings" ''
      exec ${lib.getExe pkgs.tunarr} --database /var/lib/tunarr settings update \
        --settings.ffmpeg.ffmpegExecutablePath=${ffmpeg} \
        --settings.ffmpeg.ffprobeExecutablePath=${ffprobe} \
        >/dev/null
    '';
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
  # Download and library paths share one ext4 filesystem so the Servarr apps
  # can import by hardlink while qBittorrent keeps seeding originals.
  users = {
    groups = {
      media.gid = mediaGid;
      tunarr = {};
    };
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
      tunarr = {
        isSystemUser = true;
        group = "tunarr";
        extraGroups = [
          "media"
          "render"
          "video"
        ];
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
        seerr.environment.HOST = "127.0.0.1";
        tunarr = {
          description = "Tunarr personal TV server";
          after = ["network-online.target"];
          wants = ["network-online.target"];
          wantedBy = ["multi-user.target"];
          path = [pkgs.libva-utils];
          environment = {
            HOME = "/var/lib/tunarr";
            TZ = config.time.timeZone;
            TUNARR_BIND_ADDR = "127.0.0.1";
            TUNARR_LOG_LEVEL = "info";
            TUNARR_SERVER_PORT = toString endpoints.tunarr.port;
          };
          serviceConfig = {
            User = "tunarr";
            Group = "tunarr";
            # Use the unambiguous CLI flag: v1.3.10's source and published docs
            # disagree about the corresponding environment variable's name.
            ExecStart = "${lib.getExe pkgs.tunarr} --database /var/lib/tunarr";
            ExecStartPre = tunarrReconcileSettings;
            InaccessiblePaths = [
              "${mediaRoot}/torrents"
              usenetRoot
            ];
            LockPersonality = true;
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
            ReadOnlyPaths = ["${mediaRoot}/library"];
            ReadWritePaths = ["/var/lib/tunarr"];
            Restart = "on-failure";
            RestartSec = "5s";
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_NETLINK"
              "AF_UNIX"
            ];
            RestrictSUIDSGID = true;
            StateDirectory = "tunarr";
            StateDirectoryMode = "0700";
            UMask = "0077";
            WorkingDirectory = "/var/lib/tunarr";
          };
        };

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

  containers.qbt = mkVpnContainer {
    hostAddress = "10.89.0.1";
    # The container module installs localAddress as a host route. Supplying a
    # subnet prefix here makes its generated `ip route add` reject the address.
    localAddress = qbitContainerAddress;
    port = qbitContainerPort;
    bindMounts.${mediaRoot + "/torrents"} = {
      hostPath = mediaRoot + "/torrents";
      isReadOnly = false;
    };

    applicationModule = {
      lib,
      pkgs,
      ...
    }: let
      qbitWebUICSRFProtection = "true";
      qbitWebUIHostHeaderValidation = "false";
      qbitWebUIMaxAuthenticationFailCount = "0";
      qbitBootstrapConfig = pkgs.writeText "qbittorrent-bootstrap.conf" ''
        [BitTorrent]
        Session\DefaultSavePath=${mediaRoot}/torrents/
        Session\TempPath=${mediaRoot}/torrents/incomplete/
        Session\TempPathEnabled=true

        [LegalNotice]
        Accepted=true

        [Preferences]
        Connection\Interface=${qbitNetworkInterface}
        General\Locale=en
        WebUI\Address=*
        WebUI\CSRFProtection=${qbitWebUICSRFProtection}
        WebUI\ClickjackingProtection=true
        # The loopback TCP proxy preserves localhost:18080 while qBittorrent
        # listens on 8080, so its strict port comparison cannot succeed.
        WebUI\HostHeaderValidation=${qbitWebUIHostHeaderValidation}
        # Every proxied client shares the host veth address. Do not let one
        # stale library-manager password ban the WebUI for every other client.
        WebUI\MaxAuthenticationFailCount=${qbitWebUIMaxAuthenticationFailCount}
        WebUI\Port=${toString qbitContainerPort}
        WebUI\SecureCookie=true
        WebUI\ServerDomains=${endpoints.qbittorrent.host};127.0.0.1;localhost;${qbitContainerAddress}
        WebUI\UseUPnP=false
      '';
      qbitPreStart = pkgs.writeShellApplication {
        name = "qbittorrent-vpn-prestart";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.gnused
          pkgs.mullvad
        ];
        text = ''
          ${builtins.readFile ../scripts/qbittorrent-vpn-prestart.sh}
          ${mullvadConnectionGate "qBittorrent"}
        '';
      };
    in {
      users.users.qbittorrent.uid = qbitUid;

      services.qbittorrent = {
        enable = true;
        group = "media";
        openFirewall = false;
        webuiPort = qbitContainerPort;
        extraArgs = ["--confirm-legal-notice"];
      };

      systemd = mkDeferredVpnService {
        serviceName = "qbittorrent";
        description = "Start qBittorrent after the container reports ready";
        environment = {
          QBIT_BOOTSTRAP_CONFIG = qbitBootstrapConfig;
          QBIT_NETWORK_INTERFACE = qbitNetworkInterface;
          QBIT_WEBUI_CSRF_PROTECTION = qbitWebUICSRFProtection;
          QBIT_WEBUI_HOST_HEADER_VALIDATION = qbitWebUIHostHeaderValidation;
          QBIT_WEBUI_MAX_AUTHENTICATION_FAIL_COUNT = qbitWebUIMaxAuthenticationFailCount;
        };
        # The leading + runs the leak check with full privileges even though
        # the daemon remains the unprivileged qBittorrent user.
        vpnGate = "+${lib.getExe qbitPreStart}";
      };
    };
  };

  containers.sab = mkVpnContainer {
    hostAddress = sabContainerHostAddress;
    localAddress = sabContainerAddress;
    port = sabContainerPort;
    # Keep SABnzbd's existing host state path to make this namespace move
    # migration-free; the separate container root preserves Mullvad's login.
    bindMounts = {
      ${usenetRoot} = {
        hostPath = usenetRoot;
        isReadOnly = false;
      };
      "/var/lib/sabnzbd" = {
        hostPath = "/var/lib/sabnzbd";
        isReadOnly = false;
      };
    };

    applicationModule = {
      lib,
      pkgs,
      ...
    }: let
      sabPreStart = pkgs.writeShellApplication {
        name = "sabnzbd-vpn-prestart";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.mullvad
        ];
        text = mullvadConnectionGate "SABnzbd";
      };
    in {
      nixpkgs.config.allowUnfreePredicate = package: lib.getName package == "unrar";
      users.users.sabnzbd.uid = sabnzbdUid;

      services.sabnzbd = {
        enable = true;
        # Preserve credentials entered in the WebUI while keeping network,
        # path, TLS, and category policy declarative.
        configFile = null;
        allowConfigWrite = true;
        group = "media";
        openFirewall = false;
        settings = {
          misc = {
            host = sabContainerAddress;
            port = sabContainerPort;
            download_dir = "${usenetRoot}/incomplete";
            complete_dir = "${usenetRoot}/complete";
            backup_dir = "/var/lib/sabnzbd/backups";
            permissions = "2775";
            host_whitelist = "${endpoints.sabnzbd.host}, localhost, 127.0.0.1, ${sabContainerAddress}";
            # The host veth is the only direct client. Tailscale Serve's XFF
            # value must also remain within the private tailnet ranges.
            local_ranges = "${sabContainerHostAddress}, 100.64.0.0/10, fd7a:115c:a1e0::/48";
            verify_xff_header = true;
          };
          servers.eweka = {
            name = "eweka";
            displayname = "Eweka";
            host = "news.eweka.nl";
            port = 563;
            connections = 20;
            ssl = true;
            ssl_verify = "strict";
            required = true;
            priority = 0;
          };
          categories = {
            "*" = {
              order = 0;
              pp = 3;
              script = "None";
              dir = "";
              priority = 0;
            };
            "sonarr-usenet" = {
              order = 1;
              pp = 3;
              script = "Default";
              dir = "tv";
              priority = 0;
            };
            "radarr-usenet" = {
              order = 2;
              pp = 3;
              script = "Default";
              dir = "movies";
              priority = 0;
            };
            "lidarr-usenet" = {
              order = 3;
              pp = 3;
              script = "Default";
              dir = "music";
              priority = 0;
            };
          };
        };
      };

      systemd = mkDeferredVpnService {
        serviceName = "sabnzbd";
        description = "Start SABnzbd after the container reports ready";
        # Keep the module's generated config reconciliation after the
        # privileged VPN gate instead of replacing its ExecStartPre.
        vpnGate = lib.mkBefore ["+${lib.getExe sabPreStart}"];
        extraServiceConfig.StateDirectoryMode = "0700";
      };
    };
  };
}
