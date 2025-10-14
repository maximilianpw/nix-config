{
  pkgs,
  lib,
  fetchurl,
}:
pkgs.appimageTools.wrapType2 {
  pname = "helium";
  version = "0.5.5.2";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/0.5.5.2/helium-0.5.5.2-arm64.AppImage";
    sha256 = "4a55b06c399e16ff552bc162e974b360e11d4f5fda105bae06abafcd7ee028bd";
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
