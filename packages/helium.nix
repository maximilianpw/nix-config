# Helium browser derivation.
#
# Vendored from oxcl/nix-flake-helium-browser (MIT licensed) rather than taken
# as a flake input — keeps it out of the trusted-input set and gives us full
# control. Source: https://github.com/oxcl/nix-flake-helium-browser
# Bump version + sha256 with `nix-update --flake helium`.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  patchelf,
  makeWrapper,
  wrapGAppsHook3,
  makeFontsConf,
  qt6,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  gtk4,
  adwaita-icon-theme,
  nss,
  nspr,
  libGL,
  libgbm,
  libdrm,
  libxkbcommon,
  libX11,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  libXrender,
  libxcb,
  libxshmfence,
  libXi,
  libXcursor,
  libXft,
  libXScrnSaver,
  libXtst,
  libSM,
  libICE,
  alsa-lib,
  dbus,
  cups,
  ffmpeg,
  libva,
  pipewire,
  wayland,
  vulkan-loader,
  systemd,
  xdg-utils,
  coreutils,
  pango,
  cairo,
  gdk-pixbuf,
  atk,
  at-spi2-atk,
  at-spi2-core,
  freetype,
  fontconfig,
  libuuid,
  expat,
  zlib,
  libxml2,
  libkrb5,
  snappy,
  udev,
  libXt,
  binutils,
  noto-fonts-cjk-sans,
  noto-fonts-cjk-serif,
  flags ? [],
}: let
  pname = "helium";
  version = "0.15.1.1";

  suffix =
    {
      aarch64-linux = "arm64";
      x86_64-linux = "amd64";
    }
    .${
      stdenv.hostPlatform.system
    }
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-bin_${version}-1_${suffix}.deb";
    sha256 = "sha256-URxmb6FqCAsJdKmQV+1ODyxNBeHvr86T7eLgeunZwV8=";
  };

  inherit (lib) makeLibraryPath makeSearchPathOutput;

  deps = [
    stdenv.cc.cc
    nss
    nspr
    libGL
    libgbm
    libdrm
    libxkbcommon
    libX11
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    libXrender
    libxcb
    libxshmfence
    libXi
    libXcursor
    libXft
    libXScrnSaver
    libXtst
    libSM
    libICE
    alsa-lib
    dbus
    cups
    ffmpeg
    libva
    pipewire
    wayland
    vulkan-loader
    systemd
    pango
    cairo
    gdk-pixbuf
    atk
    at-spi2-atk
    at-spi2-core
    freetype
    fontconfig
    libuuid
    expat
    zlib
    libxml2
    gtk3
    glib
    libXt
    libkrb5
    snappy
    udev
  ];

  libPath =
    makeLibraryPath deps
    + lib.optionalString stdenv.hostPlatform.is64bit
    (":" + makeSearchPathOutput "lib" "lib64" deps)
    + ":$out/opt/helium";

  fontsConf = makeFontsConf {
    fontDirectories = [
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
    ];
  };
in
  stdenv.mkDerivation {
    inherit pname version src;

    dontConfigure = true;
    dontBuild = true;
    dontPatchELF = true;
    dontStrip = true;

    nativeBuildInputs = [
      patchelf
      makeWrapper
      wrapGAppsHook3
      qt6.wrapQtAppsHook
      dpkg
      binutils
    ];

    dontWrapQtApps = true;

    buildInputs = [
      glib
      gsettings-desktop-schemas
      gtk3
      gtk4
      adwaita-icon-theme
      qt6.qtbase
      qt6.qtwayland
      libXt
      libkrb5
      snappy
      udev
      systemd
    ];

    unpackPhase = ''
      runHook preUnpack
      ar vx $src
      tar -xvf data.tar.xz
      runHook postUnpack
    '';

    installPhase = ''
      export HELIUM_LIB_PATH="${libPath}"
      ${builtins.readFile ./scripts/helium-install.sh}
    '';

    preFixup = ''
      gappsWrapperArgs+=(
        --prefix LD_LIBRARY_PATH : "${libPath}"
        --prefix PATH : ${lib.makeBinPath [xdg-utils coreutils]}
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"
        --set-default CHROME_VERSION_EXTRA nix
        --set FONTCONFIG_FILE "${fontsConf}"
        ${lib.concatMapStringsSep "\n      " (f: "--add-flags \"${f}\"") flags}
      )
    '';

    meta = {
      homepage = "https://helium.computer";
      description = "Private, fast, and honest web browser based on Chromium";
      license = lib.licenses.gpl3Only;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      maintainers = [];
      platforms = ["x86_64-linux" "aarch64-linux"];
      mainProgram = "helium";
    };
  }
