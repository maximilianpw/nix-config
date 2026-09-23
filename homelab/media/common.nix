{
  config,
  lib,
  pkgs,
}: let
  homelab = import ../../lib/homelab.nix {inherit lib;};
  endpoints =
    homelab.endpoints
    // homelab.publicEndpoints;
  hostTimeZone = config.time.timeZone;
  mediaRoot = "/srv/media";
  usenetRoot = "${mediaRoot}/usenet";
  mediaGid = 971;
  qbitUid = 970;
  sabnzbdUid = 973;
  qbitContainerAddress = "10.89.0.2";
  qbitContainerLocalAddress = "${qbitContainerAddress}/31";
  qbitContainerHostAddress = "10.89.0.3";
  qbitContainerPort = 8080;
  indexerProxyPort = 8888;
  indexerSolverPort = 8191;
  qbitNetworkInterface = "wg0-mullvad";
  sabContainerAddress = "10.89.1.2";
  sabContainerLocalAddress = "${sabContainerAddress}/31";
  sabContainerHostAddress = "10.89.1.3";
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
in {
  inherit
    downloadProxies
    endpoints
    homelab
    indexerProxyPort
    indexerSolverPort
    mediaGid
    mediaRoot
    mkContainerProxyService
    mkContainerProxySocket
    mkDeferredVpnService
    mkVpnContainer
    mullvadConnectionGate
    qbitContainerAddress
    qbitContainerHostAddress
    qbitContainerLocalAddress
    qbitContainerPort
    qbitNetworkInterface
    qbitUid
    sabContainerAddress
    sabContainerHostAddress
    sabContainerLocalAddress
    sabContainerPort
    sabnzbdUid
    usenetRoot
    ;
}
