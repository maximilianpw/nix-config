{
  config,
  lib,
  pkgs,
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  homepage = config.services.homepage-dashboard;
  nextcloud = config.services.nextcloud;
  storeAppUpdater = config.systemd.services.nextcloud-update-store-apps;
  storeAppUpdaterTimer = config.systemd.timers.nextcloud-update-store-apps;

  groupName = group: builtins.head (builtins.attrNames group);
  allCards = lib.concatMap (group: group.${groupName group}) homepage.services;
  serviceGroup = name:
    lib.findFirst
    (group: builtins.hasAttr name group)
    (throw "Homepage service group not found: ${name}")
    homepage.services;
  serviceCard = group: name:
    lib.findFirst
    (card: builtins.hasAttr name card)
    (throw "Homepage service card not found: ${group}/${name}")
    (serviceGroup group).${group};
  nextcloudCard = (serviceCard "Applications" "Nextcloud").Nextcloud;
  cardUsesLoopbackMonitor = card: let
    name = groupName card;
  in
    lib.hasPrefix "http://127.0.0.1:" card.${name}.siteMonitor;
  renderedHomepageConfig = builtins.toJSON {
    inherit (homepage) bookmarks services widgets;
  };
in
  assert lib.assertMsg (lib.all cardUsesLoopbackMonitor allCards)
  "Every Homepage service card must monitor its direct loopback endpoint";
  assert lib.assertMsg (nextcloudCard.siteMonitor == "${homelab.loopbackUrl homelab.publicServices.nextcloud.port}/status.php")
  "Homepage must monitor Nextcloud's non-redirecting status endpoint";
  assert lib.assertMsg (builtins.attrNames nextcloud.extraApps
    == [
      "calendar"
      "integration_paperless"
    ])
  "Nextcloud declarative app ownership must remain complete and explicit";
  assert lib.assertMsg (nextcloud.extraApps.calendar.version == "6.5.4")
  "Nextcloud Calendar must retain the pinned 6.5.4 release";
  assert lib.assertMsg (!nextcloud.autoUpdateApps.enable)
  "Nextcloud's broad app updater must stay disabled for immutable extraApps";
  assert lib.assertMsg ((config.systemd.services.nextcloud-update-plugins.serviceConfig.ExecStart or null) == null)
  "The broad app:update --all service must not be executable";
  assert lib.assertMsg (storeAppUpdater.serviceConfig.User == "nextcloud")
  "The mutable app updater must run as the Nextcloud service user";
  assert lib.assertMsg (builtins.elem "nextcloud-setup.service" storeAppUpdater.after)
  "The mutable app updater must run after setup when both are queued";
  assert lib.assertMsg (builtins.elem "srv.mount" storeAppUpdater.requires)
  "The mutable app updater must require persistent storage";
  assert lib.assertMsg (!builtins.elem "nextcloud-setup.service" storeAppUpdater.requires)
  "The recurring mutable app updater must not rerun Nextcloud setup";
  assert lib.assertMsg (storeAppUpdaterTimer.timerConfig.OnCalendar == "05:00")
  "The mutable app updater must retain its daily schedule";
  assert lib.assertMsg storeAppUpdaterTimer.timerConfig.Persistent
  "The mutable app updater must catch up after downtime";
  assert lib.assertMsg (lib.all (name: lib.any (package: lib.getName package == name) config.environment.systemPackages) [
    "nextcloud-app-ownership-check"
    "nextcloud-update-store-apps"
  ])
  "Nextcloud ownership and targeted update commands must remain installed";
  assert lib.assertMsg (!lib.hasInfix "remote.php/dav/public-calendars" renderedHomepageConfig)
  "Homepage configuration must not contain a calendar bearer URL";
  assert lib.assertMsg (!lib.hasInfix "homepage-calendar-url" renderedHomepageConfig)
  "Homepage must not reference the deferred calendar secret before rollout two";
    pkgs.runCommand "homepage-calendar-regression" {} ''
      touch "$out"
    ''
