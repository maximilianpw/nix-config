{
  config,
  lib,
  pkgs,
}: let
  expect = import ./lib/expect.nix {inherit lib;};
  homelab = import ../lib/homelab.nix {inherit lib;};
  containers = config.virtualisation.oci-containers.containers;
  manifest = config.custom.backup.manifestMetadata;
  names = ["autobrr" "cross-seed" "kometa" "maintainerr" "recyclarr" "tdarr" "unpackerr"];
  noPublicListener = name:
    homelab.services.${name}.endpoint.exposure
    == "tailnet"
    && !(builtins.elem homelab.services.${name}.endpoint.port config.networking.firewall.allowedTCPPorts);
  requiresMediaMounts = name: let
    service = config.systemd.services.${name};
  in
    builtins.elem "srv.mount" service.requires
    && builtins.elem "media-secondary-directories.service" service.requires
    && builtins.elem "srv-media\\x2dsecondary.mount" service.bindsTo;
in
  assert lib.assertMsg (lib.all noPublicListener ["autobrr" "maintainerr" "tdarr"])
  "media companion dashboards must stay private without host firewall openings";
  assert expect.all "private listeners and credential bootstrap must be explicit" [
    (config.services.autobrr.settings.host == "127.0.0.1")
    (builtins.elem "autobrr-session.service" config.systemd.services.autobrr.requires)
    (containers.maintainerr.environment.UI_HOSTNAME == "127.0.0.1")
    (containers.tdarr.ports == ["127.0.0.1:8265:8265"])
    (config.services.cross-seed.settings.host == "127.0.0.1")
  ];
  assert lib.assertMsg (lib.all (name: lib.hasInfix "@sha256:" containers.${name}.image) ["maintainerr" "tdarr" "kometa"])
  "media companion OCI images must use immutable digests";
  assert lib.assertMsg (lib.all requiresMediaMounts ["unpackerr" "cross-seed" "docker-tdarr"])
  "new media readers and writers must stop when either media mount is unavailable";
  assert expect.all "unconfigured acquisition and library mutation must remain guarded" [
    (config.systemd.services.cross-seed.unitConfig.ConditionPathExists == "/var/lib/cross-seed/integrations.json")
    (config.services.cross-seed.settings.action == "save")
    (config.systemd.services.docker-kometa.unitConfig.ConditionPathExists == "/var/lib/kometa/config.yml")
    (containers.tdarr.environment.startPaused == "true")
    (containers.tdarr.environment.transcodecpuWorkers == "0")
    (containers.tdarr.environment.transcodegpuWorkers == "0")
    (config.systemd.services.unpackerr.environment.UN_SONARR_0_DELETE_ORIG == "false")
    (config.systemd.services.unpackerr.environment.UN_RADARR_0_DELETE_ORIG == "false")
    (config.systemd.services.unpackerr.environment.UN_LIDARR_0_DELETE_ORIG == "false")
    (!builtins.hasAttr "chaptarr" homelab.services)
  ];
  assert lib.assertMsg (lib.all (name:
    builtins.hasAttr name manifest.applicationVersions
    && lib.all (path: builtins.elem path manifest.expectedPrimaryStatePaths) homelab.services.${name}.state.paths
    && lib.all (entry: builtins.elem entry.unit homelab.backup.archiveUnits) homelab.services.${name}.backup.quiesce)
  names)
  "every companion must have backed-up control state, version metadata, and archive quiescing";
  assert expect.all "Servarr secrets must be loaded from runtime files rather than embedded in configuration" [
    (config.systemd.services.recyclarr.serviceConfig.LoadCredential
      == [
        "sonarr-config:/var/lib/sonarr/.config/NzbDrone/config.xml"
        "radarr-config:/var/lib/radarr/.config/Radarr/config.xml"
      ])
    (builtins.length config.systemd.services.unpackerr.serviceConfig.LoadCredential == 3)
    (!(config.systemd.services.recyclarr.environment ? SONARR_API_KEY))
    (!(config.systemd.services.unpackerr.environment ? UN_SONARR_0_API_KEY))
    (builtins.elem "recyclarr.timer" homelab.backup.archiveUnits)
  ];
    pkgs.runCommand "media-companions-regression" {nativeBuildInputs = [pkgs.python3];} ''
      python3 ${./media-manager-api-env-test.py} ${../scripts/media-manager-api-env.py}
      touch "$out"
    ''
