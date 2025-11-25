{
  pkgs,
  lib,
  fetchurl,
}: let
  pname = "helium";
  version = "0.6.7.1";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
    sha256 = "7d94c136168393911e61cc590c9f37b7078c66ab4485def0b3c00551c1e314bb";
  };

  appimageContents = pkgs.appimageTools.extractType2 {
    inherit pname version src;
  };
in
  pkgs.appimageTools.wrapType2 {
    inherit pname version src;

    extraInstallCommands = ''
      # Install desktop file with correct Exec path
      install -m 444 -D ${appimageContents}/helium.desktop $out/share/applications/helium.desktop
      substituteInPlace $out/share/applications/helium.desktop \
        --replace 'Exec=AppRun' "Exec=${pname}" \
        --replace 'Icon=helium' "Icon=$out/share/pixmaps/helium.png"

      # Install icon
      install -m 444 -D ${appimageContents}/helium.png $out/share/pixmaps/helium.png
    '';

    meta = with lib; {
      description = "Helium Browser";
      homepage = "https://github.com/imputnet/helium-linux";
      license = licenses.mit;
      platforms = ["x86_64-linux"];
    };
  }
