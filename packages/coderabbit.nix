{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
}: let
  pname = "coderabbit";
  version = "0.6.0";

  sources = {
    x86_64-linux = fetchurl {
      url = "https://cli.coderabbit.ai/releases/${version}/coderabbit-linux-x64.zip";
      hash = "sha256-OUh3qzUBVwcMZllzK7AcwrXEHsTPtdo47pT3Ue+u9hc=";
    };
    aarch64-darwin = fetchurl {
      url = "https://cli.coderabbit.ai/releases/${version}/coderabbit-darwin-arm64.zip";
      hash = "sha256-hOxkKwZXS2XyENLxsgWcqi/zeNKpzv721jamqw/5Hp4=";
    };
  };

  src = sources.${stdenv.hostPlatform.system} or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");
in
  stdenv.mkDerivation {
    inherit pname version src;

    sourceRoot = ".";
    unpackCmd = "unzip $curSrc -d .";

    nativeBuildInputs = [unzip] ++ lib.optionals stdenv.hostPlatform.isLinux [autoPatchelfHook];

    installPhase = ''
      install -Dm755 coderabbit $out/bin/coderabbit
      ln -s $out/bin/coderabbit $out/bin/cr
    '';

    meta = with lib; {
      description = "AI code review CLI by CodeRabbit";
      homepage = "https://www.coderabbit.ai/cli";
      license = licenses.unfree;
      platforms = builtins.attrNames sources;
    };
  }
