{
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit (homelab.publicEndpoints) homeassistant;
in {
  services.postgresql = {
    enable = true;
    ensureDatabases = ["hass"];
    ensureUsers = [
      {
        name = "hass";
        ensureDBOwnership = true;
      }
    ];
  };

  services.home-assistant = {
    enable = true;
    # Reached only via the Cloudflare tunnel; no LAN port.
    openFirewall = false;

    extraPackages = ps:
      with ps; [
        gtts
        isal
        psycopg2
        pyatv
        roonapi
      ];

    customLovelaceModules = with pkgs.home-assistant-custom-lovelace-modules; [
      apexcharts-card
      auto-entities
      mini-media-player
      mushroom
    ];

    # Make these integrations available to UI/YAML configuration. Listing an
    # integration here packages it, but does not activate it by itself.
    extraComponents = [
      # Provides Home Assistant's standard bundle of built-in integrations.
      "default_config"
      # Provides weather forecasts from the Norwegian Meteorological Institute.
      "met"
      # Browses and plays stations from the Radio Browser internet directory.
      "radio_browser"
      # Connects Companion apps and provides their sensors and push notifications.
      "mobile_app"
      # Exposes host CPU, memory, disk, network, and process sensors.
      "systemmonitor"
      # Reads WAN status and traffic statistics from UPnP/IGD routers.
      "upnp"
      # Measures internet latency and bandwidth through Speedtest.net.
      "speedtestdotnet"
      # Wakes network devices by sending Wake-on-LAN magic packets.
      "wake_on_lan"
      # Discovers local services advertised through mDNS/DNS-SD.
      "zeroconf"
      # Discovers UPnP devices and services through SSDP multicast.
      "ssdp"
      # Integrates an SFR Box router and its network information.
      "sfr_box"
      # Creates entities and actions backed by HTTP REST endpoints.
      "rest"
      # Creates entities that read data or control devices through local commands.
      "command_line"
    ];

    config = {
      mobile_app = {};
      homeassistant = {
        name = "Home";
        unit_system = "metric";
        time_zone = "Europe/Paris";
        external_url = homeassistant.url;
      };
      http = {
        server_host = "127.0.0.1";
        server_port = homeassistant.port;
        use_x_forwarded_for = true;
        trusted_proxies = ["127.0.0.1" "::1"];
        ip_ban_enabled = true;
        login_attempts_threshold = 5;
      };
      recorder = {
        # Peer authentication maps the systemd service user to the local
        # PostgreSQL role, so the connection needs no stored password.
        db_url = "postgresql://@/hass";
      };
    };
  };

  systemd.services.home-assistant = {
    after = ["postgresql.service"];
    requires = ["postgresql.service"];
  };
}
