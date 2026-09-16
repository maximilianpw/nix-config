{
  config,
  lib,
  pkgs,
  ...
}: let
  common = import ./common.nix {inherit config lib pkgs;};
  inherit
    (common)
    endpoints
    indexerProxyPort
    indexerSolverPort
    mediaRoot
    mkDeferredVpnService
    mkVpnContainer
    mullvadConnectionGate
    qbitContainerAddress
    qbitContainerHostAddress
    qbitContainerLocalAddress
    qbitContainerPort
    qbitNetworkInterface
    qbitUid
    ;
in {
  containers.qbt = mkVpnContainer {
    hostAddress = qbitContainerHostAddress;
    # Mullvad's LAN firewall must see the host endpoint in the container's
    # connected subnet. Using the even .2 address as a /31 network base also
    # keeps the container module's generated host route valid.
    localAddress = qbitContainerLocalAddress;
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
          ${builtins.readFile ../../scripts/qbittorrent-vpn-prestart.sh}
          ${mullvadConnectionGate "qBittorrent"}
        '';
      };
      indexerProxyPreStart = pkgs.writeShellApplication {
        name = "indexer-proxy-vpn-prestart";
        runtimeInputs = [pkgs.coreutils pkgs.gnugrep pkgs.mullvad];
        text = mullvadConnectionGate "Indexer proxies";
      };
    in {
      users.users.qbittorrent.uid = qbitUid;

      # Prowlarr reaches these services over the container veth. Neither
      # listener is exposed through Kim's LAN or Tailscale ingress.
      networking.firewall.interfaces.eth0.allowedTCPPorts = [indexerProxyPort indexerSolverPort];
      services = {
        tinyproxy = {
          enable = true;
          settings = {
            Listen = qbitContainerAddress;
            Port = indexerProxyPort;
            Allow = [qbitContainerHostAddress];
            ConnectPort = [443];
            Timeout = 180;
            MaxClients = 16;
            LogLevel = "Warning";
            FilterDefaultDeny = true;
            FilterType = "ere";
            Filter = pkgs.writeText "indexer-proxy-domains" ''
              ^1337x\.(to|st)$
              ^x1337x\.(ws|eu|cc)$
              ^prowlarr\.servarr\.com$
            '';
          };
        };
        flaresolverr = {
          enable = true;
          port = indexerSolverPort;
          openFirewall = false;
        };

        qbittorrent = {
          enable = true;
          group = "media";
          openFirewall = false;
          webuiPort = qbitContainerPort;
          extraArgs = ["--confirm-legal-notice"];
        };
      };

      systemd = lib.mkMerge [
        (mkDeferredVpnService {
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
        })
        (mkDeferredVpnService {
          serviceName = "tinyproxy";
          description = "Start the indexer HTTP proxy after Mullvad connects";
          vpnGate = "+${lib.getExe indexerProxyPreStart}";
          extraServiceConfig = {
            UMask = "0077";
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            InaccessiblePaths = ["${mediaRoot}/torrents"];
          };
        })
        (mkDeferredVpnService {
          serviceName = "flaresolverr";
          description = "Start the indexer challenge helper after Mullvad connects";
          vpnGate = "+${lib.getExe indexerProxyPreStart}";
          environment = {
            HOST = qbitContainerAddress;
            LOG_LEVEL = "warning";
          };
          extraServiceConfig = {
            UMask = lib.mkForce "0077";
            Restart = lib.mkForce "on-failure";
            RestartSec = lib.mkForce "30s";
            InaccessiblePaths = ["${mediaRoot}/torrents"];
          };
        })
      ];
    };
  };
}
