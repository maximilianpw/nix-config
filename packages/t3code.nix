{
  pkgs,
  lib,
  fetchurl,
}: let
  pname = "t3code";
  version = "0.0.9";

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
    sha256 = "sha256:8dd2e6ae239bf56b2eb0e20268f85e8710f1e2002cc4755bf2624f2248054d98";
  };

  appimageContents = pkgs.appimageTools.extractType2 {
    inherit pname version src;
  };
in
  pkgs.appimageTools.wrapType2 {
    inherit pname version src;

    extraInstallCommands = ''
      install -m 444 -D ${appimageContents}/t3-code-desktop.desktop $out/share/applications/t3-code-desktop.desktop
      substituteInPlace $out/share/applications/t3-code-desktop.desktop \
        --replace 'Exec=AppRun' "Exec=${pname}" \
        --replace 'Icon=t3-code-desktop' "Icon=$out/share/pixmaps/t3-code-desktop.png"

      install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/1024x1024/apps/t3-code-desktop.png $out/share/pixmaps/t3-code-desktop.png
    '';

    meta = with lib; {
      description = "T3 Code - AI-powered code editor";
      homepage = "https://github.com/pingdotgg/t3code";
      license = licenses.unfree;
      platforms = ["x86_64-linux"];
    };
  }
