{
  fleetPackages,
  joyce,
  kim,
  lib,
  pkgs,
}: let
  kimPackage = fleetPackages.x86_64-linux.fleet;
  joycePackage = fleetPackages.aarch64-darwin.fleet;
  kimFleet = kim.programs.fleet;
  joyceFleet = joyce.programs.fleet;
  fleetPackageCount = config:
    lib.count (package: lib.getName package == "fleet") config.home.packages;
  kimFleetAgents =
    lib.filterAttrs
    (name: _: lib.hasPrefix "fleet-tunnel-" name)
    kim.launchd.agents;
  fleetAgents =
    lib.filterAttrs
    (name: _: lib.hasPrefix "fleet-tunnel-" name)
    joyce.launchd.agents;
  agent3000 = fleetAgents."fleet-tunnel-3000";
  agent5173 = fleetAgents."fleet-tunnel-5173";
  kimConfig = pkgs.writeText "fleet-kim-config.toml" kim.xdg.configFile."fleet/config.toml".text;
  joyceConfig = pkgs.writeText "fleet-joyce-config.toml" joyce.xdg.configFile."fleet/config.toml".text;
in
  assert lib.assertMsg (
    kimFleet.enable
    && kimFleet.package == kimPackage
    && fleetPackageCount kim == 1
  )
  "Kim must install exactly one Fleet package from the pinned Fleet input";
  assert lib.assertMsg (
    joyceFleet.enable
    && joyceFleet.package == joycePackage
    && fleetPackageCount joyce == 1
  )
  "Joyce must install exactly one Fleet package from the pinned Fleet input";
  assert lib.assertMsg (
    kimFleet.settings.current_host
    == "kim"
    && joyceFleet.settings.current_host == "joyce"
    && kim.xdg.configFile ? "fleet/config.toml"
    && joyce.xdg.configFile ? "fleet/config.toml"
  )
  "Installed Fleet settings must generate the runtime config for each current host";
  assert lib.assertMsg (kimFleetAgents == {})
  "Kim must not install launchd Fleet agents";
  assert lib.assertMsg (
    builtins.attrNames fleetAgents
    == ["fleet-tunnel-3000" "fleet-tunnel-5173"]
    && agent3000.config.Label == "org.nix-community.home.fleet-tunnel-3000"
    && agent5173.config.Label == "org.nix-community.home.fleet-tunnel-5173"
    && lib.hasPrefix "${joycePackage}/bin/fleet-tunnel-runner" (builtins.head agent3000.config.ProgramArguments)
    && lib.hasPrefix "${joycePackage}/bin/fleet-tunnel-runner" (builtins.head agent5173.config.ProgramArguments)
  )
  "Joyce must use the Rust runner while preserving the managed launchd labels";
    pkgs.runCommand "fleet-installed-regression" {
      nativeBuildInputs = [kimPackage];
      inherit joyceConfig kimConfig;
    } ''
      fleet --config "$kimConfig" config validate
      fleet --config "$joyceConfig" config validate
      touch "$out"
    ''
