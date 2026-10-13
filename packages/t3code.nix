# Official release binaries, coordinated by update-t3code.py. The headless CLI
# runs the bundled server with Electron's Node runtime (no npm at service start).
{
  pkgs,
  lib,
  ...
}: let
  release = builtins.fromJSON (builtins.readFile ./t3code-release.json);
  inherit (release) version;
  system = pkgs.stdenv.hostPlatform.system;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  appName = "T3 Code (Nightly)";
  suffix =
    if isDarwin
    then "arm64.zip"
    else "x86_64.AppImage";
  src = pkgs.fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-${suffix}";
    inherit (release.sources.${system}) hash;
  };
  meta = {
    description = "T3 Code nightly desktop and headless server";
    homepage = "https://github.com/pingdotgg/t3code";
    license = lib.licenses.mit;
    platforms = ["aarch64-darwin" "x86_64-linux"];
    mainProgram = "t3code";
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
in
  if isDarwin
  then
    pkgs.stdenvNoCC.mkDerivation {
      pname = "t3code";
      inherit version src meta;
      nativeBuildInputs = [pkgs.unzip pkgs.makeBinaryWrapper];
      # Never modify/re-sign the upstream notarized bundle.
      dontFixup = true;
      unpackPhase = ''
        runHook preUnpack
        unzip -q "$src"
        runHook postUnpack
      '';
      installPhase = ''
        runHook preInstall
        mkdir -p "$out/Applications" "$out/bin"
        cp -R "${appName}.app" "$out/Applications/"
        app="$out/Applications/${appName}.app/Contents"
        makeWrapper "$app/MacOS/${appName}" "$out/bin/t3code" \
          --set T3CODE_DISABLE_AUTO_UPDATE 1
        makeWrapper "$app/MacOS/${appName}" "$out/bin/t3" \
          --set ELECTRON_RUN_AS_NODE 1 \
          --add-flag "$app/Resources/app.asar/apps/server/dist/bin.mjs"
        runHook postInstall
      '';
    }
  else
    pkgs.stdenv.mkDerivation {
      pname = "t3code";
      inherit version meta;
      src = pkgs.appimageTools.extract {
        pname = "t3code";
        inherit version src;
      };
      nativeBuildInputs = [pkgs.autoPatchelfHook pkgs.makeWrapper pkgs.wrapGAppsHook3];
      buildInputs = with pkgs; [
        alsa-lib
        at-spi2-atk
        cairo
        cups
        dbus
        expat
        gdk-pixbuf
        glib
        gtk3
        libGL
        libdrm
        libgbm
        libsecret
        libxkbcommon
        libxshmfence
        nspr
        nss
        pango
        stdenv.cc.cc
        systemdLibs
        vulkan-loader
        libX11
        libXcomposite
        libXdamage
        libXext
        libXfixes
        libXrandr
        libxcb
        libxkbfile
      ];
      appendRunpaths = map (pkg: "${lib.getLib pkg}/lib") (with pkgs; [
        libGL
        libnotify
        libpulseaudio
        libsecret
        pciutils
        vulkan-loader
      ]);
      # An unused musl prebuild ships alongside the glibc native modules.
      autoPatchelfIgnoreMissingDeps = ["libc.musl-x86_64.so.1"];
      dontWrapGApps = true;
      dontConfigure = true;
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        mkdir -p "$out/libexec/t3code"
        cp -R . "$out/libexec/t3code/"
        chmod -R u+w "$out/libexec/t3code"
        # Launch Electron directly against Nix libraries, not AppRun's bundled
        # distro support tree (which carries obsolete GTK/DBus dependencies).
        rm -rf "$out/libexec/t3code/usr" "$out/libexec/t3code/AppRun" \
          "$out/libexec/t3code/.DirIcon" "$out/libexec/t3code/t3code.png" \
          "$out/libexec/t3code/t3code.desktop"
        rm "$out/libexec/t3code/libvulkan.so.1"
        ln -s ${lib.getLib pkgs.vulkan-loader}/lib/libvulkan.so.1 "$out/libexec/t3code/"
        runHook postInstall
      '';
      postFixup = ''
        makeWrapper "$out/libexec/t3code/t3code" "$out/bin/t3code" \
          "''${gappsWrapperArgs[@]}" --set T3CODE_DISABLE_AUTO_UPDATE 1
        makeWrapper "$out/libexec/t3code/t3code" "$out/bin/t3" \
          --set ELECTRON_RUN_AS_NODE 1 \
          --add-flags "$out/libexec/t3code/resources/app.asar/apps/server/dist/bin.mjs"
      '';
    }
