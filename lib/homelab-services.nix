# Data only. Validation, defaults, and all derived views live in
# lib/homelab-inventory.nix and lib/homelab.nix.
{
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
