{
  lib,
  pkgs,
  linuxPackage,
  darwinPackage,
  desktopPackage,
  kim,
  joyce,
  cuno,
}: let
  # Compare declared packages rather than building Linux artifacts on Darwin.
  macPackages = joyce.home-manager.users.max-vev.home.packages;
  service = kim.home-manager.users.maxpw.systemd.user.services.t3code.Service;
  retired = ["maxpw-t3-code-nightly" "t3-code" "t3-code@nightly"];
in
  assert lib.assertMsg (builtins.all (package:
    lib.hasInfix "-nightly." package.version
    && package.unwrapped.appName == "T3 Code (Nightly)"
    && package.src.tag == "v${package.version}"
    && toString package.pnpmDeps.src == toString package.src
    && package.pnpmDeps.version == package.version
    && toString package.resourceMonitor.src == toString package.src
    && package.resourceMonitor.version == package.version) [linuxPackage darwinPackage])
  "T3 Code nightly source, dependency graph, native monitor, and desktop branding must stay aligned";
  assert lib.assertMsg (builtins.elem (toString desktopPackage) (map toString macPackages) && builtins.elem (toString darwinPackage.desktop) (map toString desktopPackage.paths) && darwinPackage.version == linuxPackage.version)
  "T3 Code desktop must use the packaged server output and share Kim's release";
  assert lib.assertMsg (builtins.elem (toString darwinPackage) (map toString macPackages))
  "Joyce must retain the standalone t3 CLI alongside the desktop";
  assert lib.assertMsg (builtins.length service.ExecStart == 1 && lib.hasPrefix "${linuxPackage}/bin/t3 serve " (builtins.head service.ExecStart))
  "T3 Code must start its packaged CLI, not download from npm";
  assert lib.assertMsg (!(cuno.home-manager.users.maxpw.systemd.user.services ? t3code))
  "Cuno must not gain a T3 server implicitly";
  assert lib.assertMsg (joyce.launchd.user.envVariables.T3CODE_DISABLE_AUTO_UPDATE == "1")
  "Finder-launched T3 must not self-update";
  assert lib.assertMsg (builtins.all (cask: !(builtins.elem (builtins.baseNameOf cask.name) retired)) joyce.homebrew.casks)
  "T3 casks must not be reintroduced";
    pkgs.runCommand "t3code-config-regression" {} ''touch "$out"''
