{
  config,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  tailnetDomain = config.homelab.tailnet.domain;
  endpoints = homelab.endpoints tailnetDomain;

  bookmark = name: icon: href: {
    ${name} = [
      {inherit href icon;}
    ];
  };
  bookmarkGroup = name: bookmarks: {${name} = bookmarks;};

  homepageSettings = {
    title = "Homelab";
    theme = "dark";
    color = "zinc";
    headerStyle = "clean";
    iconStyle = "theme";
    statusStyle = "dot";
    target = "_self";
    useEqualHeights = true;
    disableCollapse = true;
    hideVersion = true;
    disableUpdateCheck = true;
    disableIndexing = true;
  };
  settingsFormat = pkgs.formats.yaml {};
  generatedSettings = settingsFormat.generate "homepage-settings-base.yaml" homepageSettings;
  # Nix attribute sets sort their keys. Homepage instead uses YAML mapping order
  # to interleave bookmark and service groups, so append this small ordered
  # presentation-only layout rather than encoding the order in fake group names.
  orderedSettings = pkgs.concatText "homepage-settings.yaml" [
    generatedSettings
    ./homepage/layout.yaml
  ];
in {
  custom.backup.applicationVersions.homepage = config.services.homepage-dashboard.package.version;

  # The nixpkgs module exposes no listen-address option; Homepage is a
  # Next.js standalone server and binds the address given in $HOSTNAME.
  # Tailscale Serve is its only ingress path.
  systemd.services.homepage-dashboard.environment.HOSTNAME = "127.0.0.1";

  # Preserve the presentation order in the generated YAML; see orderedSettings.
  environment.etc."homepage-dashboard/settings.yaml".source = lib.mkForce orderedSettings;

  services.homepage-dashboard = {
    enable = true;
    listenPort = endpoints.homelab.port;
    allowedHosts = homelab.allowedHosts endpoints.homelab.host;
    openFirewall = false;

    settings = homepageSettings;

    customCSS = builtins.readFile ./homepage/custom.css;

    bookmarks = [
      (bookmarkGroup "Everyday" [
        (bookmark "GitHub" "github.png" "https://github.com/")
        (bookmark "Pull Requests" "github.png" "https://github.com/pulls")
        (bookmark "YouTube" "youtube.png" "https://www.youtube.com/")
        (bookmark "X" "x.png" "https://x.com/")
        (bookmark "Calendar" "nextcloud.png" "${homelab.publicEndpoints.nextcloud.url}/apps/calendar/")
        (bookmark "Chess.com" "si-chessdotcom" "https://www.chess.com/")
        (bookmark "Reddit" "reddit.png" "https://www.reddit.com/")
        (bookmark "Letterboxd" "si-letterboxd" "https://letterboxd.com/")
      ])
      (bookmarkGroup "VEV" [
        (bookmark "Outlook" "microsoft-outlook.png" "https://outlook.cloud.microsoft/mail/")
        (bookmark "Lucca Schedule" "mdi-calendar-clock-outline" "https://vev.ilucca.net/work-locations/schedule")
        (bookmark "VEV GitHub" "github.png" "https://github.com/VEV-platform-services")
        (bookmark "AWS Access Portal" "amazon-web-services.png" "https://d-8067153cb2.awsapps.com/")
        (bookmark "Linear" "linear.png" "https://linear.app/")
      ])
      (bookmarkGroup "RBI" [
        (bookmark "PostHog" "posthog.png" "https://eu.posthog.com/project/216724/web")
        (bookmark "RBI Landing" "github.png" "https://github.com/maximilianpw/rbi-landing")
        (bookmark "Cloudflare" "cloudflare.png" "https://dash.cloudflare.com/a2ca791db3863dceb49557db0f0f3647/rivierabeauty.com")
        (bookmark "Riviera Beauty" "mdi-storefront-outline" "https://rivierabeauty.com/")
      ])
    ];

    # Availability checks stay on loopback; public and tailnet URLs are launch
    # targets only. Uptime Kuma remains responsible for external availability.
    services = homelab.homepageServiceGroups tailnetDomain;

    widgets = [
      {
        datetime = {
          text_size = "xl";
          format = {
            dateStyle = "medium";
            timeStyle = "short";
          };
        };
      }
      {
        # Without committed coordinates Homepage asks the browser for its
        # location. This works because Tailscale Serve provides HTTPS.
        openmeteo = {
          units = "metric";
          cache = 5;
          format.maximumFractionDigits = 1;
        };
      }
      {
        search = {
          provider = [
            "duckduckgo"
            "brave"
            "google"
          ];
          target = "_self";
          showSearchSuggestions = true;
        };
      }
    ];
  };
}
