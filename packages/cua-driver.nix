{
  autoPatchelfHook,
  fetchurl,
  lib,
  libX11,
  libXi,
  libxkbcommon,
  stdenv,
  stdenvNoCC,
}: let
  pname = "cua-driver";
  version = "0.52.0";
  system = stdenv.hostPlatform.system;
  isDarwin = stdenv.hostPlatform.isDarwin;

  artifacts = {
    aarch64-darwin = {
      name = "darwin-universal";
      hash = "sha256-GeXmUtuDzAMk56OJjuh1uHsmWtfhwJ/YYu94hpSA9h0=";
    };
    x86_64-darwin = {
      name = "darwin-universal";
      hash = "sha256-GeXmUtuDzAMk56OJjuh1uHsmWtfhwJ/YYu94hpSA9h0=";
    };
    aarch64-linux = {
      name = "linux-arm64-binary";
      hash = "sha256-XH0KNsDjaPsoR/ImyhQ1xgv7eaw5aNmwipTYLJfaiAo=";
    };
    x86_64-linux = {
      name = "linux-x86_64-binary";
      hash = "sha256-VcmexBdxcLGkQKXv1B5Vusrh6f4lfJbc2eW4HvkIUDY=";
    };
  };

  artifact =
    artifacts.${system}
    or (throw "Unsupported system: ${system}");

  src = fetchurl {
    url = "https://github.com/trycua/cua/releases/download/cua-driver-rs-v${version}/cua-driver-rs-${version}-${artifact.name}.tar.gz";
    inherit (artifact) hash;
  };
in
  stdenvNoCC.mkDerivation {
    inherit pname version src;

    sourceRoot =
      if isDarwin
      then "cua-driver-rs-${version}-darwin-universal"
      else ".";
    dontBuild = true;

    nativeBuildInputs = lib.optionals (!isDarwin) [autoPatchelfHook];
    buildInputs = lib.optionals (!isDarwin) [stdenv.cc.cc.lib libX11 libXi libxkbcommon];

    # The Darwin release app is signed by upstream. Any fixup of its Mach-O
    # binaries would invalidate that signature and break macOS TCC attribution.
    dontFixup = isDarwin;

    installPhase =
      if isDarwin
      then ''
        runHook preInstall

        mkdir -p "$out/Applications" "$out/bin"
        cp -R CuaDriver.app "$out/Applications/CuaDriver.app"

        cat > "$out/bin/cua-driver" <<'EOF'
        #!/bin/sh
        exec /Applications/CuaDriver.app/Contents/MacOS/cua-driver "$@"
        EOF
        chmod +x "$out/bin/cua-driver"

        runHook postInstall
      ''
      else ''
        runHook preInstall

        mkdir -p "$out/bin" "$out/libexec/cua-driver"
        cp -R . "$out/libexec/cua-driver/"
        chmod +x "$out/libexec/cua-driver/cua-driver" "$out/libexec/cua-driver/cua-cursor-theme"
        ln -s "$out/libexec/cua-driver/cua-driver" "$out/bin/cua-driver"

        runHook postInstall
      '';

    doInstallCheck = true;
    installCheckPhase =
      if isDarwin
      then ''
        /usr/bin/codesign --verify --deep --strict "$out/Applications/CuaDriver.app"
        test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$out/Applications/CuaDriver.app/Contents/Info.plist")" = "com.trycua.driver"
      ''
      else ''
        "$out/bin/cua-driver" --version
      '';

    passthru.updateScript = ./update-cua-driver.sh;

    meta = {
      description = "Cross-platform computer-use driver for AI agents";
      homepage = "https://github.com/trycua/cua";
      license = lib.licenses.mit;
      mainProgram = "cua-driver";
      platforms = builtins.attrNames artifacts;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
