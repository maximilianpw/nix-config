{
  lib,
  bash,
  buildNpmPackage,
  fetchurl,
  nodejs_26,
}: let
  pname = "birdclaw";
  version = "0.8.5";

  buildNpmPackageWithNode26 = buildNpmPackage.override {
    nodejs = nodejs_26;
  };
in
  buildNpmPackageWithNode26 {
    inherit pname version;

    src = fetchurl {
      url = "https://registry.npmjs.org/birdclaw/-/birdclaw-${version}.tgz";
      hash = "sha512-9+An43wlzEiIRgf20lGNuE8B8Si6GmWm5b46IvcCWgJdI/ZHL9BrC25KuOc47bycCvgJihGkspoc6qhpmU4JmA==";
    };

    npmDepsHash = "sha256-JfmE5NzB7aqeozymyA6rntXRePKbKIjJbhLK9foeBxQ=";

    postPatch = ''
      cp ${./birdclaw-package-lock.json} package-lock.json
      awk '
        /"devDependencies": \{/ { skip = 1; depth = 1; next }
        skip {
          depth += gsub(/\{/, "{")
          depth -= gsub(/\}/, "}")
          if (depth == 0) { skip = 0 }
          next
        }
        { print }
      ' package.json > package.json.tmp
      mv package.json.tmp package.json

      substituteInPlace dist/cli/birdclaw.js dist/server/assets/router-*.js \
        --replace-fail '"/bin/bash"' '"${bash}/bin/bash"'
    '';

    dontNpmBuild = true;
    npmInstallFlags = ["--omit=dev" "--ignore-scripts"];
    npmPackFlags = ["--ignore-scripts"];

    meta = with lib; {
      description = "Local Twitter memory in SQLite for archives, DMs, likes, bookmarks, and moderation";
      homepage = "https://birdclaw.sh/";
      license = licenses.mit;
      mainProgram = "birdclaw";
      platforms = platforms.unix;
    };
  }
