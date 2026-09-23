{
  config,
  lib,
  pkgs,
}: let
  nextcloud = config.services.nextcloud;
  storeAppUpdater = config.systemd.services.nextcloud-update-store-apps;
  storeAppUpdaterTimer = config.systemd.timers.nextcloud-update-store-apps;
in
  assert lib.assertMsg (builtins.attrNames nextcloud.extraApps
    == [
      "calendar"
      "integration_paperless"
    ])
  "Nextcloud declarative app ownership must remain complete and explicit";
  assert lib.assertMsg (!nextcloud.autoUpdateApps.enable)
  "Nextcloud's broad app updater must stay disabled for immutable extraApps";
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
    pkgs.runCommand "nextcloud-apps-regression" {} ''
      touch "$out"
    ''
