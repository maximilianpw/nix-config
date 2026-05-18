{
  stdenv,
  lib,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libGL,
  libpulseaudio,
  libuuid,
  libva,
  libvdpau,
  libxkbcommon,
  libxshmfence,
  mesa,
  nspr,
  nss,
  pango,
  pipewire,
  systemd,
  vulkan-loader,
  wayland,
  xorg,
}: let
  pname = "helium";
  version = "0.12.3.1";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64_linux.tar.xz";
    hash = "sha256-a4kcudN+bsOV253BSmTFsx0Tngmr/jbUd/A1gesc6QE=";
  };

  runtimeLibs = [
    libGL
    libvdpau
    libva
    pipewire
    alsa-lib
    libpulseaudio
  ];
in
  stdenv.mkDerivation {
    inherit pname version src;

    nativeBuildInputs = [
      autoPatchelfHook
      copyDesktopItems
      makeWrapper
    ];

    buildInputs = [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      dbus
      expat
      fontconfig
      freetype
      gdk-pixbuf
      glib
      gtk3
      libdrm
      libGL
      libpulseaudio
      libuuid
      libxkbcommon
      libxshmfence
      mesa
      nspr
      nss
      pango
      pipewire
      systemd
      vulkan-loader
      wayland
      xorg.libX11
      xorg.libXScrnSaver
      xorg.libXcomposite
      xorg.libXcursor
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXi
      xorg.libXrandr
      xorg.libXrender
      xorg.libXtst
      xorg.libxcb
    ];

    autoPatchelfIgnoreMissingDeps = [
      "libQt5Core.so.5"
      "libQt5Gui.so.5"
      "libQt5Widgets.so.5"
      "libQt6Core.so.6"
      "libQt6Gui.so.6"
      "libQt6Widgets.so.6"
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin $out/opt/helium $out/share/icons/hicolor/256x256/apps
      cp -R . $out/opt/helium

      makeWrapper $out/opt/helium/helium $out/bin/helium \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}" \
        --add-flags "--ozone-platform-hint=auto" \
        --add-flags "--enable-features=WaylandWindowDecorations" \
        --add-flags "--disable-component-update" \
        --add-flags "--simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'" \
        --add-flags "--check-for-update-interval=0" \
        --add-flags "--disable-background-networking"

      cp product_logo_256.png $out/share/icons/hicolor/256x256/apps/helium.png

      runHook postInstall
    '';

    desktopItems = [
      (makeDesktopItem {
        name = "helium";
        exec = "helium %U";
        icon = "helium";
        desktopName = "Helium";
        genericName = "Web Browser";
        categories = ["Network" "WebBrowser"];
        terminal = false;
        mimeTypes = [
          "text/html"
          "text/xml"
          "application/xhtml+xml"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
        ];
      })
    ];

    meta = with lib; {
      description = "Private, fast, and honest web browser based on ungoogled-chromium";
      homepage = "https://helium.computer";
      license = licenses.gpl3Only;
      platforms = ["x86_64-linux"];
      mainProgram = "helium";
    };
  }
