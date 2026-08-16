{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}: let
  pname = "plannotator";
  version = "0.27.3";

  sources = {
    x86_64-linux = fetchurl {
      url = "https://github.com/backnotprop/plannotator/releases/download/v${version}/plannotator-linux-x64";
      hash = "sha256-YpXiRnfgMqvsEIzGsCh12y+G0oLf3l181yW1uS6/9ow=";
    };
    aarch64-linux = fetchurl {
      url = "https://github.com/backnotprop/plannotator/releases/download/v${version}/plannotator-linux-arm64";
      hash = "sha256-jJkVjFxWj6lqBojruLBiRpBfvZNnaJ/LZmpqRx+u1KU=";
    };
    aarch64-darwin = fetchurl {
      url = "https://github.com/backnotprop/plannotator/releases/download/v${version}/plannotator-darwin-arm64";
      hash = "sha256-1ZCht4axKZol0iizDVuXMHpztPjzxMyt5Z9AsC+J8V0=";
    };
    x86_64-darwin = fetchurl {
      url = "https://github.com/backnotprop/plannotator/releases/download/v${version}/plannotator-darwin-x64";
      hash = "sha256-kw9Slut12IX0S/8hMj4X+HYnapO58KDCQ/7GXS+0OKo=";
    };
  };

  src = sources.${stdenv.hostPlatform.system} or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");
in
  stdenv.mkDerivation {
    inherit pname version src;

    dontUnpack = true;
    # Bun single-file executables store their application payload in ELF
    # sections that the default strip phase would remove.
    dontStrip = true;
    nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [autoPatchelfHook];

    installPhase = ''
      install -Dm755 "$src" "$out/bin/plannotator"
    '';

    meta = with lib; {
      description = "Visual plan and code review tool for coding agents";
      homepage = "https://github.com/backnotprop/plannotator";
      license = licenses.asl20;
      mainProgram = "plannotator";
      platforms = builtins.attrNames sources;
    };
  }
