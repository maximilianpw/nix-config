{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs_26,
}: let
  pname = "bird";
  version = "0.8.0";

  buildNpmPackageWithNode26 = buildNpmPackage.override {
    nodejs = nodejs_26;
  };
in
  buildNpmPackageWithNode26 {
    inherit pname version;

    src = fetchurl {
      url = "https://registry.npmjs.org/@steipete/bird/-/bird-${version}.tgz";
      hash = "sha256-L4MyudLgcS10j46gCkkexUSSTTJqYYsA5j9Dnd6kRL0=";
    };

    npmDepsHash = "sha256-b3whJhQ0V51gC9cejnrnIKW37pTg4Hkmmpb+WQxYsPE=";

    postPatch = ''
      cp ${./bird-package.json} package.json
      cp ${./bird-package-lock.json} package-lock.json
    '';

    dontNpmBuild = true;
    npmInstallFlags = ["--omit=dev" "--ignore-scripts"];
    npmPackFlags = ["--ignore-scripts"];

    meta = with lib; {
      description = "Fast X CLI for tweeting, replying, and reading through browser-cookie auth";
      homepage = "https://github.com/steipete/bird";
      license = licenses.mit;
      mainProgram = "bird";
      platforms = platforms.unix;
    };
  }
