{
  config,
  lib,
  pkgs,
}: let
  nextcloud = config.services.nextcloud;
  paperless = config.services.paperless;
  schedulerPostStart = config.systemd.services.paperless-scheduler.serviceConfig.ExecStartPost;
in
  assert lib.assertMsg paperless.configureTika
  "Paperless must retain Office-document ingestion through Tika and Gotenberg";
  assert lib.assertMsg (paperless.settings.PAPERLESS_TASK_WORKERS == 2)
  "Paperless task workers must remain capped on the shared homelab host";
  assert lib.assertMsg (paperless.settings.PAPERLESS_THREADS_PER_WORKER == 1)
  "Paperless OCR threads must remain capped on the shared homelab host";
  assert lib.assertMsg nextcloud.appstoreEnable
  "packaged Nextcloud apps must not disable existing app-store apps";
  assert lib.assertMsg (builtins.hasAttr "integration_paperless" nextcloud.extraApps)
  "Nextcloud must include its Paperless integration app";
  assert lib.assertMsg (lib.hasInfix "superuser-state" schedulerPostStart)
  "Paperless must remove its persisted plaintext bootstrap state after startup";
    pkgs.runCommand "paperless-config-regression" {} ''
      touch "$out"
    ''
