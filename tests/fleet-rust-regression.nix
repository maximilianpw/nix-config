# Pinned standalone Fleet coverage matrix:
# - SSH/tmux/session validation: ssh_named_session_uses_explicit_remote_tmux_and_tty,
#   local_ssh_uses_path_tmux_and_main_default, and unsafe_session_is_rejected_before_planning_ssh.
# - Attachment forwards, aliases, and SSH policy: ssh_named_session_repeatable_forwards_normalize_loopback,
#   known_alias_keeps_nix_target_triple, ad_hoc_forward_passes_bracketed_remote_host_as_data,
#   and argument_policy_is_passed_through_unchanged.
# - Tunnel state and launchd parsing: status_uses_one_job_read_per_mapping,
#   pause_only_requested_job_and_survives_relogin, and resume_loaded_stopped_uses_kickstart.
# - Doctor classifications and deadlines: doctor_ssh_unavailable_skips_remote_probe,
#   doctor_ssh_auth_skips_remote_probe, doctor_remote_down_is_not_local_health,
#   and system_ssh_deadline_kills_hanging_child.
# - Runner startup, reconnect, listener ownership, and signal cleanup:
#   production_startup_deadline_is_forty_five_seconds, transport_failure_after_startup_reconnects,
#   listener_ownership_accepts_job_or_direct_ssh_child, stop_during_startup_reaps_owned_child,
#   and stop_after_healthy_listener_reaps_owned_child.
# - Schema/config validation: nix_projection_fields_round_trip_through_validation and
#   config_validate_success_and_invalid_exit_codes, plus the external Home Manager evaluations below.
# Callers pass fleetSrc; this file must not bake a checkout path into the flake.
{
  lib,
  pkgs,
  fleetSrc,
  homeManager,
}: let
  inherit (lib) concatStringsSep filterAttrs hasSuffix;

  defaultTunnels = import ../modules/fleet/default-tunnels.nix;
  mkFleet = args:
    import ../lib/fleet.nix ({
        inherit lib;
      }
      // args);

  joyce = mkFleet {
    hostname = "joyce";
    homeDirectory = "/Users/max-vev";
    tunnels = defaultTunnels.joyce or [];
  };
  kim = mkFleet {
    hostname = "kim";
    homeDirectory = "/home/maxpw";
  };

  placeholderPackage = pkgs.runCommand "fleet-placeholder-package" {} ''
    mkdir -p "$out/bin"
    : >"$out/bin/fleet"
    : >"$out/bin/fleet-tunnel-runner"
    chmod +x "$out/bin/fleet" "$out/bin/fleet-tunnel-runner"
  '';
  expectedTriple = token: {
    ssh_target = token;
    tmux_target = "tm-${token}";
    forward_target = "fleet-forward-${token}";
  };
  identityFields = host:
    (host ? hostKey)
    || (host ? identityFile)
    || (host ? identityAgent)
    || (host ? client)
    || (host ? port);

  joyceKim = joyce.settings.hosts.kim;
  joyceLocal = joyce.settings.hosts.joyce;
  joyceCuno = joyce.settings.hosts.cuno;
  kimJoyce = kim.settings.hosts.joyce;
  kimLocal = kim.settings.hosts.kim;

  fictionalSettings = {
    schema_version = 1;
    current_host = "laptop";
    hosts = {
      laptop = {
        ssh_target = "laptop";
        display_target = "laptop.local";
        aliases = [];
        os = "darwin";
        role = "interface";
        user = "developer";
        client_enrolled = true;
        gui = true;
        long_running_agents = false;
      };
      workbox = {
        ssh_target = "workbox";
        display_target = "workbox.example";
        aliases = ["dev"];
        os = "nixos";
        role = "compute";
        user = "developer";
        client_enrolled = true;
        gui = false;
        long_running_agents = true;
        tmux_command = "tmux";
        tmux_session = "main";
        tmux_target = "tm-workbox";
        forward_target = "fleet-forward-workbox";
        alias_targets.dev = expectedTriple "dev";
      };
    };
    tunnels = {
      supervisor = "launchd";
      mappings = [
        {
          host = "workbox";
          local_port = 5173;
          remote_port = 5173;
          remote_host = "localhost";
          label = "org.nix-community.home.fleet-tunnel-5173";
        }
      ];
    };
  };

  invalidConfig = pkgs.writeText "fleet-invalid.toml" ''
    schema_version = 99
    current_host = "missing"
  '';

  homeManagerSrc = homeManager.outPath or (toString homeManager);
  mkEvalPkgs = darwin:
    if darwin
    then import pkgs.path {system = "aarch64-darwin";}
    else pkgs;

  loadCandidate = src: let
    suppliedFlake = builtins.isAttrs src && src ? packages && src ? homeManagerModules;
    sourcePath =
      if builtins.isAttrs src
      then src.outPath
      else src;
    srcPath = toString sourcePath;
    moduleFile = sourcePath + "/nix/home-manager.nix";
    packageFile = sourcePath + "/nix/package.nix";
    flakeTry =
      if suppliedFlake
      then {
        success = true;
        value = src;
      }
      else if builtins.pathExists (sourcePath + "/flake.nix")
      then builtins.tryEval (builtins.getFlake "path:${srcPath}")
      else {
        success = false;
        value = null;
      };
    flake =
      if flakeTry.success
      then flakeTry.value
      else null;
    system = pkgs.stdenv.hostPlatform.system;
    systemPackages =
      if flake != null && flake ? packages && builtins.hasAttr system flake.packages
      then flake.packages.${system}
      else {};
    # Prefer the live module file so concurrent checkout edits are visible
    # without depending on a getFlake snapshot.
    module =
      if builtins.pathExists moduleFile
      then import moduleFile
      else if flake != null && flake ? homeManagerModules && flake.homeManagerModules ? default
      then flake.homeManagerModules.default
      else throw "fleetSrc has no nix/home-manager.nix and no homeManagerModules.default: ${srcPath}";
    package =
      systemPackages.fleet
      or systemPackages.default
      or (
        if builtins.pathExists packageFile
        then pkgs.callPackage packageFile {}
        else throw "fleetSrc has no packages.${system}.fleet and no nix/package.nix: ${srcPath}"
      );
  in {
    inherit module package;
    modules =
      if builtins.isList module
      then module
      else [module];
  };

  candidate = loadCandidate fleetSrc;

  evalFleetHome = {
    darwin,
    package,
    settings,
  }: let
    evalPkgs = mkEvalPkgs darwin;
    extendedLib = import (homeManagerSrc + "/modules/lib/stdlib-extended.nix") lib;
    hmModules = import (homeManagerSrc + "/modules/modules.nix") {
      pkgs = evalPkgs;
      lib = extendedLib;
      check = true;
      minimal = false;
    };
    raw = extendedLib.evalModules {
      modules =
        [
          {
            home = {
              username = "tester";
              homeDirectory = "/tmp/fleet-rust-hm";
              stateVersion = "25.05";
            };
            targets.darwin = {
              linkApps.enable = false;
              copyApps.enable = false;
            };
            programs.fleet = {
              enable = true;
              inherit package settings;
            };
          }
        ]
        ++ candidate.modules
        ++ hmModules;
      class = "homeManager";
      specialArgs = {
        modulesPath = homeManagerSrc + "/modules";
      };
    };
    failed = map (x: x.message) (lib.filter (x: !x.assertion) raw.config.assertions);
  in
    if failed == []
    then raw.config
    else throw "Fleet Home Manager evaluation failed:\n${concatStringsSep "\n" failed}";

  enabledLaunchdAgents = config:
    filterAttrs (_: agent: agent.enable or false) (config.launchd.agents or {});

  configTomlText = config: let
    file = config.xdg.configFile."fleet/config.toml" or null;
  in
    if file == null
    then throw "candidate Home Manager module did not set xdg.configFile.\"fleet/config.toml\""
    else file.text;

  linuxFictional = evalFleetHome {
    darwin = false;
    package = placeholderPackage;
    settings = fictionalSettings;
  };
  darwinFictional = evalFleetHome {
    darwin = true;
    package = placeholderPackage;
    settings = fictionalSettings;
  };
  linuxPersonal = evalFleetHome {
    darwin = false;
    package = placeholderPackage;
    inherit (joyce) settings;
  };
  darwinPersonal = evalFleetHome {
    darwin = true;
    package = placeholderPackage;
    inherit (joyce) settings;
  };

  linuxFictionalAgents = enabledLaunchdAgents linuxFictional;
  linuxPersonalAgents = enabledLaunchdAgents linuxPersonal;
  darwinFictionalAgents = enabledLaunchdAgents darwinFictional;
  darwinPersonalAgents = enabledLaunchdAgents darwinPersonal;
  darwinPersonal3000 = darwinPersonalAgents."fleet-tunnel-3000" or null;
  darwinPersonal5173 = darwinPersonalAgents."fleet-tunnel-5173" or null;
  darwinFictional5173 = darwinFictionalAgents."fleet-tunnel-5173" or null;
  ordinarySshBlocks = builtins.attrValues joyce.sshSettings;
  hasArg = args: needle: lib.elem needle args;
in
  assert lib.assertMsg (
    joyce.aliases.fl
    == "fleet list"
    && joyce.aliases.fs == "fleet ssh"
    && joyce.files ? contract
    && joyce.files ? hostsJson
    && joyce.files ? knownHosts
  )
  "projection must keep the generated contract, host data, known hosts, and aliases";
  assert lib.assertMsg (
    ordinarySshBlocks
    != []
    && lib.all (block: block.ForwardAgent == "no") ordinarySshBlocks
    && lib.all (block: !(block ? LocalForward)) ordinarySshBlocks
  )
  "ordinary SSH blocks must be nonempty, disable agent forwarding, and omit LocalForward";
  assert lib.assertMsg (
    joyce.settings.schema_version
    == 1
    && joyce.settings.current_host == "joyce"
    && kim.settings.current_host == "kim"
    && joyce.settings.tunnels.supervisor == "launchd"
    && kim.settings.tunnels.supervisor == "none"
    && kim.settings.tunnels.mappings == []
  )
  "v1 settings must set schema_version, current_host, and Darwin-only launchd supervision";
  assert lib.assertMsg (
    joyceLocal.ssh_target
    == "joyce"
    && joyceLocal.display_target == "maximilians-macbook-pro-1"
    && joyceLocal.ssh_target != joyceLocal.display_target
    && !(joyceLocal ? tmux_target)
    && !(joyceLocal ? forward_target)
    && !(joyceLocal ? alias_targets)
    && joyceLocal.os == "darwin"
    && joyceLocal.gui
    && joyceLocal.client_enrolled
    && joyceLocal.user == "max-vev"
    && !joyceLocal.long_running_agents
  )
  "Joyce local host must keep display_target as hostName and omit remote target triples";
  assert lib.assertMsg (
    joyceKim.ssh_target
    == "kim"
    && joyceKim.display_target == "kim"
    && joyceKim.os == "nixos"
    && joyceKim.tmux_target == "tm-kim"
    && joyceKim.forward_target == "fleet-forward-kim"
    && joyceKim.alias_targets."main-pc" == expectedTriple "main-pc"
    && joyceKim.alias_targets.main == expectedTriple "main"
    && joyceKim.alias_targets.desktop == expectedTriple "desktop"
    && joyceKim.t3code_port == 51000
    && joyceKim.long_running_agents
    && joyceKim.client_enrolled
    && !joyceKim.gui
  )
  "Kim remote projection must use inventory-key ssh_target, NixOS os, and alias target triples";
  assert lib.assertMsg (
    joyceCuno.os
    == "nixos-wsl"
    && !joyceCuno.client_enrolled
    && joyceCuno.alias_targets.wsl == expectedTriple "wsl"
    && kimJoyce.ssh_target == "joyce"
    && kimJoyce.display_target == "maximilians-macbook-pro-1"
    && kimJoyce.tmux_target == "tm-joyce"
    && kimJoyce.forward_target == "fleet-forward-joyce"
    && kimJoyce.alias_targets.macbook == expectedTriple "macbook"
    && kimJoyce.alias_targets.mac == expectedTriple "mac"
    && !(kimLocal ? tmux_target)
    && !(kimLocal ? alias_targets)
  )
  "Remote Joyce/Cuno projections must keep display_target vs ssh_target and alias triples";
  assert lib.assertMsg (
    lib.all (host: !identityFields host) (builtins.attrValues joyce.settings.hosts)
    && lib.all (host: !identityFields host) (builtins.attrValues kim.settings.hosts)
  )
  "v1 settings must not project host keys, identity files, or client records";
  assert lib.assertMsg (
    map (m: m.label) joyce.settings.tunnels.mappings
    == [
      "org.nix-community.home.fleet-tunnel-3000"
      "org.nix-community.home.fleet-tunnel-5173"
    ]
    && lib.all (m: m.host == "kim" && m.remote_host == "localhost") joyce.settings.tunnels.mappings
  )
  "Joyce mappings must keep baseline labels, kim as host, and localhost remotes";
  assert lib.assertMsg (
    linuxFictional.xdg.configFile ? "fleet/config.toml"
    && linuxPersonal.xdg.configFile ? "fleet/config.toml"
    && darwinFictional.xdg.configFile ? "fleet/config.toml"
    && darwinPersonal.xdg.configFile ? "fleet/config.toml"
    && lib.elem placeholderPackage linuxFictional.home.packages
    && lib.elem placeholderPackage linuxPersonal.home.packages
  )
  "candidate module must generate xdg.configFile.\"fleet/config.toml\" and install the selected package";
  assert lib.assertMsg (linuxFictionalAgents == {} && linuxPersonalAgents == {})
  "Linux Home Manager evaluation must not enable launchd tunnel jobs";
  assert lib.assertMsg (
    darwinFictional5173
    != null
    && darwinFictional5173.enable
    && darwinFictional5173.config.Label == "org.nix-community.home.fleet-tunnel-5173"
    && darwinFictional5173.config.RunAtLoad == true
    && darwinFictional5173.config.KeepAlive.SuccessfulExit == false
    && darwinFictional5173.config.ThrottleInterval == 30
    && darwinFictional5173.config.ProcessType == "Background"
    && (darwinFictional5173.config.StandardOutPath or null) == null
    && (darwinFictional5173.config.StandardErrorPath or null) == null
    && hasSuffix "/bin/fleet-tunnel-runner" (builtins.head darwinFictional5173.config.ProgramArguments)
    && builtins.elemAt darwinFictional5173.config.ProgramArguments 1 == "5173"
    && hasArg darwinFictional5173.config.ProgramArguments "127.0.0.1:5173:localhost:5173"
    && hasArg darwinFictional5173.config.ProgramArguments "fleet-forward-workbox"
    && hasArg darwinFictional5173.config.ProgramArguments "ForwardAgent=no"
    && hasArg darwinFictional5173.config.ProgramArguments "ControlMaster=no"
  )
  "Darwin fictional jobs must keep baseline labels, keepalive, runner argv, and forwarding policy";
  assert lib.assertMsg (
    darwinPersonal3000
    != null
    && darwinPersonal5173 != null
    && builtins.attrNames darwinPersonalAgents == ["fleet-tunnel-3000" "fleet-tunnel-5173"]
    && darwinPersonal3000.config.Label == "org.nix-community.home.fleet-tunnel-3000"
    && darwinPersonal5173.config.Label == "org.nix-community.home.fleet-tunnel-5173"
    && darwinPersonal3000.config.RunAtLoad == true
    && darwinPersonal5173.config.RunAtLoad == true
    && darwinPersonal3000.config.KeepAlive.SuccessfulExit == false
    && darwinPersonal5173.config.KeepAlive.SuccessfulExit == false
    && darwinPersonal3000.config.ThrottleInterval == 30
    && darwinPersonal5173.config.ThrottleInterval == 30
    && darwinPersonal3000.config.ProcessType == "Background"
    && darwinPersonal5173.config.ProcessType == "Background"
    && (darwinPersonal3000.config.StandardOutPath or null) == null
    && (darwinPersonal3000.config.StandardErrorPath or null) == null
    && (darwinPersonal5173.config.StandardOutPath or null) == null
    && (darwinPersonal5173.config.StandardErrorPath or null) == null
    && hasSuffix "/bin/fleet-tunnel-runner" (builtins.head darwinPersonal3000.config.ProgramArguments)
    && hasSuffix "/bin/fleet-tunnel-runner" (builtins.head darwinPersonal5173.config.ProgramArguments)
    && hasArg darwinPersonal3000.config.ProgramArguments "127.0.0.1:3000:localhost:3000"
    && hasArg darwinPersonal5173.config.ProgramArguments "127.0.0.1:5173:localhost:5173"
    && hasArg darwinPersonal3000.config.ProgramArguments "fleet-forward-kim"
    && hasArg darwinPersonal5173.config.ProgramArguments "fleet-forward-kim"
    && hasArg darwinPersonal3000.config.ProgramArguments "ForwardAgent=no"
    && hasArg darwinPersonal5173.config.ProgramArguments "ForwardAgent=no"
    && hasArg darwinPersonal3000.config.ProgramArguments "ControlMaster=no"
    && hasArg darwinPersonal5173.config.ProgramArguments "ControlMaster=no"
  )
  "Darwin personal jobs must keep labels, lifecycle fields, loopback forwards, and SSH policy";
    pkgs.runCommand "fleet-rust-regression" {
      fleetBin = "${candidate.package}/bin/fleet";
      fictionalConfig = pkgs.writeText "fleet-fictional.toml" (configTomlText linuxFictional);
      personalConfig = pkgs.writeText "fleet-personal.toml" (configTomlText linuxPersonal);
      fictionalDarwinConfig = pkgs.writeText "fleet-fictional-darwin.toml" (configTomlText darwinFictional);
      personalDarwinConfig = pkgs.writeText "fleet-personal-darwin.toml" (configTomlText darwinPersonal);
      inherit invalidConfig;
    } ''
      set -eu
      export HOME="$PWD/home"
      mkdir -p "$HOME"

      "$fleetBin" --help >/dev/null

      fleet_validate() {
        config_path="$1"
        if "$fleetBin" --help 2>/dev/null | grep -F -- '--config' >/dev/null; then
          "$fleetBin" --config "$config_path" config validate
        else
          FLEET_CONFIG="$config_path" "$fleetBin" config validate
        fi
      }

      fleet_validate "$fictionalConfig"
      fleet_validate "$personalConfig"
      cmp "$fictionalConfig" "$fictionalDarwinConfig"
      cmp "$personalConfig" "$personalDarwinConfig"

      set +e
      fleet_validate "$invalidConfig"
      status=$?
      set -e
      if [[ "$status" -eq 0 ]]; then
        echo "fleet config validate accepted invalid config" >&2
        exit 1
      fi
      if [[ "$status" -ne 2 ]]; then
        echo "fleet config validate on invalid config exited $status, expected 2" >&2
        exit 1
      fi

      touch "$out"
    ''
