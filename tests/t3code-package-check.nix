{
  pkgs,
  package,
  desktopPackage ? null,
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
    # Upstream builds a launcher bundle, not a notarized release artifact.
    app="${desktopPackage}/Applications/${package.unwrapped.appName}.app"
    test -x "${desktopPackage}/bin/t3code-desktop"
    test -x "$app/Contents/MacOS/${package.unwrapped.appName}"
    test -f "$app/Contents/Info.plist"
    test -d "$app/Contents/Resources"
    ${pkgs.python3}/bin/python3 - <<'PY'
    import json
    from pathlib import Path
    manifest = Path("${package.unwrapped.desktop}/libexec/t3code/apps/desktop/package.json")
    assert json.loads(manifest.read_text())["version"] == "${package.version}"
    PY
    grep -Fx 'Name=${package.unwrapped.appName}' "${desktopPackage}/share/applications/t3code.desktop"
  ''}
  # Darwin's build sandbox rejects native server subprocesses (spawn EPERM).
  # Run this disposable-state test outside the sandbox on macOS; Linux has its
  # own loopback namespace and can exercise it as a build check.
  ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
    ${pkgs.python3}/bin/python3 ${../scripts/tests/t3code-server-smoke.py} ${package}/bin/t3 ${package.version}
  ''}
  touch "$out"
''
