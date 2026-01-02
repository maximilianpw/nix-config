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
  services.tailscale.enable = true;
  networking.firewall.trustedInterfaces = ["tailscale0"];

  # -------------------------------------------
  # Nextcloud
  # -------------------------------------------
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud32;
    hostName = "nextcloud.localhost";

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
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."nextcloud.localhost" = {
      forceSSL = true;
      enableACME = false;
      sslCertificate = "/var/lib/nextcloud/ssl/cert.pem";
      sslCertificateKey = "/var/lib/nextcloud/ssl/key.pem";
      serverAliases = ["100.76.56.97" "main-pc"];
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
    extraComponents = [
      "default_config"
      "met" # weather
      "radio_browser"
      "hue"
      # Add others as needed: "hue" "zwave" "mqtt" etc.
    ];
    config = {
      homeassistant = {
        name = "Home";
        unit_system = "metric";
        time_zone = "Europe/Paris";
        # Trust Tailscale network for reverse proxy headers
        trusted_proxies = ["127.0.0.1" "::1" "100.64.0.0/10"];
      };
      http = {
        use_x_forwarded_for = true;
        trusted_proxies = ["127.0.0.1" "::1" "100.64.0.0/10"];
      };
    };
  };
}
