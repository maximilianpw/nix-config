{
  pkgs,
  lib,
  fetchurl,
}: let
  pname = "t3code";
  version = "0.0.17";

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
    hash = "sha256-uS+o1nRA3R7hn9BaomrdsGVC8UcpPFFRG3a1qGVrs8w=";
  };

  appimageContents = pkgs.appimageTools.extractType2 {
    inherit pname version src;
  };
in
  pkgs.appimageTools.wrapType2 {
    inherit pname version src;

    extraInstallCommands = ''
      install -m 444 -D ${appimageContents}/t3code.desktop $out/share/applications/t3code.desktop
      substituteInPlace $out/share/applications/t3code.desktop \
        --replace-warn 'Exec=AppRun' "Exec=${pname}" \
        --replace-warn 'Icon=t3code' "Icon=$out/share/pixmaps/t3code.png"

      install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/1024x1024/apps/t3code.png $out/share/pixmaps/t3code.png
    '';

    meta = with lib; {
      description = "T3 Code - AI-powered code editor";
      homepage = "https://github.com/pingdotgg/t3code";
      license = licenses.unfree;
      platforms = ["x86_64-linux"];
    };
  }
