{
  config,
  homelab,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (homelab.services.food-tracker) endpoint;
  package = pkgs.callPackage ../packages/food-tracker.nix {src = inputs.food-tracker-src;};
  stateDir = "/var/lib/food-tracker";
  visionModel = "qwen2.5vl:7b";
  ollama = config.services.ollama;
in {
  custom.backup.applicationVersions.food-tracker = inputs.food-tracker-src.shortRev or "ci-stub";

  users.users.food-tracker = {
    isSystemUser = true;
    group = "food-tracker";
  };
  users.groups.food-tracker = {};

  # One Node process serves the web app, its API and the assistant endpoint
  # (/mcp). The API has no login of its own: it must stay on loopback, with
  # Tailscale Serve in front deciding who reaches it. Never give it a public
  # Cloudflare route or a firewall opening.
  systemd.services.food-tracker = {
    description = "Foodlog kitchen and food journal";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    environment = {
      HOST = "127.0.0.1";
      PORT = toString endpoint.port;
      DATABASE_PATH = "${stateDir}/foodlog.db";
      MIGRATIONS_DIR = "${package}/migrations";
      STATIC_DIR = "${package}/client";
      # Receipts and shopping lists are read on this machine; photos never leave it.
      VISION_BASE_URL = "http://${ollama.host}:${toString ollama.port}/v1";
      VISION_MODEL = visionModel;
    };
    serviceConfig = {
      ExecStart = "${lib.getExe pkgs.nodejs} ${package}/server/main.mjs";
      User = "food-tracker";
      Group = "food-tracker";
      StateDirectory = "food-tracker";
      StateDirectoryMode = "0700";
      Restart = "on-failure";
      RestartSec = 5;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
      RestrictNamespaces = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
      CapabilityBoundingSet = "";
    };
  };

  # The vision model for scans. CPU-only here: a first scan takes under a minute
  # while the model loads, later ones about ten seconds. The model (about 6 GB)
  # is downloaded once on activation and can always be downloaded again.
  services.ollama = {
    enable = true;
    loadModels = [visionModel];
  };
}
