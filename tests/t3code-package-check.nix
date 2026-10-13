{
  pkgs,
  package,
}:
pkgs.runCommand "t3code-package-check" {nativeBuildInputs = [pkgs.coreutils pkgs.git pkgs.bash];} ''
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME"
  timeout 30 ${package}/bin/t3 serve --help > help.txt
  grep -F 't3 serve' help.txt
  grep -F -- '--base-dir' help.txt
  timeout 30 ${package}/bin/t3 --version > version.txt
  grep -Fx 't3 v${package.version}' version.txt
  ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
    /usr/bin/codesign --verify --deep --strict '${package}/Applications/T3 Code (Nightly).app'
    test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' '${package}/Applications/T3 Code (Nightly).app/Contents/Info.plist')" = '${package.version}'
  ''}
  # Darwin's build sandbox rejects native server subprocesses (spawn EPERM).
  # Run this disposable-state test outside the sandbox on macOS; Linux has its
  # own loopback namespace and can exercise it as a build check.
  ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
    ${pkgs.python3}/bin/python3 ${../scripts/tests/t3code-server-smoke.py} ${package}/bin/t3 ${package.version}
  ''}
  touch "$out"
''
