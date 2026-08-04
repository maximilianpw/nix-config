# Data only. Validation, defaults, and all derived views live in
# lib/homelab-inventory.nix and lib/homelab.nix.
{
  bazarr = {
    endpoint = {
      authorizationOwner = "tailscale";
      exposure = "tailnet";
      port = 6767;
    };
    state.paths = ["/var/lib/bazarr"];
    backup.quiesce = [
      {
        unit = "bazarr.service";
        until = "archive";
      }
    ];
    storage.units = ["bazarr.service"];
    operations.units = ["bazarr.service"];
    recovery = {
      order = 92;
      versionPolicy = "restore-archived-version-first";
      runbook = "docs/media-stack.md#recovery";
      acceptance = ["sonarr-radarr-providers-and-subtitle-history-load"];
      secretOwners = ["mutable-state:/var/lib/bazarr"];
    };
    presentation = {
      group = "operations";
      title = "Bazarr";
      icon = "bazarr.png";
      description = "Subtitle automation";
      order = 68;
    };
  };

  grafana = {
    endpoint = {
      authorizationOwner = "tailscale";
      exposure = "tailnet";
      port = 19004;
      monitorPath = "/api/health";
    };
    state.disposable = true;
    operations.units = ["grafana.service"];
    recovery = {
      order = 80;
      versionPolicy = "rebuild-from-archived-revision";
      runbook = "docs/homelab-recovery.md#grafana-and-prometheus";
      acceptance = ["provisioned-dashboard-and-datasource-load"];
      secretOwners = ["disposable-generated:/var/lib/grafana/secret_key"];
    };
    presentation = {
      group = "operations";
      title = "Grafana";
      icon = "grafana.png";
      description = "Kim health and history";
      order = 10;
    };
  };

  homeassistant = {
    endpoint = {
      authorizationOwner = "cloudflare";
      exposure = "public";
      hostname = "homeassistant.maximilian.pw";
      port = 19123;
    };
    state = {
      paths = ["/var/lib/hass"];
      database = "hass";
    };
    backup = {
      strategy = "archive-transform";
      artifacts = ["/var/backup/home-assistant/config.tar"];
      transformedPaths = ["/var/lib/hass"];
      quiesce = [
        {
          unit = "home-assistant.service";
          until = "dump";
        }
      ];
    };
    operations.units = ["home-assistant.service"];
    recovery = {
      order = 20;
      versionPolicy = "restore-archived-version-first";
      runbook = "docs/homelab-recovery.md#home-assistant";
      acceptance = [
        "configuration-and-recorder-load"
        "harmless-automation-runs"
      ];
      secretOwners = ["mutable-state:/var/lib/hass"];
    };
    presentation = {
      group = "applications";
      title = "Home Assistant";
      icon = "home-assistant.png";
      description = "Smart home";
      order = 10;
    };
  };

  homelab = {
    endpoint = {
      authorizationOwner = "tailscale";
      exposure = "tailnet";
      port = 19082;
    };
    operations.units = ["homepage-dashboard.service"];
  };

  immich = {
    endpoint = {
      authorizationOwner = "tailscale";
      exposure = "tailnet";
      port = 2283;
    };
    state = {
      paths = ["/srv/immich"];
      database = "immich";
    };
    backup.quiesce = [
      {
        unit = "immich-server.service";
        until = "archive";
      }
    ];
    storage.units = ["immich-server.service"];
    operations.units = [
      "immich-machine-learning.service"
      "immich-server.service"
    ];
    recovery = {
      order = 15;
      versionPolicy = "restore-archived-version-first";
      runbook = "docs/homelab-recovery.md#immich";
      acceptance = [
        "database-and-storage-integrity-pass"
        "representative-original-thumbnail-and-video-open"
        "mobile-upload-and-search-pass"
      ];
      secretOwners = ["mutable-state:immich-database"];
    };
    presentation = {
      group = "applications";
      title = "Immich";
      icon = "immich.png";
      description = "Private photo library";
      order = 60;
    };
  };

  jellyfin = {
    endpoint = {
      authorizationOwner = "tailscale";
      exposure = "tailnet";
      port = 8096;
      monitorPath = "/health";
    };
    state.paths = ["/var/lib/jellyfin"];
    backup.quiesce = [
      {
        unit = "jellyfin.service";
        until = "archive";
      }
    ];
    storage.units = ["jellyfin.service"];
    operations.units = ["jellyfin.service"];
    recovery = {
      order = 90;
      versionPolicy = "restore-archived-version-first";
      runbook = "docs/media-stack.md#recovery";
      acceptance = [
        "libraries-users-and-watch-state-load"
        "representative-direct-play-and-transcode-pass"
      ];
      secretOwners = ["mutable-state:/var/lib/jellyfin"];
    };
    presentation = {
      group = "applications";
      title = "Jellyfin";
      icon = "jellyfin.png";
      description = "Private movies and television";
      order = 70;
    };
  };

  kuma = {
    endpoint = {
      authorizationOwner = "tailscale";
      exposure = "tailnet";
      port = 19001;
    };
    state = {
      # DynamicUser StateDirectory data lives below /var/lib/private; the
      # /var/lib/uptime-kuma compatibility path is only a symlink.
      paths = ["/var/lib/private/uptime-kuma"];
    };
    backup.quiesce = [
      {
        unit = "uptime-kuma.service";
        until = "archive";
      }
    ];
    operations.units = ["uptime-kuma.service"];
    recovery = {
      order = 70;
      versionPolicy = "restore-archived-version-first";
      runbook = "docs/homelab-recovery.md#uptime-kuma";
      acceptance = [
        "monitor-count-and-history-match"
        "notification-test-delivered"
      ];
      secretOwners = ["mutable-state:/var/lib/private/uptime-kuma"];
    };
    presentation = {
      group = "operations";
      title = "Uptime Kuma";
      icon = "uptime-kuma.png";
      description = "Endpoint availability";
      order = 20;
    };
  };

  lidarr = {
    endpoint = {
      authorizationOwner = "tailscale";
      exposure = "tailnet";
      port = 8686;
    };
    state.paths = ["/var/lib/lidarr/.config/Lidarr"];
    backup.quiesce = [
      {
        unit = "lidarr.service";
        until = "archive";
      }
    ];
    storage.units = ["lidarr.service"];
    operations.units = ["lidarr.service"];
    recovery = {
      order = 92;
      versionPolicy = "restore-archived-version-first";
      runbook = "docs/media-stack.md#recovery";
      acceptance = ["music-root-download-client-and-history-load"];
      secretOwners = ["mutable-state:/var/lib/lidarr/.config/Lidarr"];
    };
    presentation = {
      group = "operations";
      title = "Lidarr";
      icon = "lidarr.png";
      description = "Music automation";
      order = 65;
    };
  };

  miniflux = {
    endpoint = {
      authorizationOwner = "tailscale";
      exposure = "tailnet";
      port = 19002;
    };
    state.database = "miniflux";
    backup.quiesce = [
      {
        unit = "miniflux.service";
        until = "dump";
      }
    ];
    operations.units = ["miniflux.service"];
    recovery = {
      order = 50;
      versionPolicy = "restore-archived-version-first";
      runbook = "docs/homelab-recovery.md#miniflux";
      acceptance = ["login-feed-and-preference-state-load"];
      secretOwners = ["sops:miniflux-admin-credentials"];
    };
    presentation = {
      group = "applications";
      title = "Miniflux";
      icon = "miniflux.png";
      description = "Focused RSS reading";
      order = 40;
    };
  };

  nextcloud = {
    endpoint = {
      authorizationOwner = "cloudflare";
      exposure = "public";
      hostname = "nextcloud.maximilian.pw";
      port = 19080;
      monitorPath = "/status.php";
    };
    state = {
      paths = ["/srv/nextcloud"];
      database = "nextcloud";
    };
    backup = {
      quiesce = [
        {
          unit = "nextcloud-update-store-apps.timer";
          until = "archive";
        }
        {
          unit = "nextcloud-cron.timer";
          until = "archive";
        }
        {
          unit = "nextcloud-cron.service";
          until = "archive";
        }
        {
          unit = "phpfpm-nextcloud.service";
          until = "archive";
        }
      ];
    };
    storage = {
      units = [
        "nextcloud-cron.service"
        "nextcloud-setup.service"
        "nextcloud-update-db.service"
        "nextcloud-update-store-apps.service"
        "phpfpm-nextcloud.service"
      ];
    };
    operations.units = [
      "nextcloud-cron.service"
      "nextcloud-cron.timer"
      "nextcloud-update-store-apps.service"
      "nextcloud-update-store-apps.timer"
      "nginx.service"
      "phpfpm-nextcloud.service"
    ];
    recovery = {
      order = 10;
      versionPolicy = "restore-archived-version-first";
      runbook = "docs/homelab-recovery.md#nextcloud";
      acceptance = [
        "representative-files-open"
        "calendar-data-loads"
        "occ-status-and-app-ownership-pass"
      ];
      secretOwners = ["sops:nextcloud-admin-password"];
    };
    presentation = {
      group = "applications";
      title = "Nextcloud";
      icon = "nextcloud.png";
      description = "Files, calendar, and sync";
      order = 20;
    };
  };

  paperless = {
    endpoint = {
      authorizationOwner = "tailscale";
      exposure = "tailnet";
      port = 28981;
    };
    state = {
      paths = [
        "/srv/paperless/consume"
        "/srv/paperless/media"
      ];
      database = "paperless";
    };
    backup = {
      strategy = "application-export";
      artifacts = ["/srv/paperless/export"];
      quiesce = [
        {
          unit = "paperless-scheduler.service";
          until = "archive";
        }
        {
          unit = "paperless-web.service";
          until = "archive";
        }
        {
          unit = "paperless-consumer.service";
          until = "archive";
        }
        {
          unit = "paperless-task-queue.service";
          until = "archive";
        }
      ];
    };
    storage = {
      units = [
        "paperless-consumer.service"
        "paperless-exporter.service"
        "paperless-scheduler.service"
        "paperless-task-queue.service"
        "paperless-web.service"
      ];
    };
    operations.units = [
      "paperless-consumer.service"
      "paperless-scheduler.service"
      "paperless-task-queue.service"
      "paperless-web.service"
      "paperless-exporter.service"
    ];
    recovery = {
      order = 30;
      versionPolicy = "restore-archived-version-first";
      runbook = "docs/homelab-recovery.md#paperless";
      acceptance = [
        "export-import-and-counts-match"
        "search-and-document-open-pass"
        "pending-consume-files-accounted-for"
      ];
      secretOwners = [
        "sops:paperless-admin-password"
        "regenerated:/srv/paperless/nixos-paperless-secret-key"
      ];
    };
    presentation = {
      group = "applications";
      title = "Paperless";
      icon = "paperless-ngx.png";
      description = "Document archive";
      order = 30;
    };
  };

  prowlarr = {
    endpoint = {
      authorizationOwner = "tailscale";
      exposure = "tailnet";
      port = 9696;
    };
    state.paths = ["/var/lib/private/prowlarr"];
    backup.quiesce = [
      {
        unit = "prowlarr.service";
        until = "archive";
      }
    ];
    operations.units = ["prowlarr.service"];
    recovery = {
      order = 93;
      versionPolicy = "restore-archived-version-first";
      runbook = "docs/media-stack.md#recovery";
      acceptance = ["applications-and-authorized-indexer-definitions-load"];
      secretOwners = ["mutable-state:/var/lib/private/prowlarr"];
    };
    presentation = {
      group = "operations";
      title = "Prowlarr";
      icon = "prowlarr.png";
      description = "Media source coordination";
      order = 70;
    };
  };

  prometheus = {
    endpoint = {
      authorizationOwner = "host-local";
      exposure = "local";
      port = 9090;
    };
    state.disposable = true;
    operations.units = ["prometheus.service"];
    recovery = {
      order = 80;
      versionPolicy = "rebuild-from-archived-revision";
      runbook = "docs/homelab-recovery.md#grafana-and-prometheus";
      acceptance = ["targets-and-rules-load-with-empty-history"];
    };
  };

  qbittorrent = {
    endpoint = {
      authorizationOwner = "tailscale";
      exposure = "tailnet";
      port = 18080;
    };
    # The declarative container root holds qBittorrent resume/config state and
    # Mullvad's device login. The bind-mounted media tree is intentionally not
    # part of this recovery class.
    state.paths = ["/var/lib/nixos-containers/qbt"];
    backup.quiesce = [
      {
        unit = "container@qbt.service";
        until = "archive";
      }
    ];
    storage.units = ["container@qbt.service"];
    operations.units = ["container@qbt.service"];
    recovery = {
      order = 91;
      versionPolicy = "restore-archived-version-first";
      runbook = "docs/media-stack.md#recovery";
      acceptance = [
        "mullvad-reports-connected-before-daemon-start"
        "torrent-resume-state-and-categories-load"
      ];
      secretOwners = [
        "interactive:mullvad-account-login"
        "mutable-state:/var/lib/nixos-containers/qbt"
      ];
    };
    presentation = {
      group = "operations";
      title = "qBittorrent";
      icon = "qbittorrent.png";
      description = "Mullvad-isolated downloads";
      order = 80;
    };
  };

  radarr = {
    endpoint = {
      authorizationOwner = "tailscale";
      exposure = "tailnet";
      port = 7878;
    };
    state.paths = ["/var/lib/radarr/.config/Radarr"];
    backup.quiesce = [
      {
        unit = "radarr.service";
        until = "archive";
      }
    ];
    storage.units = ["radarr.service"];
    operations.units = ["radarr.service"];
    recovery = {
      order = 92;
      versionPolicy = "restore-archived-version-first";
      runbook = "docs/media-stack.md#recovery";
      acceptance = ["movie-root-download-client-and-history-load"];
      secretOwners = ["mutable-state:/var/lib/radarr/.config/Radarr"];
    };
    presentation = {
      group = "operations";
      title = "Radarr";
      icon = "radarr.png";
      description = "Movie automation";
      order = 60;
    };
  };

  sabnzbd = {
    endpoint = {
      authorizationOwner = "tailscale";
      exposure = "tailnet";
      port = 18081;
    };
    state.paths = ["/var/lib/sabnzbd"];
    backup.quiesce = [
      {
        unit = "sabnzbd.service";
        until = "archive";
      }
    ];
    storage.units = ["sabnzbd.service"];
    operations.units = ["sabnzbd.service"];
    recovery = {
      order = 91;
      versionPolicy = "restore-archived-version-first";
      runbook = "docs/media-stack.md#recovery";
      acceptance = [
        "provider-uses-strict-tls"
        "queue-history-categories-and-download-clients-load"
      ];
      secretOwners = ["mutable-state:/var/lib/sabnzbd"];
    };
    presentation = {
      group = "operations";
      title = "SABnzbd";
      icon = "sabnzbd.png";
      description = "Usenet downloads";
      order = 75;
    };
  };

  seerr = {
    endpoint = {
      authorizationOwner = "tailscale";
      exposure = "tailnet";
      port = 5055;
    };
    # Kim retains stateVersion 24.05, so nixpkgs keeps Seerr's compatibility
    # StateDirectory name rather than migrating mutable state implicitly.
    state.paths = ["/var/lib/private/jellyseerr"];
    backup.quiesce = [
      {
        unit = "seerr.service";
        until = "archive";
      }
    ];
    operations.units = ["seerr.service"];
    recovery = {
      order = 94;
      versionPolicy = "restore-archived-version-first";
      runbook = "docs/media-stack.md#recovery";
      acceptance = ["jellyfin-sonarr-and-radarr-connections-load"];
      secretOwners = ["mutable-state:/var/lib/private/jellyseerr"];
    };
    presentation = {
      group = "applications";
      title = "Seerr";
      icon = "jellyseerr.png";
      description = "Media discovery and requests";
      order = 80;
    };
  };

  sonarr = {
    endpoint = {
      authorizationOwner = "tailscale";
      exposure = "tailnet";
      port = 8989;
    };
    state.paths = ["/var/lib/sonarr/.config/NzbDrone"];
    backup.quiesce = [
      {
        unit = "sonarr.service";
        until = "archive";
      }
    ];
    storage.units = ["sonarr.service"];
    operations.units = ["sonarr.service"];
    recovery = {
      order = 92;
      versionPolicy = "restore-archived-version-first";
      runbook = "docs/media-stack.md#recovery";
      acceptance = ["series-root-download-client-and-history-load"];
      secretOwners = ["mutable-state:/var/lib/sonarr/.config/NzbDrone"];
    };
    presentation = {
      group = "operations";
      title = "Sonarr";
      icon = "sonarr.png";
      description = "Television automation";
      order = 50;
    };
  };

  syncthing = {
    endpoint = {
      authorizationOwner = "tailscale";
      exposure = "tailnet";
      port = 19384;
    };
    state = {
      paths = [
        "/home/maxpw/.config/syncthing"
        "/home/maxpw/Sync"
      ];
    };
    backup.quiesce = [
      {
        unit = "syncthing.service";
        until = "archive";
      }
    ];
    operations.units = ["syncthing.service"];
    recovery = {
      order = 60;
      versionPolicy = "restore-archived-version-first";
      runbook = "docs/homelab-recovery.md#syncthing";
      acceptance = ["identity-reviewed-before-one-peer-reconnect"];
      secretOwners = [
        "sops:syncthing-gui-password"
        "mutable-state:/home/maxpw/.config/syncthing"
      ];
    };
    presentation = {
      group = "operations";
      title = "Syncthing";
      icon = "syncthing.png";
      description = "File sync status";
      order = 30;
    };
  };

  t3code = {
    endpoint = {
      authorizationOwner = "tailscale";
      exposure = "tailnet";
      port = 51000;
    };
    state.paths = ["/home/maxpw/.local/share/t3code"];
    backup.quiesce = [
      {
        scope = "user";
        user = "maxpw";
        unit = "t3code.service";
        until = "archive";
      }
    ];
    operations = {
      units = [];
      monitorException = "T3 Code is a user service; endpoint monitoring owns its availability.";
    };
    recovery = {
      order = 75;
      versionPolicy = "restore-archived-version-first";
      runbook = "docs/homelab-recovery.md#t3-code";
      acceptance = [
        "sqlite-integrity-check-passes"
        "environment-and-attachments-load"
        "existing-worktree-opens"
        "authenticated-workspace-creation-succeeds"
      ];
      secretOwners = ["mutable-state:/home/maxpw/.local/share/t3code/userdata/secrets"];
    };
    presentation = {
      group = "operations";
      title = "T3 Code";
      icon = "mdi-code-braces";
      description = "Remote AI coding";
      order = 40;
    };
  };

  vaultwarden = {
    endpoint = {
      authorizationOwner = "tailscale";
      exposure = "tailnet";
      port = 19003;
      monitorPath = "/alive";
    };
    state = {
      paths = ["/var/lib/bitwarden_rs"];
      database = "vaultwarden";
    };
    backup.quiesce = [
      {
        unit = "vaultwarden.service";
        until = "archive";
      }
    ];
    operations.units = ["vaultwarden.service"];
    recovery = {
      order = 40;
      versionPolicy = "restore-archived-version-first";
      runbook = "docs/homelab-recovery.md#vaultwarden";
      acceptance = [
        "representative-item-and-attachment-open"
        "send-and-rsa-identity-verified"
      ];
      secretOwners = [
        "sops:vaultwarden-environment"
        "mutable-state:/var/lib/bitwarden_rs"
      ];
    };
    presentation = {
      group = "applications";
      title = "Vaultwarden";
      icon = "vaultwarden.png";
      description = "Password manager";
      order = 50;
    };
  };
}
