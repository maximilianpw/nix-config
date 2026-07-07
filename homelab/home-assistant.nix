{lib, ...}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit (homelab.publicEndpoints) homeassistant;
in {
  services.home-assistant = {
    enable = true;
    # Reached only via the Cloudflare tunnel; no LAN port.
    openFirewall = false;

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
        external_url = homeassistant.url;
        internal_url = homeassistant.monitorUrl;
      };
      http = {
        server_host = "127.0.0.1";
        server_port = homeassistant.port;
        use_x_forwarded_for = true;
        trusted_proxies = ["127.0.0.1" "::1"];
      };
    };
  };
}
