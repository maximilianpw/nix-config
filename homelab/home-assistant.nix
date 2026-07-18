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
