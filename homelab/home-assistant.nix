_: {
  services.home-assistant = {
    enable = true;
    # Reached only via the Cloudflare tunnel (127.0.0.1:8123); no LAN port.
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
        external_url = "https://homeassistant.maximilian.pw";
        internal_url = "http://127.0.0.1:8123";
      };
      http = {
        use_x_forwarded_for = true;
        trusted_proxies = ["127.0.0.1" "::1"];
      };
    };
  };
}
