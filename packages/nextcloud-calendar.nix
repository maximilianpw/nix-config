# Bump with `make update-nextcloud-apps`.
{
  lib,
  stdenvNoCC,
  fetchurl,
}: let
  pname = "nextcloud-app-calendar";
  version = "6.5.4";
in
  stdenvNoCC.mkDerivation {
    inherit pname version;

    src = fetchurl {
      url = "https://github.com/nextcloud-releases/calendar/releases/download/v${version}/calendar-v${version}.tar.gz";
      hash = "sha256-Z8d3puqXRAnp0ijCP8YPK+jmddN2UxtrGxJfLwNlc40=";
    };

    dontConfigure = true;
    dontBuild = true;

    preInstall = ''
      test -f appinfo/info.xml
    '';

    installPhase = ''
      runHook preInstall
      cp -R . "$out"
      runHook postInstall
    '';

    meta = {
      description = "Calendar app for Nextcloud";
      homepage = "https://github.com/nextcloud/calendar";
      license = lib.licenses.agpl3Plus;
      platforms = lib.platforms.all;
    };
  }
