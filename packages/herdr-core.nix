{
  fetchurl,
  lib,
  stdenvNoCC,
}: let
  version = "0.1.18";
  artifacts = {
    aarch64-darwin = {
      target = "macos-aarch64";
      hash = "sha256-d9ivCS4lrmUPRCTW2tJ1FPaRahHYB/sHUoWM0nwh5Pw=";
    };
    x86_64-darwin = {
      target = "macos-x86_64";
      hash = "sha256-FaErgOk+xOB029uC+opm5SmFer+9+0VvlNURbcQ4/tw=";
    };
    aarch64-linux = {
      target = "linux-aarch64";
      hash = "sha256-zzM5PPlQu3Y3NNw+FmEKudr4SSORpO8N5WAmzX91KFM=";
    };
    x86_64-linux = {
      target = "linux-x86_64";
      hash = "sha256-Wy+Xy0sqnXprLMWUJiggPtn7t8wMK0sJrYpvVkjiRrc=";
    };
  };
  artifact = artifacts.${stdenvNoCC.hostPlatform.system};
in
  stdenvNoCC.mkDerivation {
    pname = "herdr-core";
    inherit version;
    src = fetchurl {
      url = "https://releases.herdr.dev/core/${version}/herdr-core-${artifact.target}.tar.gz";
      inherit (artifact) hash;
    };

    unpackPhase = ''
      runHook preUnpack
      mkdir source
      tar -xzf "$src" -C source
      cd source
      runHook postUnpack
    '';
    dontBuild = true;
    # Preserve the upstream Mach-O signature; Linux releases are static binaries.
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 herdr-core "$out/bin/herdr-core"
      ln -s herdr-core "$out/bin/hc"
      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      test "$("$out/bin/hc" --version)" = "hc ${version}"
      "$out/bin/herdr-core" --help > /dev/null
      runHook postInstallCheck
    '';

    meta = {
      description = "Persistent terminal and coding-agent runtime for Herdr App";
      homepage = "https://github.com/herdrdev/herdr-core";
      license = lib.licenses.asl20;
      mainProgram = "hc";
      platforms = builtins.attrNames artifacts;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
