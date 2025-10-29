{
  pkgs,
  lib,
  fetchurl,
}: let
  pname = "helium";
  version = "0.5.8.1";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
    sha256 = "77c9302c453aaa0120a7b9e513075f45ebc1d49adb10a1d17bcf86846a465228";
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
