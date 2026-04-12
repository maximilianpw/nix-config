{
  pkgs,
  lib,
  fetchurl,
}: let
  pname = "obsidian";
  version = "1.12.7";

  src = fetchurl {
    url = "https://github.com/obsidianmd/obsidian-releases/releases/download/v${version}/Obsidian-${version}.AppImage";
    hash = "sha256-9ti5b+aFqGMsgZzAk6JIrOD2urQQ9EpskpomEbHrsXw=";
  };

  appimageContents = pkgs.appimageTools.extractType2 {
    inherit pname version src;
  };
in
  pkgs.appimageTools.wrapType2 {
    inherit pname version src;

    extraInstallCommands = ''
      # Install desktop file
      install -m 444 -D ${appimageContents}/obsidian.desktop $out/share/applications/obsidian.desktop
      substituteInPlace $out/share/applications/obsidian.desktop \
        --replace-warn 'Exec=AppRun' "Exec=${pname}" \
        --replace-warn 'Icon=obsidian' "Icon=$out/share/pixmaps/obsidian.png"

      # Install icon
      install -m 444 -D ${appimageContents}/obsidian.png $out/share/pixmaps/obsidian.png

      # Install CLI tool (patch ELF interpreter for NixOS)
      install -m 755 -D ${appimageContents}/obsidian-cli $out/bin/obsidian-cli
      ${pkgs.patchelf}/bin/patchelf \
        --set-interpreter "$(cat ${pkgs.stdenv.cc}/nix-support/dynamic-linker)" \
        $out/bin/obsidian-cli
      ln -s $out/bin/obsidian-cli $out/bin/obs
    '';

    meta = with lib; {
      description = "Obsidian - A second brain, for you, forever";
      homepage = "https://obsidian.md";
      license = licenses.unfree;
      platforms = ["x86_64-linux"];
    };
  }
