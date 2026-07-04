{
  pkgs,
  lib,
  fetchurl,
}: let
  appimage = import ../lib/appimage.nix {inherit pkgs;};
  pname = "obsidian";
  version = "1.12.7";

  src = fetchurl {
    url = "https://github.com/obsidianmd/obsidian-releases/releases/download/v${version}/Obsidian-${version}.AppImage";
    hash = "sha256-9ti5b+aFqGMsgZzAk6JIrOD2urQQ9EpskpomEbHrsXw=";
  };
in
  appimage.mkDesktopAppImage {
    inherit pname version src;
    iconPath = "obsidian.png";
    extraInstallCommands = appimageContents: ''
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
