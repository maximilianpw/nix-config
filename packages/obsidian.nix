# Obsidian from the official release artifacts: the AppImage on Linux and the
# universal DMG on macOS, kept at one version. On macOS the app bundle lands in
# $out/Applications, which Hjem's link-nix-apps agent links into
# ~/Applications/Nix User Apps. Obsidian's own in-app updates go to its
# writable data directory, so the read-only bundle does not block them.
{
  _7zz,
  fetchurl,
  lib,
  makeWrapper,
  pkgs,
  stdenvNoCC,
}: let
  pname = "obsidian";
  version = "1.14.4";
  releases = "https://github.com/obsidianmd/obsidian-releases/releases/download/v${version}";

  meta = with lib; {
    description = "Obsidian - A second brain, for you, forever";
    homepage = "https://obsidian.md";
    license = licenses.unfree;
    platforms = ["x86_64-linux" "aarch64-darwin"];
    sourceProvenance = [sourceTypes.binaryNativeCode];
  };

  linux = let
    appimage = import ../lib/appimage.nix {inherit pkgs;};
  in
    appimage.mkDesktopAppImage {
      inherit pname version meta;
      src = fetchurl {
        url = "${releases}/Obsidian-${version}.AppImage";
        hash = "sha256-Y2Ldvu7rt7vMtI+uAJVyzyKE75L1yRnBMyq6SN5v/qo=";
      };
      iconPath = "obsidian.png";
      extraInstallCommands = appimageContents: ''
        install -m 755 -D ${appimageContents}/obsidian-cli $out/bin/obsidian-cli
        ${pkgs.patchelf}/bin/patchelf \
          --set-interpreter "$(cat ${pkgs.stdenv.cc}/nix-support/dynamic-linker)" \
          $out/bin/obsidian-cli
        ln -s $out/bin/obsidian-cli $out/bin/obs
      '';
    };

  darwin = stdenvNoCC.mkDerivation {
    inherit pname version meta;
    src = fetchurl {
      url = "${releases}/Obsidian-${version}.dmg";
      hash = "sha256-3PgY3SDuXZ3T54Lu4MDExHzCJTg7BRwvya99V3L1n3A=";
    };
    nativeBuildInputs = [_7zz makeWrapper];
    # -snl keeps the DMG's symlinks as symlinks. Without it the framework
    # bundles' Versions/Current links become files and the signature breaks.
    unpackCmd = "7zz x -snl $curSrc";
    # 7-Zip also writes extended attributes out as `file:attribute` files, which
    # the signature seal does not list (and the store cannot hold xattrs).
    postUnpack = ''
      find "$sourceRoot" -name '*:com.apple.*' -delete
    '';
    # Re-signing would invalidate Obsidian's notarized signature.
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/Applications $out/bin
      cp -R Obsidian.app $out/Applications/
      makeWrapper $out/Applications/Obsidian.app/Contents/MacOS/Obsidian $out/bin/obsidian
      makeWrapper $out/Applications/Obsidian.app/Contents/MacOS/obsidian-cli $out/bin/obsidian-cli
      ln -s $out/bin/obsidian-cli $out/bin/obs
      runHook postInstall
    '';
  };
in
  if stdenvNoCC.hostPlatform.isDarwin
  then darwin
  else linux
