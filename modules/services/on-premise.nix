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
  networking.firewall.trustedInterfaces = ["wg-mullvad" "tailscale0"];

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
      trusted_proxies = ["127.0.0.1" "::1" "100.64.0.0/10"];
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

  # -------------------------------------------
  # SSL Certificate Management
  # -------------------------------------------
  # Self-signed certificates for local .nas domains
  # Stored in neutral location since used by multiple services

  systemd.services.local-ssl-init = {
    description = "Generate/renew self-signed SSL certs for local services";
    wantedBy = ["multi-user.target"];
    before = ["nginx.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "ssl-certs";
    };
    script = ''
      SSL_DIR="/var/lib/ssl-certs"
      CERT="$SSL_DIR/cert.pem"
      KEY="$SSL_DIR/key.pem"
      RENEW_DAYS=30

      generate_cert() {
        ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:4096 \
          -keyout "$KEY" \
          -out "$CERT" \
          -days 365 -nodes \
          -subj "/CN=local.nas" \
          -addext "subjectAltName=DNS:nextcloud.nas,DNS:hass.nas,DNS:nextcloud.localhost,DNS:hass.localhost,DNS:nextcloud.main-pc,DNS:hass.main-pc"
      }

      # Generate if missing
      if [ ! -f "$CERT" ]; then
        echo "Generating new SSL certificate..."
        generate_cert
      else
        # Check expiry and renew if within RENEW_DAYS
        EXPIRY=$(${pkgs.openssl}/bin/openssl x509 -enddate -noout -in "$CERT" | cut -d= -f2)
        EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
        NOW_EPOCH=$(date +%s)
        DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

        if [ "$DAYS_LEFT" -lt "$RENEW_DAYS" ]; then
          echo "Certificate expires in $DAYS_LEFT days, renewing..."
          generate_cert
        else
          echo "Certificate valid for $DAYS_LEFT more days"
        fi
      fi

      chown nginx:nginx "$KEY" "$CERT"
      chmod 600 "$KEY"
      chmod 644 "$CERT"
    '';
  };

  # Timer to check certificate expiry weekly
  systemd.timers.local-ssl-renew = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  systemd.services.local-ssl-renew = {
    description = "Check and renew SSL certificates";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl restart local-ssl-init.service";
    };
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
      sslCertificate = "/var/lib/ssl-certs/cert.pem";
      sslCertificateKey = "/var/lib/ssl-certs/key.pem";
      serverAliases = ["nextcloud.main-pc"];
    };

    virtualHosts."hass.nas" = {
      forceSSL = true;
      enableACME = false;
      sslCertificate = "/var/lib/ssl-certs/cert.pem";
      sslCertificateKey = "/var/lib/ssl-certs/key.pem";
      serverAliases = ["hass.main-pc"];
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
        external_url = "https://hass.nas";
        internal_url = "http://127.0.0.1:8123";
      };
      http = {
        use_x_forwarded_for = true;
        trusted_proxies = ["127.0.0.1" "::1" "100.64.0.0/10"];
      };
    };
  };
}
