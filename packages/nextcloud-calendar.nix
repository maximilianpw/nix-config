# Bump with `make update-nextcloud-apps`.
{
  lib,
  stdenvNoCC,
  fetchurl,
}: let
  pname = "nextcloud-app-calendar";
  version = "6.6.1";
in
  stdenvNoCC.mkDerivation {
    inherit pname version;

    src = fetchurl {
      url = "https://github.com/nextcloud-releases/calendar/releases/download/v${version}/calendar-v${version}.tar.gz";
      hash = "sha256-/WYw3uxWg2h4TFae8Bx9ntisyhq2gzzxKiv/WYSj+ns=";
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
