{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  nodejs,
  writeShellScript,
  curl,
  jq,
  common-updater-scripts,
}: let
  pname = "skills";
  version = "1.5.0";

  yamlVersion = "2.8.3";
  yamlSrc = fetchurl {
    url = "https://registry.npmjs.org/yaml/-/yaml-${yamlVersion}.tgz";
    hash = "sha256-lTmAXXRH3vK+1cW0rKzCgzYsXoCrxdk0crLzXwy/ha0=";
  };
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    inherit pname version;

    src = fetchurl {
      url = "https://registry.npmjs.org/skills/-/skills-${version}.tgz";
      hash = "sha256-ju9WPOfQJuQGZb9Wrk4CzN+IpsCkx6p4fupMKocctwE=";
    };

    sourceRoot = "package";

    nativeBuildInputs = [makeWrapper];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/node_modules/skills
      cp -r . $out/lib/node_modules/skills/

      mkdir -p $out/lib/node_modules/skills/node_modules/yaml
      tar -xzf ${yamlSrc} \
        -C $out/lib/node_modules/skills/node_modules/yaml \
        --strip-components=1

      mkdir -p $out/bin
      makeWrapper ${nodejs}/bin/node $out/bin/skills \
        --add-flags $out/lib/node_modules/skills/bin/cli.mjs
      makeWrapper ${nodejs}/bin/node $out/bin/add-skill \
        --add-flags $out/lib/node_modules/skills/bin/cli.mjs

      runHook postInstall
    '';

    # Query npm for the latest version and rewrite version + src hash in this
    # file. Invoked by `nix-update skills` (nix-update honours
    # passthru.updateScript). Does not touch the pinned yaml dep — bump that
    # manually if skills changes its dependency range.
    passthru.updateScript = writeShellScript "update-skills" ''
      set -euo pipefail
      latest=$(${curl}/bin/curl -fsSL https://registry.npmjs.org/skills/latest | ${jq}/bin/jq -r .version)
      if [ "$latest" = "${finalAttrs.version}" ]; then
        echo "skills is already at $latest"
        exit 0
      fi
      echo "Bumping skills ${finalAttrs.version} -> $latest"
      ${common-updater-scripts}/bin/update-source-version skills "$latest"
    '';

    meta = with lib; {
      description = "Package manager for the open agent skills ecosystem";
      homepage = "https://github.com/vercel-labs/skills";
      license = licenses.mit;
      mainProgram = "skills";
      platforms = platforms.unix;
    };
  })
