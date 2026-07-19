{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
}: let
  pname = "cliproxyapi";
  version = "7.2.90";

  src = fetchurl {
    url = "https://github.com/router-for-me/CLIProxyAPI/releases/download/v${version}/CLIProxyAPI_${version}_linux_amd64.tar.gz";
    hash = "sha256-+2N/FHHKPKQiXbPhkN0GE7ikpaIjOsGGCmY1VCYDiGM=";
  };
in
  stdenv.mkDerivation {
    inherit pname version src;

    sourceRoot = ".";
    dontBuild = true;

    nativeBuildInputs = [autoPatchelfHook];

    installPhase = ''
      runHook preInstall

      install -Dm755 cli-proxy-api $out/bin/cli-proxy-api
      ln -s cli-proxy-api $out/bin/cliproxyapi
      install -Dm644 LICENSE $out/share/licenses/${pname}/LICENSE

      runHook postInstall
    '';

    meta = {
      description = "OpenAI, Gemini, Claude, and Codex compatible API proxy for CLI accounts";
      homepage = "https://github.com/router-for-me/CLIProxyAPI";
      license = lib.licenses.mit;
      mainProgram = "cli-proxy-api";
      platforms = ["x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
