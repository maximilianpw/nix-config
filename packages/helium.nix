{
  pkgs,
  lib,
  fetchurl,
}:
pkgs.appimageTools.wrapType2 {
  pname = "helium";
  version = "0.5.5.1";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/0.5.5.1/helium-0.5.5.1.AppImage";
    sha256 = "sha256:29f425393e2630a438d01f215a5f8696644d5616671259f9f69b5f5cdd1708b7"; # Will need to update this
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
