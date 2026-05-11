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
  version = "0.11.1";

  hostPackages = {
    aarch64-darwin = {
      packageName = "hunkdiff-darwin-arm64";
      hash = "sha512-0uTuJeB7ZrT999WMcvUU1YvvIgoHIrU5orObKvXc5/Ach+tZWwt85cKD3Sy8sk0QLd/KoGEgRODSKFl5Tjx4+A==";
    };
    x86_64-darwin = {
      packageName = "hunkdiff-darwin-x64";
      hash = "sha512-vmk97ifp08kVUvuAXluMFT+o3bKDI/H4HVPnEvRe+XINEN2QKJrw8GWQXL2axjy3hPpNKZsstuuAJM+UEfIiIg==";
    };
    aarch64-linux = {
      packageName = "hunkdiff-linux-arm64";
      hash = "sha512-g+3hs/ffKRL+TVTck1AVKhC3ym0UxMh6yVEXyg/FPnwDOOKgaPMMRpN7HLI6qzgdL7lZBcmXFw/bI6XrP2a93A==";
    };
    x86_64-linux = {
      packageName = "hunkdiff-linux-x64";
      hash = "sha512-2a0bDS0IbjoLc6zzdK2A/0O73Uhze8/kzXcJyu59meBXnk3hJGZxKuwoFW4v/g0hOnnmvR6OPhmiLEMGV/Jy+Q==";
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
      hash = "sha256-251t629e3cqLL89PzYqh4vJhoGhsAaAnkKv7Q4IqKfc=";
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
