{
  config,
  lib,
  pkgs,
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  endpoints = homelab.endpoints config.homelab.tailnet.domain;
  mediaRoot = "/srv/media";
  usenetRoot = "${mediaRoot}/usenet";
  qbt = config.containers.qbt;
  qbtConfig = qbt.config;
  qbtService = qbtConfig.systemd.services.qbittorrent;
  qbtDeferredTimer = qbtConfig.systemd.timers.qbittorrent-deferred-start;
  hostContainerService = config.systemd.services."container@qbt";
  ersatzService = config.systemd.services.ersatztv;
  sabService = config.systemd.services.sabnzbd;
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
  mediaDirectoryIsShared = path: let
    rule = config.systemd.tmpfiles.settings."10-media".${path}.d;
  in
    rule.mode == "2775" && rule.user == "root" && rule.group == "media";
  requiresSrv = service:
    builtins.elem "srv.mount" service.requires
    && builtins.elem "srv.mount" service.after
    && builtins.elem "/srv" service.unitConfig.RequiresMountsFor;
  manifest = config.custom.backup.manifestMetadata;
  mediaStatePaths = [
    "/var/lib/bazarr"
    "/var/lib/ersatztv"
    "/var/lib/jellyfin"
    "/var/lib/lidarr/.config/Lidarr"
    "/var/lib/private/prowlarr"
    "/var/lib/nixos-containers/qbt"
    "/var/lib/radarr/.config/Radarr"
    "/var/lib/sabnzbd"
    "/var/lib/private/jellyseerr"
    "/var/lib/sonarr/.config/NzbDrone"
  ];
in
  assert lib.assertMsg (lib.all mediaDirectoryIsShared mediaDirectories)
  "media directories must be setgid and group-writable for reliable hardlink imports";
  assert lib.assertMsg (
    config.users.groups.media.gid
    == qbtConfig.users.groups.media.gid
    && config.users.users.qbittorrent.uid == 970
    && qbtConfig.users.users.qbittorrent.uid == 970
  )
  "the bind-mounted torrent tree must retain stable qBittorrent and media identities";
  assert lib.assertMsg (
    config.users.users.sabnzbd.uid
    == 973
    && config.users.users.sabnzbd.group == "media"
  )
  "SABnzbd must retain a stable identity across state and download restores";
  assert lib.assertMsg (
    config.services.bazarr.enable
    && config.services.ersatztv.enable
    && config.services.ersatztv.environment.ETV_UI_PORT == endpoints.ersatztv.port
    && !config.services.ersatztv.openFirewall
    && config.services.jellyfin.enable
    && config.services.lidarr.enable
    && config.services.sonarr.enable
    && config.services.radarr.enable
    && !config.services.readarr.enable
    && !(builtins.hasAttr "readarr" homelab.services)
    && !(builtins.hasAttr "lazylibrarian" homelab.services)
    && !(builtins.hasAttr "lazylibrarian" config.virtualisation.oci-containers.containers)
    && !(builtins.hasAttr "lazylibrarian" config.users.users)
    && builtins.elem "/var/lib/lazylibrarian" config.custom.backup.exclude
    && config.services.prowlarr.enable
    && config.services.sabnzbd.enable
    && config.services.seerr.enable
    && !config.services.qbittorrent.enable
  )
  "unsupported book managers must be absent and the supported native media applications enabled";
  assert lib.assertMsg (
    config.services.sabnzbd.configFile
    == null
    && config.services.sabnzbd.allowConfigWrite
    && config.services.sabnzbd.group == "media"
    && !config.services.sabnzbd.openFirewall
    && config.services.sabnzbd.settings.misc.host == "127.0.0.1"
    && config.services.sabnzbd.settings.misc.port == endpoints.sabnzbd.port
    && config.services.sabnzbd.settings.misc.download_dir == "${usenetRoot}/incomplete"
    && config.services.sabnzbd.settings.misc.complete_dir == "${usenetRoot}/complete"
    && config.services.sabnzbd.settings.misc.backup_dir == "/var/lib/sabnzbd/backups"
    && config.services.sabnzbd.settings.misc.permissions == "2775"
    && config.services.sabnzbd.settings.misc.host_whitelist
    == "${endpoints.sabnzbd.host}, localhost, 127.0.0.1"
    && config.services.sabnzbd.settings.misc.local_ranges
    == "100.64.0.0/10, fd7a:115c:a1e0::/48"
    && config.services.sabnzbd.settings.misc.verify_xff_header
    && config.services.sabnzbd.settings.servers.eweka.host == "news.eweka.nl"
    && config.services.sabnzbd.settings.servers.eweka.port == 563
    && config.services.sabnzbd.settings.servers.eweka.connections == 20
    && config.services.sabnzbd.settings.servers.eweka.ssl
    && config.services.sabnzbd.settings.servers.eweka.ssl_verify == 3
    && config.services.sabnzbd.settings.servers.eweka.required
    && !(builtins.hasAttr "username" config.services.sabnzbd.settings.servers.eweka)
    && !(builtins.hasAttr "password" config.services.sabnzbd.settings.servers.eweka)
    && config.services.sabnzbd.settings.categories."sonarr-usenet".dir == "tv"
    && config.services.sabnzbd.settings.categories."radarr-usenet".dir == "movies"
    && config.services.sabnzbd.settings.categories."lidarr-usenet".dir == "music"
    && !(builtins.hasAttr "sonarr" config.services.sabnzbd.settings.categories)
    && !(builtins.hasAttr "radarr" config.services.sabnzbd.settings.categories)
    && !(builtins.hasAttr "lidarr" config.services.sabnzbd.settings.categories)
  )
  "SABnzbd must keep credentials mutable while enforcing loopback paths and media categories";
  assert lib.assertMsg (
    sabService.serviceConfig.StateDirectoryMode
    == "0700"
    && config.systemd.tmpfiles.settings."10-sabnzbd"."/var/lib/sabnzbd".d.mode == "0700"
    && config.systemd.tmpfiles.settings."10-sabnzbd"."/var/lib/sabnzbd".d.user == "sabnzbd"
    && builtins.elem "${mediaRoot}/torrents" sabService.serviceConfig.InaccessiblePaths
    && builtins.elem "${mediaRoot}/library" sabService.serviceConfig.InaccessiblePaths
  )
  "SABnzbd state must stay private and the service must see only its download tree";
  assert lib.assertMsg (
    config.services.bazarr.listenPort
    == endpoints.bazarr.port
    && config.services.lidarr.settings.server.bindaddress == "127.0.0.1"
    && config.services.lidarr.settings.server.port == endpoints.lidarr.port
    && config.services.sonarr.settings.server.bindaddress == "127.0.0.1"
    && config.services.sonarr.settings.server.port == endpoints.sonarr.port
    && config.services.radarr.settings.server.bindaddress == "127.0.0.1"
    && config.services.radarr.settings.server.port == endpoints.radarr.port
    && config.services.prowlarr.settings.server.bindaddress == "127.0.0.1"
    && config.services.prowlarr.settings.server.port == endpoints.prowlarr.port
    && !config.services.bazarr.openFirewall
    && !config.services.lidarr.openFirewall
    && !config.services.sonarr.openFirewall
    && !config.services.radarr.openFirewall
    && !config.services.prowlarr.openFirewall
    && !config.services.seerr.openFirewall
  )
  "administrative media services must stay on loopback or behind the host firewall";
  assert lib.assertMsg (
    builtins.elem "media" config.users.users.ersatztv.extraGroups
    && builtins.elem "render" config.users.users.ersatztv.extraGroups
    && builtins.elem "video" config.users.users.ersatztv.extraGroups
    && builtins.elem "${mediaRoot}/library" ersatzService.serviceConfig.ReadOnlyPaths
    && builtins.elem "${mediaRoot}/torrents" ersatzService.serviceConfig.InaccessiblePaths
    && builtins.elem usenetRoot ersatzService.serviceConfig.InaccessiblePaths
  )
  "ErsatzTV must read the library and render node without modifying media or seeing downloads";
  assert lib.assertMsg (
    config.services.jellyfin.hardwareAcceleration.enable
    && config.services.jellyfin.hardwareAcceleration.type == "vaapi"
    && config.services.jellyfin.hardwareAcceleration.device == "/dev/dri/renderD128"
    && config.hardware.graphics.enable
  )
  "Jellyfin must use Kim's declared AMD VA-API render path";
  assert lib.assertMsg (
    builtins.elem "media" config.users.users.jellyfin.extraGroups
    && !(builtins.elem "${mediaRoot}/library" (config.systemd.services.jellyfin.serviceConfig.ReadOnlyPaths or []))
    && builtins.elem "${mediaRoot}/torrents" config.systemd.services.jellyfin.serviceConfig.InaccessiblePaths
    && builtins.elem usenetRoot config.systemd.services.jellyfin.serviceConfig.InaccessiblePaths
  )
  "Jellyfin must be able to manage the finished library without seeing downloads";
  assert lib.assertMsg (
    ersatzService.serviceConfig.UMask
    == "0077"
    && config.systemd.services.bazarr.serviceConfig.UMask == "0002"
    && config.systemd.services.jellyfin.serviceConfig.UMask == "0002"
    && config.systemd.services.lidarr.serviceConfig.UMask == "0002"
    && config.systemd.services.sonarr.serviceConfig.UMask == "0002"
    && config.systemd.services.radarr.serviceConfig.UMask == "0002"
    && sabService.serviceConfig.UMask == "0002"
    && qbtService.serviceConfig.UMask == "0002"
  )
  "ErsatzTV must keep private state while all media writers preserve shared-group access";
  assert lib.assertMsg (
    qbt.autoStart
    && qbt.privateNetwork
    && qbt.enableTun
    && qbt.hostAddress == "10.89.0.1"
    && qbt.localAddress == "10.89.0.2"
    && !lib.hasInfix "/" qbt.localAddress
    && builtins.attrNames qbt.bindMounts == ["${mediaRoot}/torrents"]
    && qbt.bindMounts."${mediaRoot}/torrents".hostPath == "${mediaRoot}/torrents"
    && !qbt.bindMounts."${mediaRoot}/torrents".isReadOnly
  )
  "qBittorrent must use the container module's prefix-free host-route address and only the torrent bind mount";
  assert lib.assertMsg (
    qbtConfig.services.mullvad-vpn.enable
    && qbtConfig.services.mullvad-vpn.enableEarlyBootBlocking
    && !qbtConfig.services.mullvad-vpn.enableExcludeWrapper
    && !config.services.mullvad-vpn.enable
    && qbtConfig.services.qbittorrent.enable
    && !qbtConfig.services.qbittorrent.openFirewall
    && lib.hasPrefix "+/nix/store/" qbtService.serviceConfig.ExecStartPre
    && builtins.elem "mullvad-daemon.service" qbtService.requires
  )
  "Mullvad's early blocker and pre-start connection gate must fail qBittorrent closed without affecting Kim";
  assert lib.assertMsg (
    qbtService.wantedBy
    == []
    && qbtDeferredTimer.wantedBy == ["timers.target"]
    && qbtDeferredTimer.timerConfig.Unit == "qbittorrent.service"
  )
  "qBittorrent must not block the container boot target while Mullvad awaits its first login";
  assert lib.assertMsg (
    qbtService.environment.QBIT_NETWORK_INTERFACE
    == "wg0-mullvad"
    && qbtService.environment.QBIT_WEBUI_CSRF_PROTECTION == "true"
    && qbtService.environment.QBIT_WEBUI_HOST_HEADER_VALIDATION == "false"
    && qbtService.environment.QBIT_WEBUI_MAX_AUTHENTICATION_FAIL_COUNT == "0"
  )
  "qBittorrent must bind to Mullvad and preserve CSRF protection while accepting the port-translating proxy without shared-IP bans";
  assert lib.assertMsg (
    config.networking.nat.enable
    && config.networking.nat.externalInterface == "enp194s0"
    && config.networking.nat.internalInterfaces == ["ve-qbt"]
  )
  "only the qBittorrent veth must use Kim's physical uplink for NAT";
  assert lib.assertMsg (
    config.systemd.sockets.qbittorrent-proxy.socketConfig.ListenStream
    == "127.0.0.1:${toString endpoints.qbittorrent.port}"
    && lib.hasSuffix "systemd-socket-proxyd 10.89.0.2:8080" config.systemd.services.qbittorrent-proxy.serviceConfig.ExecStart
  )
  "qBittorrent's WebUI must cross the namespace only through a loopback proxy";
  assert lib.assertMsg (
    config.networking.firewall.interfaces.enp194s0.allowedTCPPorts
    == [endpoints.jellyfin.port]
    && config.networking.firewall.interfaces.enp194s0.allowedUDPPorts == [7359]
  )
  "the physical LAN must expose Jellyfin playback and discovery only";
  assert lib.assertMsg (lib.all requiresSrv [
    config.systemd.services.bazarr
    ersatzService
    config.systemd.services.jellyfin
    config.systemd.services.lidarr
    config.systemd.services.sonarr
    config.systemd.services.radarr
    sabService
    hostContainerService
  ])
  "every media writer or reader must fail closed when /srv is absent";
  assert lib.assertMsg (
    lib.all (path: builtins.elem path manifest.expectedPrimaryStatePaths) mediaStatePaths
    && lib.all (name: builtins.hasAttr name manifest.applicationVersions) [
      "bazarr"
      "ersatztv"
      "jellyfin"
      "lidarr"
      "prowlarr"
      "qbittorrent"
      "radarr"
      "sabnzbd"
      "seerr"
      "sonarr"
    ]
    && !lib.any (lib.hasPrefix mediaRoot) manifest.expectedPrimaryStatePaths
    && !builtins.elem mediaRoot config.services.borgbackup.jobs.main.paths
  )
  "Borg must preserve media control state while excluding replaceable downloaded media";
  assert lib.assertMsg (lib.all (unit: builtins.elem unit homelab.backup.archiveUnits) [
    "bazarr.service"
    "ersatztv.service"
    "jellyfin.service"
    "lidarr.service"
    "prowlarr.service"
    "container@qbt.service"
    "radarr.service"
    "sabnzbd.service"
    "seerr.service"
    "sonarr.service"
  ])
  "Borg must quiesce every mutable media control plane before copying it";
    pkgs.runCommand "media-stack-regression" {} ''
      touch "$out"
    ''
