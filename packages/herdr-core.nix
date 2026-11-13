{
  fetchurl,
  lib,
  stdenvNoCC,
}: let
  version = "0.1.21";
  artifacts = {
    aarch64-darwin = {
      target = "macos-aarch64";
      hash = "sha256-GrON2ScPY6j3lNbWDocC6w0chacr2oXXNeXupD8F/+0=";
    };
    x86_64-darwin = {
      target = "macos-x86_64";
      hash = "sha256-43fh00LN3OA0baWy88KBuXAeRzHAACTHxQKCZed6IX8=";
    };
    aarch64-linux = {
      target = "linux-aarch64";
      hash = "sha256-6ESiv6tIoiYJdnnQdryDBC/lf8zvU4fvgC5bJOeLUpo=";
    };
    x86_64-linux = {
      target = "linux-x86_64";
      hash = "sha256-eEJHVcEKQN3jigvbVcIKwZcG6a4F7Wj8Ks8fz/DZQcE=";
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
