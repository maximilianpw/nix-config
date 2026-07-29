{
  config,
  lib,
  pkgs,
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  homepage = config.services.homepage-dashboard;
  nextcloud = config.services.nextcloud;

  groupName = group: builtins.head (builtins.attrNames group);
  bookmarkGroups = builtins.map groupName homepage.bookmarks;
  serviceGroups = builtins.map groupName homepage.services;
  bookmarksIn = index: let
    group = builtins.elemAt homepage.bookmarks index;
  in
    group.${groupName group};
  bookmarkSummary = bookmarks:
    builtins.map (bookmark: let
      name = groupName bookmark;
      item = builtins.head bookmark.${name};
    in {
      inherit name;
      inherit (item) href;
    })
    bookmarks;
  cardNames = group:
    builtins.map groupName group.${groupName group};
  allBookmarks = lib.concatMap (group: group.${groupName group}) homepage.bookmarks;
  bookmarkHasNoDescription = bookmark: let
    name = groupName bookmark;
  in
    !(builtins.head bookmark.${name} ? description);
  allCards = lib.concatMap (group: group.${groupName group}) homepage.services;
  cardUsesLoopbackMonitor = card: let
    name = groupName card;
  in
    lib.hasPrefix "http://127.0.0.1:" card.${name}.siteMonitor;
  renderedHomepageConfig = builtins.toJSON {
    inherit (homepage) bookmarks services widgets;
  };
in
  assert lib.assertMsg (bookmarkGroups
    == [
      "Everyday"
      "VEV"
      "RBI"
    ])
  "Homepage bookmark groups must retain their daily-use order";
  assert lib.assertMsg (bookmarkSummary (bookmarksIn 0)
    == [
      {
        name = "GitHub";
        href = "https://github.com/";
      }
      {
        name = "Pull Requests";
        href = "https://github.com/pulls";
      }
      {
        name = "YouTube";
        href = "https://www.youtube.com/";
      }
      {
        name = "X";
        href = "https://x.com/";
      }
      {
        name = "Calendar";
        href = "${homelab.publicEndpoints.nextcloud.url}/apps/calendar/";
      }
      {
        name = "Chess.com";
        href = "https://www.chess.com/";
      }
      {
        name = "Reddit";
        href = "https://www.reddit.com/";
      }
      {
        name = "Letterboxd";
        href = "https://letterboxd.com/";
      }
    ])
  "Homepage Everyday bookmarks must retain their exact names, order, and URLs";
  assert lib.assertMsg (bookmarkSummary (bookmarksIn 1)
    == [
      {
        name = "Outlook";
        href = "https://outlook.cloud.microsoft/mail/";
      }
      {
        name = "Lucca Schedule";
        href = "https://vev.ilucca.net/work-locations/schedule";
      }
      {
        name = "VEV GitHub";
        href = "https://github.com/VEV-platform-services";
      }
      {
        name = "AWS Access Portal";
        href = "https://d-8067153cb2.awsapps.com/";
      }
      {
        name = "Linear";
        href = "https://linear.app/";
      }
    ])
  "Homepage VEV bookmarks must retain their exact names, order, and URLs";
  assert lib.assertMsg (bookmarkSummary (bookmarksIn 2)
    == [
      {
        name = "PostHog";
        href = "https://eu.posthog.com/project/216724/web";
      }
      {
        name = "RBI Landing";
        href = "https://github.com/maximilianpw/rbi-landing";
      }
      {
        name = "Cloudflare";
        href = "https://dash.cloudflare.com/a2ca791db3863dceb49557db0f0f3647/rivierabeauty.com";
      }
      {
        name = "Riviera Beauty";
        href = "https://rivierabeauty.com/";
      }
    ])
  "Homepage RBI bookmarks must retain their exact names, order, and URLs";
  assert lib.assertMsg (lib.all bookmarkHasNoDescription allBookmarks)
  "Homepage bookmarks must remain compact launchers without descriptions";
  assert lib.assertMsg (serviceGroups
    == [
      "Applications"
      "Operations"
    ])
  "Homepage must keep Applications and Operations separate and ordered";
  assert lib.assertMsg (cardNames (builtins.elemAt homepage.services 0)
    == [
      "Home Assistant"
      "Nextcloud"
      "Paperless"
      "Miniflux"
      "Buzz"
    ])
  "Homepage Applications must retain their intended order";
  assert lib.assertMsg (cardNames (builtins.elemAt homepage.services 1)
    == [
      "Grafana"
      "Uptime Kuma"
      "Syncthing"
      "T3 Code"
    ])
  "Homepage Operations must retain their intended order";
  assert lib.assertMsg (lib.all cardUsesLoopbackMonitor allCards)
  "Every Homepage service card must monitor its direct loopback endpoint";
  assert lib.assertMsg (homepage.settings.target == "_self")
  "Homepage links must open in the current tab";
  assert lib.assertMsg (builtins.hasAttr "calendar" nextcloud.extraApps)
  "Nextcloud Calendar must be installed declaratively";
  assert lib.assertMsg (!lib.hasInfix "remote.php/dav/public-calendars" renderedHomepageConfig)
  "Homepage configuration must not contain a calendar bearer URL";
  assert lib.assertMsg (!lib.hasInfix "homepage-calendar-url" renderedHomepageConfig)
  "Homepage must not reference the deferred calendar secret before rollout two";
    pkgs.runCommand "homepage-calendar-regression" {} ''
      touch "$out"
    ''
