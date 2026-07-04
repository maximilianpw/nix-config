{pkgs}: {
  mkDesktopAppImage = {
    pname,
    version,
    src,
    desktopPath ? "${pname}.desktop",
    desktopFileName ? "${pname}.desktop",
    desktopExec ? "AppRun",
    iconName ? pname,
    iconPath,
    pixmapName ? "${pname}.png",
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
        install -m 444 -D ${appimageContents}/${desktopPath} $out/share/applications/${desktopFileName}
        substituteInPlace $out/share/applications/${desktopFileName} \
          --replace-warn 'Exec=${desktopExec}' "Exec=${pname}" \
          --replace-warn 'Icon=${iconName}' "Icon=$out/share/pixmaps/${pixmapName}"

        install -m 444 -D ${appimageContents}/${iconPath} $out/share/pixmaps/${pixmapName}
        ${extraInstallCommands appimageContents}
      '';
    };
}
