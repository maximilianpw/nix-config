{
  pkgs,
  lib,
  fetchurl,
}: let
  appimage = import ../lib/appimage.nix {inherit pkgs;};
  pname = "t3code";
  version = "0.0.27";

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
    hash = "sha256-ALkm7wSVbDlZR7TWVag3NRbP1kvGJQqmpR1mmZvSCAU=";
  };
in
  appimage.mkDesktopAppImage {
    inherit pname version src;
    iconPath = "usr/share/icons/hicolor/512x512/apps/t3code.png";

    meta = with lib; {
      description = "T3 Code - AI-powered code editor";
      homepage = "https://github.com/pingdotgg/t3code";
      license = licenses.unfree;
      platforms = ["x86_64-linux"];
    };
  }
