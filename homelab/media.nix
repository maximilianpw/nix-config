{
  config,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  endpoints = homelab.endpoints config.homelab.tailnet.domain;
  mediaRoot = "/srv/media";
  mediaGid = 971;
  qbitUid = 970;
  qbitContainerAddress = "10.89.0.2";
  qbitContainerPort = 8080;
  qbitNetworkInterface = "wg0-mullvad";
  mediaDirectories = [
    mediaRoot
    "${mediaRoot}/torrents"
    "${mediaRoot}/torrents/incomplete"
    "${mediaRoot}/torrents/movies"
    "${mediaRoot}/torrents/tv"
    "${mediaRoot}/library"
    "${mediaRoot}/library/movies"
    "${mediaRoot}/library/tv"
  ];
  sharedMediaDirectory = {
    mode = "2775";
    user = "root";
    group = "media";
  };
in {
  # Download and library paths share one ext4 filesystem so Sonarr and Radarr
  # can import by hardlink while qBittorrent keeps seeding the original name.
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
      jellyfin.extraGroups = [
        "media"
        "render"
        "video"
      ];
    };
  };

  services = {
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
    tmpfiles.settings."10-media" = lib.genAttrs mediaDirectories (_: {d = sharedMediaDirectory;});

    services = {
      sonarr.serviceConfig.UMask = lib.mkForce "0002";
      radarr.serviceConfig.UMask = lib.mkForce "0002";

      # Jellyfin can traverse the shared group-owned tree but cannot see active
      # downloads or mutate the finished library, even if its UI grants delete.
      jellyfin.serviceConfig = {
        InaccessiblePaths = ["${mediaRoot}/torrents"];
        ReadOnlyPaths = ["${mediaRoot}/library"];
      };

      # Socket activation exposes the container WebUI only on host loopback.
      # Tailscale Serve, Sonarr, and Radarr use this one guarded endpoint.
      qbittorrent-proxy = {
        description = "qBittorrent container WebUI proxy";
        requires = ["container@qbt.service"];
        after = ["container@qbt.service"];
        serviceConfig = {
          DynamicUser = true;
          ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd ${qbitContainerAddress}:${toString qbitContainerPort}";
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
    };

    sockets.qbittorrent-proxy = {
      description = "qBittorrent loopback proxy socket";
      wantedBy = ["sockets.target"];
      socketConfig.ListenStream = "127.0.0.1:${toString endpoints.qbittorrent.port}";
    };
  };

  # Playback is private to the physical LAN plus the HTTPS tailnet endpoint.
  # The administrative services remain closed on every host interface.
  networking.firewall.interfaces.enp194s0 = {
    allowedTCPPorts = [endpoints.jellyfin.port];
    allowedUDPPorts = [7359];
  };

  # Only this private veth is NATed to the physical uplink. Mullvad runs inside
  # the namespace, so it cannot replace Kim's routes or interfere with Tailscale.
  networking.nat = {
    enable = true;
    externalInterface = "enp194s0";
    internalInterfaces = ["ve-qbt"];
  };

  containers.qbt = {
    autoStart = true;
    privateNetwork = true;
    enableTun = true;
    hostAddress = "10.89.0.1";
    # The container module installs localAddress as a host route. Supplying a
    # subnet prefix here makes its generated `ip route add` reject the address.
    localAddress = qbitContainerAddress;
    bindMounts.${mediaRoot + "/torrents"} = {
      hostPath = mediaRoot + "/torrents";
      isReadOnly = false;
    };

    config = {
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
        # stale Sonarr/Radarr password ban the WebUI for every other client.
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
          config_file=/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf
          if [[ ! -e "$config_file" ]]; then
            install -Dm0600 -o qbittorrent -g media ${qbitBootstrapConfig} "$config_file"
          fi

          set_preference() {
            key="$1"
            value="$2"
            escaped_key="$(printf '%s' "$key" | sed 's/\\/\\\\/g')"

            if grep --fixed-strings --quiet "$key=" "$config_file"; then
              sed --in-place "\|^$escaped_key=|c\\$escaped_key=$value" "$config_file"
            else
              sed --in-place "/^\[Preferences\]$/a\\$escaped_key=$value" "$config_file"
            fi
          }

          # qBittorrent rewrites its config after WebUI changes, so reconcile
          # the VPN and proxy/security contract on every start without
          # replacing the operator-managed username or password hash.
          set_preference 'Connection\Interface' "$QBIT_NETWORK_INTERFACE"
          set_preference 'WebUI\CSRFProtection' "$QBIT_WEBUI_CSRF_PROTECTION"
          set_preference 'WebUI\HostHeaderValidation' "$QBIT_WEBUI_HOST_HEADER_VALIDATION"
          set_preference 'WebUI\MaxAuthenticationFailCount' "$QBIT_WEBUI_MAX_AUTHENTICATION_FAIL_COUNT"

          # These settings persist in Mullvad's state. Reasserting them makes
          # every qBittorrent start fail closed, including the first boot before
          # the operator has logged this container into their Mullvad account.
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

          echo "Mullvad did not connect; refusing to start qBittorrent" >&2
          exit 1
        '';
      };
    in {
      system.stateVersion = "24.05";

      networking = {
        useDHCP = false;
        useHostResolvConf = false;
        firewall.allowedTCPPorts = [qbitContainerPort];
      };
      users = {
        groups.media.gid = mediaGid;
        users.qbittorrent.uid = qbitUid;
      };

      services = {
        resolved.enable = true;
        mullvad-vpn = {
          enable = true;
          enableEarlyBootBlocking = true;
          enableExcludeWrapper = false;
        };
        qbittorrent = {
          enable = true;
          group = "media";
          openFirewall = false;
          webuiPort = qbitContainerPort;
          extraArgs = ["--confirm-legal-notice"];
        };
      };

      systemd = {
        services.qbittorrent = {
          # Waiting for the first interactive Mullvad login must not prevent
          # the container from reaching multi-user.target and reporting ready
          # to the host activation. A timer starts the fail-closed daemon after
          # boot; Restart=on-failure keeps retrying until Mullvad connects.
          wantedBy = lib.mkForce [];
          requires = ["mullvad-daemon.service"];
          after = ["mullvad-daemon.service"];
          environment = {
            QBIT_NETWORK_INTERFACE = qbitNetworkInterface;
            QBIT_WEBUI_CSRF_PROTECTION = qbitWebUICSRFProtection;
            QBIT_WEBUI_HOST_HEADER_VALIDATION = qbitWebUIHostHeaderValidation;
            QBIT_WEBUI_MAX_AUTHENTICATION_FAIL_COUNT = qbitWebUIMaxAuthenticationFailCount;
          };
          serviceConfig = {
            # The leading + runs the leak check with full privileges even
            # though the daemon remains the unprivileged qbittorrent user.
            ExecStartPre = "+${lib.getExe qbitPreStart}";
            RestartSec = "30s";
            UMask = "0002";
          };
        };

        timers.qbittorrent-deferred-start = {
          description = "Start qBittorrent after the container reports ready";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "15s";
            Unit = "qbittorrent.service";
          };
        };
      };
    };
  };
}
