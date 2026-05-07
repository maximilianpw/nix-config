{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  nodejs,
  writeShellScript,
  curl,
  jq,
  nix,
}: let
  pname = "hunkdiff";
  version = "0.10.0";

  hostPackages = {
    aarch64-darwin = {
      packageName = "hunkdiff-darwin-arm64";
      hash = "sha512-oJALanUcIFp19LQbTTNKEk/RA0QIeeqwXzUciTzBlze1IA5GPe+rq+OLy66fFUA5tiO6qj6sXf1UqK9cL8o0Mw==";
    };
    x86_64-darwin = {
      packageName = "hunkdiff-darwin-x64";
      hash = "sha512-5sVwIN7OQ4x6/K1TfP4n0wUZinL9nPKmbZ/oHJWhMD6FScGuOOYYZQtN+q2j3ahzlu36Iio7OXajuyQZulwU4A==";
    };
    aarch64-linux = {
      packageName = "hunkdiff-linux-arm64";
      hash = "sha512-h3yY1cxEmer3StCppvQ4kZyK10971t6dMO76jMnWNhREWML2H2hCiPrNw5Yjx0tI0AyI1P4D3guNCcvylLmO4A==";
    };
    x86_64-linux = {
      packageName = "hunkdiff-linux-x64";
      hash = "sha512-me3Pl6Tqb46yoZP930iCUdE3pE5lDOtfsWUcCZXqEpsg0WPbW6PjO6tjX7MRnkLFPacPDrqfPZpEHr2bxK0X9A==";
    };
  };

  hostPackage =
    hostPackages.${stdenvNoCC.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenvNoCC.hostPlatform.system}");

  hostSrc = fetchurl {
    url = "https://registry.npmjs.org/${hostPackage.packageName}/-/${hostPackage.packageName}-${version}.tgz";
    inherit (hostPackage) hash;
  };
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    inherit pname version;

    src = fetchurl {
      url = "https://registry.npmjs.org/hunkdiff/-/hunkdiff-${version}.tgz";
      hash = "sha512-GfUYNCzEnZ0OTdg340YRFbW1SvvwgRMyQmn44t2GKoSjYqiXGaDCeOG66fpIzU8WRdbUi2uzdGIVkEsCps8TeA==";
    };

    sourceRoot = "package";

    nativeBuildInputs = [makeWrapper];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/node_modules/hunkdiff
      cp -r . $out/lib/node_modules/hunkdiff/

      mkdir -p $out/lib/node_modules/hunkdiff/node_modules/${hostPackage.packageName}
      tar -xzf ${hostSrc} \
        -C $out/lib/node_modules/hunkdiff/node_modules/${hostPackage.packageName} \
        --strip-components=1
      chmod +x $out/lib/node_modules/hunkdiff/node_modules/${hostPackage.packageName}/bin/*

      mkdir -p $out/bin
      makeWrapper ${nodejs}/bin/node $out/bin/hunk \
        --add-flags $out/lib/node_modules/hunkdiff/bin/hunk.cjs

      runHook postInstall
    '';

    passthru.updateScript = writeShellScript "update-hunkdiff" ''
      set -euo pipefail

      package_file="packages/hunkdiff.nix"
      latest=$(${curl}/bin/curl -fsSL https://registry.npmjs.org/hunkdiff/latest | ${jq}/bin/jq -r .version)

      if [ "$latest" = "${finalAttrs.version}" ]; then
        echo "hunkdiff is already at $latest"
        exit 0
      fi

      npm_hash() {
        package_name="$1"
        ${nix}/bin/nix hash convert --hash-algo sha512 --to sri "$(
          ${curl}/bin/curl -fsSL "https://registry.npmjs.org/$package_name/$latest" \
            | ${jq}/bin/jq -r '.dist.integrity'
        )"
      }

      main_hash="$(npm_hash hunkdiff)"
      darwin_arm64_hash="$(npm_hash hunkdiff-darwin-arm64)"
      darwin_x64_hash="$(npm_hash hunkdiff-darwin-x64)"
      linux_arm64_hash="$(npm_hash hunkdiff-linux-arm64)"
      linux_x64_hash="$(npm_hash hunkdiff-linux-x64)"

      perl -0pi -e '
        s/version = "[^"]+"/version = "'"$latest"'"/;
        s/(packageName = "hunkdiff-darwin-arm64";\n\s+hash = ")[^"]+(")/$1'"$darwin_arm64_hash"'$2/;
        s/(packageName = "hunkdiff-darwin-x64";\n\s+hash = ")[^"]+(")/$1'"$darwin_x64_hash"'$2/;
        s/(packageName = "hunkdiff-linux-arm64";\n\s+hash = ")[^"]+(")/$1'"$linux_arm64_hash"'$2/;
        s/(packageName = "hunkdiff-linux-x64";\n\s+hash = ")[^"]+(")/$1'"$linux_x64_hash"'$2/;
        s/(url = "https:\/\/registry\.npmjs\.org\/hunkdiff\/-\/hunkdiff-\$\{version\}\.tgz";\n\s+hash = ")[^"]+(")/$1'"$main_hash"'$2/;
      ' "$package_file"

      echo "Bumped hunkdiff ${finalAttrs.version} -> $latest"
    '';

    meta = with lib; {
      description = "Review-first terminal diff viewer for agent-authored changesets";
      homepage = "https://github.com/modem-dev/hunk";
      license = licenses.mit;
      mainProgram = "hunk";
      platforms = builtins.attrNames hostPackages;
    };
  })
