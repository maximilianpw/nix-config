{
  config,
  pkgs,
  lib,
  ...
}: {
  # ===========================================
  # On-Premise Services
  # ===========================================
  # This module configures self-hosted services:
  # - Tailscale (mesh VPN)
  # - Nextcloud (file sync & sharing)
  # - Roon Server (music library management)

  # -------------------------------------------
  # Tailscale
  # -------------------------------------------
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };
  networking.firewall.trustedInterfaces = ["tailscale0"];

  # -------------------------------------------
  # Nextcloud
  # -------------------------------------------
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud32;
    hostName = "nextcloud.nas";

    # Use HTTPS (nginx will handle this)
    https = true;

    # Auto-update Nextcloud apps
    autoUpdateApps.enable = true;

    # Database configuration (PostgreSQL)
    database.createLocally = true;
    config = {
      dbtype = "pgsql";
      adminuser = "admin";
      adminpassFile = config.sops.secrets.nextcloud-admin-password.path;
    };

    # Performance settings
    configureRedis = true;
    caching.redis = true;

    # Nextcloud settings
    settings = {
      # Trust Tailscale network
      trusted_proxies = ["127.0.0.1" "::1"];
      overwriteprotocol = "https";

      # Allow access from Tailscale IP and hostname
      trusted_domains = [
        "nextcloud.localhost"
        "100.76.56.97"
        "nextcloud.main-pc"
        "nextcloud.nas"
        "main-pc"
      ];

      # Default phone region
      default_phone_region = "FR";

      # Maintenance window (4 AM local time)
      maintenance_window_start = 4;
    };

    # PHP tuning
    maxUploadSize = "16G";
    phpOptions = {
      "opcache.interned_strings_buffer" = "16";
      "opcache.memory_consumption" = "256";
    };
  };

  # Nginx configuration for Nextcloud
  systemd.services.nextcloud-ssl-init = {
    description = "Generate self-signed SSL certs for Nextcloud";
    wantedBy = ["multi-user.target"];
    before = ["nginx.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /var/lib/nextcloud/ssl
      if [ ! -f /var/lib/nextcloud/ssl/cert.pem ]; then
        ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:4096 \
          -keyout /var/lib/nextcloud/ssl/key.pem \
          -out /var/lib/nextcloud/ssl/cert.pem \
          -days 365 -nodes \
          -subj "/CN=nextcloud.nas" \
          -addext "subjectAltName=DNS:nextcloud.nas,DNS:hass.nas,DNS:nextcloud.localhost,DNS:hass.localhost"
      fi
      chown nginx:nginx /var/lib/nextcloud/ssl/key.pem
      chown nginx:nginx /var/lib/nextcloud/ssl/cert.pem
      chmod 600 /var/lib/nextcloud/ssl/key.pem
      chmod 644 /var/lib/nextcloud/ssl/cert.pem
    '';
  };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."nextcloud.nas" = {
      forceSSL = true;
      enableACME = false;
      sslCertificate = "/var/lib/nextcloud/ssl/cert.pem";
      sslCertificateKey = "/var/lib/nextcloud/ssl/key.pem";
      serverAliases = ["nextcloud.main-pc" "nextcloud.nas"];
    };

    virtualHosts."hass.nas" = {
      forceSSL = true;
      enableACME = false;
      sslCertificate = "/var/lib/nextcloud/ssl/cert.pem";
      sslCertificateKey = "/var/lib/nextcloud/ssl/key.pem";
      serverAliases = ["hass.main-pc" "hass.nas"];
      locations."/" = {
        proxyPass = "http://127.0.0.1:8123";
        proxyWebsockets = true;
      };
    };
  };

  # Open firewall for Nextcloud (HTTP/HTTPS)
  networking.firewall.allowedTCPPorts = [80 443];

  # -------------------------------------------
  # Roon Server
  # -------------------------------------------
  services.roon-server = {
    enable = true;
    openFirewall = true;
  };

  # Ensure roon user has access to audio and nextcloud groups
  users.users.roon-server = {
    extraGroups = ["audio" "nextcloud"];
    isSystemUser = true;
    group = "roon-server";
  };
  users.groups.roon-server = {};

  services.home-assistant = {
    enable = true;
    openFirewall = true;
    extraPackages = ps:
      with ps; [
        gtts
        isal
        roonapi
        pyatv
      ];
    extraComponents = [
      "default_config"
      "met" # weather
      "radio_browser"
      "hue"
      "mobile_app"
      "roon"
      "systemmonitor"
      "apple_tv"
      "homekit"
      "homekit_controller"
      "icloud"
      "upnp"
      "speedtestdotnet"
      "ping"
      "wake_on_lan"
      "zeroconf"
      "ssdp"
      "sfr_box"
      "rest"
      "command_line"
    ];
    config = {
      homeassistant = {
        name = "Home";
        unit_system = "metric";
        time_zone = "Europe/Paris";
        external_url = "https://hass.localhost";
        internal_url = "http://127.0.0.1:8123";
      };
      http = {
        use_x_forwarded_for = true;
        trusted_proxies = ["127.0.0.1" "::1" "100.64.0.0/10"];
      };
    };
  };
}
