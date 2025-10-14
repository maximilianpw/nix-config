{
  pkgs,
  lib,
  fetchurl,
}: let
  pname = "helium";
  version = "0.5.5.2";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
    sha256 = "d9ffef79779432bfdc861d184812c3f3ada7bf946d272e6a95a03b7e1bab5a80";
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

    extraPkgs = pkgs:
      with pkgs; [
        # Add any additional dependencies here if needed
      ];

    meta = with lib; {
      description = "Helium Browser";
      homepage = "https://github.com/imputnet/helium-linux";
      license = licenses.mit;
      platforms = ["x86_64-linux"];
    };
  }
