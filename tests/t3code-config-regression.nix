{
  lib,
  pkgs,
  linuxPackage,
  kim,
  joyce,
  cuno,
}: let
  # Compare declared packages rather than building Linux artifacts on Darwin.
  macPackages = joyce.home-manager.users.max-vev.home.packages;
  macPackage = lib.findFirst (package: (package.pname or "") == "t3code") null macPackages;
  service = kim.home-manager.users.maxpw.systemd.user.services.t3code.Service;
  retired = ["maxpw-t3-code-nightly" "t3-code" "t3-code@nightly"];
in
  assert lib.assertMsg (macPackage != null && macPackage.version == linuxPackage.version)
  "T3 Code desktop and server must share a release";
  assert lib.assertMsg (builtins.length service.ExecStart == 1 && lib.hasPrefix "${linuxPackage}/bin/t3 serve " (builtins.head service.ExecStart))
  "T3 Code must start its packaged CLI, not download from npm";
  assert lib.assertMsg (!(cuno.home-manager.users.maxpw.systemd.user.services ? t3code))
  "Cuno must not gain a T3 server implicitly";
  assert lib.assertMsg (joyce.launchd.user.envVariables.T3CODE_DISABLE_AUTO_UPDATE == "1")
  "Finder-launched T3 must not self-update";
  assert lib.assertMsg (builtins.all (cask: !(builtins.elem (builtins.baseNameOf cask.name) retired)) joyce.homebrew.casks)
  "T3 casks must not be reintroduced";
    pkgs.runCommand "t3code-config-regression" {} ''touch "$out"''
