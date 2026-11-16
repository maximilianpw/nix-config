{
  lib,
  pkgs,
  core,
  package,
  home,
  files,
}: let
  expectedLauncher =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "/usr/bin/open -a Herdr"
    else "hc";
  # Comparing output paths before names forces unrelated package build graphs.
  hasPackage = expected:
    builtins.any (installed: lib.getName installed == lib.getName expected && toString installed == toString expected) home.home.packages;
  coreConfig = builtins.fromTOML (builtins.readFile files.".config/herdr-core/config.toml".source);
  appPrefix = ".config/herdr-app/";
  mods = ["migrated-pane" "migrated-pane-name" "migrated-scrollback" "migrated-spaces" "migrated-terminal" "migrated-tools" "tmux-prefix"];
  appFiles =
    [
      "keys.json"
      "layouts/migrated.json"
      "layouts/migrated.svg"
      "themes/catppuccin-mocha.json"
      "mods/migrated-pane/close.svg"
      "mods/migrated-pane/split-down.svg"
      "mods/migrated-pane/split-right.svg"
      "mods/migrated-pane/unzoom.svg"
      "mods/migrated-pane/zoom.svg"
      "mods/migrated-tools/backend/bridge"
      "mods/migrated-tools/backend/bridge-lib.mjs"
      "mods/migrated-tools/backend/tools.mjs"
    ]
    ++ lib.concatMap (mod: map (file: "mods/${mod}/${file}") ["main.js" "mod.json"]) mods;
  appSource = path: files."${appPrefix}${path}".source;
  # Tests stay in the repository; backend.test.mjs and core-smoke.test.mjs need
  # a live Herdr core and are run by hand with `bun test`.
  appTests = ../users/maxpw/files/managed/.config/herdr-app;
  keys = builtins.fromJSON (builtins.readFile (appSource "keys.json"));
  layout = builtins.fromJSON (builtins.readFile (appSource "layouts/migrated.json"));
  theme = builtins.fromJSON (builtins.readFile (appSource "themes/catppuccin-mocha.json"));
in
  assert hasPackage core;
  # The migrated App still uses this backend, but not the TUI's registry hook.
  assert hasPackage package;
  assert !(home.home.activation ? linkHerdrJJ);
  assert builtins.all (installed: !(builtins.elem (lib.getName installed) ["herdr" "herdr-shell"])) home.home.packages;
  assert builtins.all (name: let
    file = home.home.file.".local/bin/${name}";
  in
    toString file.source == "${core}/bin/${name}" && file.force) ["hc" "herdr-core"];
  assert builtins.all (shell: shell.shellAliases.h == expectedLauncher) [home.programs.bash home.programs.fish home.programs.nushell];
  assert coreConfig.history_mb == 50;
  assert !(home.xdg.configFile ? "herdr-core/config.toml");
  # An exact manifest keeps app-owned settings, state, shipped mods and generated
  # guides/types out of Hjem, including future accidental additions to ./files.
  assert builtins.filter (lib.hasPrefix appPrefix) (builtins.attrNames files) == lib.sort builtins.lessThan (map (path: appPrefix + path) appFiles);
  assert builtins.all (path: files."${appPrefix}${path}".type == "symlink") appFiles;
  assert keys.global."ctrl-space" == "mod.open:tmux-prefix";
  assert keys."layout:migrated"."ctrl-h" == "migrated-tools.go-left";
  assert layout.preview == "layouts/migrated.svg";
  assert builtins.length theme.ansi == 16;
    pkgs.runCommand "herdr-config-regression" {
      nativeBuildInputs = [pkgs.nodejs];
    } ''
      test -x ${appSource "mods/migrated-tools/backend/bridge"}
      node --experimental-vm-modules --test \
        ${appTests}/mods/tmux-prefix/main.test.mjs \
        ${appTests}/mods/migrated-tools/controller.test.mjs
      touch "$out"
    ''
