{
  lib,
  buildGoModule,
  fetchFromGitHub,
}: let
  pname = "xurl";
  version = "1.1.1";
  commit = "ca7af700a3d8888e63bb819f6f118e2aec42c2db";
in
  buildGoModule {
    inherit pname version;

    src = fetchFromGitHub {
      owner = "xdevplatform";
      repo = "xurl";
      rev = "v${version}";
      hash = "sha256-sL1CIXM3tD9pL8hig+UhBAK7G+4JVOFevHdIyS3DhCU=";
    };

    vendorHash = "sha256-sYGm/Yrcu+i+EsjcJfZcCrp3tvWLxo8cte5YnC0fEbI=";

    postPatch = ''
      substituteInPlace api/client_test.go \
        --replace-fail 'xurl/dev' 'xurl/${version}'
    '';

    env.CGO_ENABLED = 0;

    ldflags = [
      "-s"
      "-w"
      "-X github.com/xdevplatform/xurl/version.Version=${version}"
      "-X github.com/xdevplatform/xurl/version.Commit=${commit}"
      "-X github.com/xdevplatform/xurl/version.BuildDate=1970-01-01T00:00:00Z"
    ];

    meta = with lib; {
      description = "Auth-enabled curl-like CLI for the X API";
      homepage = "https://github.com/xdevplatform/xurl";
      license = licenses.mit;
      mainProgram = "xurl";
      platforms = platforms.unix;
    };
  }
