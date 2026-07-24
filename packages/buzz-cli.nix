{
  fetchFromGitHub,
  lib,
  rustPlatform,
  stdenv,
}: let
  version = "0.4.23";
  rev = "acfbb1bb6af54cb29cb152496ff43b8285dcb8cf";
in
  rustPlatform.buildRustPackage {
    pname = "buzz-cli";
    inherit version;

    src = fetchFromGitHub {
      owner = "block";
      repo = "buzz";
      inherit rev;
      hash = "sha256-gxjoDvfKj0UhHZfOVSO0UZBx31oZJVXThgYGPRtjiPU=";
    };

    cargoHash = "sha256-WXnmAsFo5m9mZGy7gLk6egTN94X7WMSsBfhslzaloH4=";
    cargoBuildFlags = ["-p" "buzz-cli"];
    doCheck = false;

    installPhase = ''
      runHook preInstall

      releaseDir=target/${stdenv.hostPlatform.rust.rustcTarget}/release
      install -Dm755 "$releaseDir/buzz" $out/bin/buzz

      runHook postInstall
    '';

    meta = {
      description = "Command-line client for Buzz";
      homepage = "https://github.com/block/buzz";
      license = lib.licenses.asl20;
      mainProgram = "buzz";
      platforms = lib.platforms.linux;
    };
  }
