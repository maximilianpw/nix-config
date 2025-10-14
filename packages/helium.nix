{
  pkgs,
  lib,
  fetchurl,
}:
pkgs.appimageTools.wrapType2 {
  pname = "helium";
  version = "0.5.5.2";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/0.5.5.2/helium-0.5.5.2-x86_64.AppImage";
    sha256 = "d9ffef79779432bfdc861d184812c3f3ada7bf946d272e6a95a03b7e1bab5a80";
  };

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
