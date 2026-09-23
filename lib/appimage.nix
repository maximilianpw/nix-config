{pkgs}: {
  mkDesktopAppImage = {
    pname,
    version,
    src,
    iconPath,
    extraInstallCommands ? (_: ""),
    meta ? {},
  }: let
    appimageContents = pkgs.appimageTools.extractType2 {
      inherit pname version src;
    };
  in
    pkgs.appimageTools.wrapType2 {
      inherit pname version src meta;

      extraInstallCommands = ''
        install -m 444 -D ${appimageContents}/${pname}.desktop $out/share/applications/${pname}.desktop
        substituteInPlace $out/share/applications/${pname}.desktop \
          --replace-warn 'Exec=AppRun' "Exec=${pname}" \
          --replace-warn 'Icon=${pname}' "Icon=$out/share/pixmaps/${pname}.png"

        install -m 444 -D ${appimageContents}/${iconPath} $out/share/pixmaps/${pname}.png
        ${extraInstallCommands appimageContents}
      '';
    };
}
