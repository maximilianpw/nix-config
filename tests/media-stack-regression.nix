{
  config,
  lib,
  pkgs,
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  endpoints =
    homelab.endpoints config.homelab.tailnet.domain
    // homelab.publicEndpoints;
  mediaRoot = "/srv/media";
  usenetRoot = "${mediaRoot}/usenet";
  qbt = config.containers.qbt;
  qbtConfig = qbt.config;
  qbtService = qbtConfig.systemd.services.qbittorrent;
  qbtDeferredTimer = qbtConfig.systemd.timers.qbittorrent-deferred-start;
  sab = config.containers.sab;
  sabConfig = sab.config;
  sabService = sabConfig.systemd.services.sabnzbd;
  sabDeferredTimer = sabConfig.systemd.timers.sabnzbd-deferred-start;
  hostQbtContainerService = config.systemd.services."container@qbt";
  hostSabContainerService = config.systemd.services."container@sab";
  tunarrService = config.systemd.services.tunarr;
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
  quiescesBefore = first: second: let
    before = units:
      if units == []
      then false
      else if builtins.head units == first
      then true
      else if builtins.head units == second
      then false
      else before (builtins.tail units);
  in
    before homelab.backup.archiveUnits;
  manifest = config.custom.backup.manifestMetadata;
  mediaStatePaths = [
    "/var/lib/bazarr"
    "/var/lib/jellyfin"
    "/var/lib/lidarr/.config/Lidarr"
    "/var/lib/private/prowlarr"
    "/var/lib/nixos-containers/qbt"
    "/var/lib/nixos-containers/sab"
    "/var/lib/radarr/.config/Radarr"
    "/var/lib/sabnzbd"
    "/var/lib/private/jellyseerr"
    "/var/lib/sonarr/.config/NzbDrone"
    "/var/lib/tunarr"
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
    config.users.groups.media.gid
    == sabConfig.users.groups.media.gid
    && config.users.users.sabnzbd.uid == 973
    && config.users.users.sabnzbd.group == "media"
    && sabConfig.users.users.sabnzbd.uid == 973
  )
  "the bind-mounted Usenet tree and SABnzbd state must retain stable media identities";
  assert lib.assertMsg (
    config.services.bazarr.enable
    && !config.services.ersatztv.enable
    && !(builtins.hasAttr "ersatztv" homelab.services)
    && tunarrService.environment.TUNARR_SERVER_PORT == toString endpoints.tunarr.port
    && tunarrService.environment.TUNARR_BIND_ADDR == "127.0.0.1"
    && !(builtins.hasAttr "TUNARR_DATABASE_PATH" tunarrService.environment)
    && !(builtins.hasAttr "TUNARR_DATABASE_NAME" tunarrService.environment)
    && pkgs.tunarr.ffmpeg == pkgs.ffmpeg
    && lib.versionAtLeast pkgs.tunarr.ffmpeg.version "7.1"
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
    && !config.services.sabnzbd.enable
    && sabConfig.services.sabnzbd.enable
    && config.services.seerr.enable
    && !config.services.qbittorrent.enable
  )
  "unsupported book managers must be absent and supported media applications must run in their declared isolation domains";
  assert lib.assertMsg (
    sabConfig.services.sabnzbd.configFile
    == null
    && sabConfig.services.sabnzbd.allowConfigWrite
    && sabConfig.services.sabnzbd.group == "media"
    && !sabConfig.services.sabnzbd.openFirewall
    && sabConfig.services.sabnzbd.settings.misc.host == "10.89.1.2"
    && sabConfig.services.sabnzbd.settings.misc.port == 8080
    && sabConfig.services.sabnzbd.settings.misc.download_dir == "${usenetRoot}/incomplete"
    && sabConfig.services.sabnzbd.settings.misc.complete_dir == "${usenetRoot}/complete"
    && sabConfig.services.sabnzbd.settings.misc.backup_dir == "/var/lib/sabnzbd/backups"
    && sabConfig.services.sabnzbd.settings.misc.permissions == "2775"
    && sabConfig.services.sabnzbd.settings.misc.host_whitelist
    == "${endpoints.sabnzbd.host}, localhost, 127.0.0.1, 10.89.1.2"
    && sabConfig.services.sabnzbd.settings.misc.local_ranges
    == "10.89.1.1, 100.64.0.0/10, fd7a:115c:a1e0::/48"
    && sabConfig.services.sabnzbd.settings.misc.verify_xff_header
    && sabConfig.services.sabnzbd.settings.servers.eweka.host == "news.eweka.nl"
    && sabConfig.services.sabnzbd.settings.servers.eweka.port == 563
    && sabConfig.services.sabnzbd.settings.servers.eweka.connections == 20
    && sabConfig.services.sabnzbd.settings.servers.eweka.ssl
    && sabConfig.services.sabnzbd.settings.servers.eweka.ssl_verify == 3
    && sabConfig.services.sabnzbd.settings.servers.eweka.required
    && !(builtins.hasAttr "username" sabConfig.services.sabnzbd.settings.servers.eweka)
    && !(builtins.hasAttr "password" sabConfig.services.sabnzbd.settings.servers.eweka)
    && sabConfig.services.sabnzbd.settings.categories."sonarr-usenet".dir == "tv"
    && sabConfig.services.sabnzbd.settings.categories."radarr-usenet".dir == "movies"
    && sabConfig.services.sabnzbd.settings.categories."lidarr-usenet".dir == "music"
    && !(builtins.hasAttr "sonarr" sabConfig.services.sabnzbd.settings.categories)
    && !(builtins.hasAttr "radarr" sabConfig.services.sabnzbd.settings.categories)
    && !(builtins.hasAttr "lidarr" sabConfig.services.sabnzbd.settings.categories)
  )
  "SABnzbd must keep credentials mutable while enforcing proxied access, strict TLS, paths, and media categories";
  assert lib.assertMsg (
    sabService.serviceConfig.StateDirectoryMode
    == "0700"
    && config.systemd.tmpfiles.settings."10-sabnzbd"."/var/lib/sabnzbd".d.mode == "0700"
    && config.systemd.tmpfiles.settings."10-sabnzbd"."/var/lib/sabnzbd".d.user == "sabnzbd"
    && builtins.attrNames sab.bindMounts
    == [
      "/srv/media/usenet"
      "/var/lib/sabnzbd"
    ]
    && !sab.bindMounts.${usenetRoot}.isReadOnly
    && !sab.bindMounts."/var/lib/sabnzbd".isReadOnly
  )
  "SABnzbd state must stay private and the container must see only its state and download tree";
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
    && config.systemd.services.bazarr.environment.DYNACONF_GENERAL__IP == "127.0.0.1"
    && config.systemd.services.seerr.environment.HOST == "127.0.0.1"
    && !config.services.bazarr.openFirewall
    && !config.services.lidarr.openFirewall
    && !config.services.sonarr.openFirewall
    && !config.services.radarr.openFirewall
    && !config.services.prowlarr.openFirewall
    && !config.services.seerr.openFirewall
  )
  "administrative media services must bind loopback and keep their firewall ports closed";
  assert lib.assertMsg (
    config.users.users.tunarr.isSystemUser
    && config.users.users.tunarr.group == "tunarr"
    && builtins.elem "media" config.users.users.tunarr.extraGroups
    && builtins.elem "render" config.users.users.tunarr.extraGroups
    && builtins.elem "video" config.users.users.tunarr.extraGroups
    && tunarrService.serviceConfig.ExecStart == "${lib.getExe pkgs.tunarr} --database /var/lib/tunarr"
    && lib.hasInfix "tunarr-reconcile-settings" tunarrService.serviceConfig.ExecStartPre
    && builtins.elem pkgs.libva-utils tunarrService.path
    && builtins.elem "${mediaRoot}/library" tunarrService.serviceConfig.ReadOnlyPaths
    && builtins.elem "${mediaRoot}/torrents" tunarrService.serviceConfig.InaccessiblePaths
    && builtins.elem usenetRoot tunarrService.serviceConfig.InaccessiblePaths
  )
  "Tunarr must read the library and render node without modifying media or seeing downloads";
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
    tunarrService.serviceConfig.UMask
    == "0077"
    && tunarrService.serviceConfig.StateDirectory == "tunarr"
    && tunarrService.serviceConfig.StateDirectoryMode == "0700"
    && tunarrService.serviceConfig.NoNewPrivileges
    && tunarrService.serviceConfig.ProtectSystem == "strict"
    && builtins.elem "AF_NETLINK" tunarrService.serviceConfig.RestrictAddressFamilies
    && config.systemd.services.bazarr.serviceConfig.UMask == "0002"
    && config.systemd.services.jellyfin.serviceConfig.UMask == "0002"
    && config.systemd.services.lidarr.serviceConfig.UMask == "0002"
    && config.systemd.services.sonarr.serviceConfig.UMask == "0002"
    && config.systemd.services.radarr.serviceConfig.UMask == "0002"
    && sabService.serviceConfig.UMask == "0002"
    && qbtService.serviceConfig.UMask == "0002"
  )
  "Tunarr must keep private state while all media writers preserve shared-group access";
  assert lib.assertMsg (
    qbt.autoStart
    && qbt.privateNetwork
    && qbt.enableTun
    && qbt.hostAddress == "10.89.0.1"
    && qbt.localAddress == "10.89.0.2"
    && !lib.hasInfix "/" qbt.localAddress
    && qbtConfig.time.timeZone == config.time.timeZone
    && builtins.attrNames qbt.bindMounts == ["${mediaRoot}/torrents"]
    && qbt.bindMounts."${mediaRoot}/torrents".hostPath == "${mediaRoot}/torrents"
    && !qbt.bindMounts."${mediaRoot}/torrents".isReadOnly
  )
  "qBittorrent must use the container module's prefix-free host-route address and only the torrent bind mount";
  assert lib.assertMsg (
    sab.autoStart
    && sab.privateNetwork
    && sab.enableTun
    && sab.hostAddress == "10.89.1.1"
    && sab.localAddress == "10.89.1.2"
    && !lib.hasInfix "/" sab.localAddress
    && sabConfig.time.timeZone == config.time.timeZone
    && sab.bindMounts.${usenetRoot}.hostPath == usenetRoot
    && sab.bindMounts."/var/lib/sabnzbd".hostPath == "/var/lib/sabnzbd"
  )
  "SABnzbd must use a separate prefix-free private network and preserve only its state and Usenet bind mounts";
  assert lib.assertMsg (
    qbtConfig.services.mullvad-vpn.enable
    && qbtConfig.services.mullvad-vpn.enableEarlyBootBlocking
    && !qbtConfig.services.mullvad-vpn.enableExcludeWrapper
    && sabConfig.services.mullvad-vpn.enable
    && sabConfig.services.mullvad-vpn.enableEarlyBootBlocking
    && !sabConfig.services.mullvad-vpn.enableExcludeWrapper
    && !config.services.mullvad-vpn.enable
    && qbtConfig.services.qbittorrent.enable
    && !qbtConfig.services.qbittorrent.openFirewall
    && lib.hasPrefix "+/nix/store/" qbtService.serviceConfig.ExecStartPre
    && lib.hasPrefix "+/nix/store/" (builtins.head sabService.serviceConfig.ExecStartPre)
    && builtins.elem "mullvad-daemon.service" qbtService.requires
    && builtins.elem "mullvad-daemon.service" sabService.requires
    && qbtService.serviceConfig.Restart == "on-failure"
    && sabService.serviceConfig.Restart == "on-failure"
  )
  "Mullvad's early blocker and pre-start connection gate must fail both downloaders closed without affecting Kim";
  assert lib.assertMsg (
    qbtService.wantedBy
    == []
    && qbtDeferredTimer.wantedBy == ["timers.target"]
    && qbtDeferredTimer.timerConfig.OnUnitInactiveSec == "30s"
    && qbtDeferredTimer.timerConfig.Unit == "qbittorrent.service"
    && sabService.wantedBy == []
    && sabDeferredTimer.wantedBy == ["timers.target"]
    && sabDeferredTimer.timerConfig.OnUnitInactiveSec == "30s"
    && sabDeferredTimer.timerConfig.Unit == "sabnzbd.service"
  )
  "downloaders must not block their container boot targets while Mullvad awaits first login";
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
    && config.networking.nat.internalInterfaces
    == [
      "ve-qbt"
      "ve-sab"
    ]
  )
  "only the isolated downloader veths must use Kim's physical uplink for NAT";
  assert lib.assertMsg (
    config.systemd.sockets.qbittorrent-proxy.socketConfig.ListenStream
    == "127.0.0.1:${toString endpoints.qbittorrent.port}"
    && lib.hasSuffix "systemd-socket-proxyd 10.89.0.2:8080" config.systemd.services.qbittorrent-proxy.serviceConfig.ExecStart
    && config.systemd.sockets.sabnzbd-proxy.socketConfig.ListenStream
    == "127.0.0.1:${toString endpoints.sabnzbd.port}"
    && lib.hasSuffix "systemd-socket-proxyd 10.89.1.2:8080" config.systemd.services.sabnzbd-proxy.serviceConfig.ExecStart
  )
  "downloader WebUIs must cross their namespaces only through loopback proxies";
  assert lib.assertMsg (
    config.networking.firewall.interfaces.enp194s0.allowedTCPPorts
    == [endpoints.jellyfin.port]
    && config.networking.firewall.interfaces.enp194s0.allowedUDPPorts == [7359]
  )
  "the physical LAN must expose Jellyfin playback and discovery only";
  assert lib.assertMsg (lib.all requiresSrv [
    config.systemd.services.bazarr
    tunarrService
    config.systemd.services.jellyfin
    config.systemd.services.lidarr
    config.systemd.services.sonarr
    config.systemd.services.radarr
    hostQbtContainerService
    hostSabContainerService
  ])
  "every media writer or reader must fail closed when /srv is absent";
  assert lib.assertMsg (
    lib.all (path: builtins.elem path manifest.expectedPrimaryStatePaths) mediaStatePaths
    && lib.all (name: builtins.hasAttr name manifest.applicationVersions) [
      "bazarr"
      "jellyfin"
      "lidarr"
      "prowlarr"
      "qbittorrent"
      "radarr"
      "sabnzbd"
      "seerr"
      "sonarr"
      "tunarr"
    ]
    && !lib.any (lib.hasPrefix mediaRoot) manifest.expectedPrimaryStatePaths
    && !builtins.elem mediaRoot config.services.borgbackup.jobs.main.paths
    && builtins.elem "/var/lib/tunarr/data.ms" config.custom.backup.exclude
  )
  "Borg must preserve media control state while excluding replaceable downloaded media";
  assert lib.assertMsg (lib.all (unit: builtins.elem unit homelab.backup.archiveUnits) [
      "bazarr.service"
      "jellyfin.service"
      "lidarr.service"
      "prowlarr.service"
      "qbittorrent-proxy.socket"
      "container@qbt.service"
      "sabnzbd-proxy.socket"
      "container@sab.service"
      "radarr.service"
      "seerr.service"
      "sonarr.service"
      "tunarr.service"
    ]
    && quiescesBefore "qbittorrent-proxy.socket" "container@qbt.service"
    && quiescesBefore "sabnzbd-proxy.socket" "container@sab.service")
  "Borg must disable downloader socket activation before quiescing every mutable media control plane";
    pkgs.runCommand "media-stack-regression" {} ''
      touch "$out"
    ''
