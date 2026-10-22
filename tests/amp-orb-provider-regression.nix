{
  lib,
  nixpkgs,
  pkgs,
  package,
}: let
  evaluate = extra:
    (nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ../modules/amp-orb-provider
        {
          nixpkgs.pkgs = pkgs;
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "none";
            fsType = "tmpfs";
          };
          system.stateVersion = "26.05";
          services.amp-orb-provider.package = package;
        }
        extra
      ];
    }).config;
  disabled = evaluate {};
  enabled = evaluate {
    services.amp-orb-provider = {
      enable = true;
      tokenFile = "/run/secrets/orb-fixture-token";
      image = "fixture/orb:pinned";
      cpus = "0.5";
    };
  };
  service = enabled.systemd.services.amp-orb-provider;
  invalidToken = evaluate {
    services.amp-orb-provider = {
      enable = true;
      tokenFile = "/nix/store/not-a-runtime-secret";
    };
  };
in
  assert lib.assertMsg (!(disabled.systemd.services ? amp-orb-provider) && !disabled.virtualisation.docker.enable)
  "Amp orb provider must remain opt-in without enabling Docker implicitly";
  assert lib.assertMsg (enabled.virtualisation.docker.enable && lib.all (entry: entry.assertion) enabled.assertions)
  "Amp orb provider must enable Docker and satisfy its host assertions";
  assert lib.assertMsg (
    service.serviceConfig.LoadCredential
    == ["provider-token:/run/secrets/orb-fixture-token"]
    && service.unitConfig.ConditionPathExists == "/run/secrets/orb-fixture-token"
    && !(service.environment ? AMP_ORB_PROVIDER_TOKEN)
  )
  "Amp orb provider must load its token at runtime, never from the Nix store or unit environment";
  assert lib.assertMsg (lib.any (entry: !entry.assertion && entry.message == "Amp orb provider tokens must not be stored in the Nix store.") invalidToken.assertions)
  "Amp orb provider must reject tokens in the Nix store";
  assert lib.assertMsg (
    service.wantedBy
    == ["multi-user.target"]
    && builtins.elem "docker.service" service.requires
    && service.serviceConfig.Restart == "on-failure"
    && service.environment.ORB_IMAGE == "fixture/orb:pinned"
  )
  "Amp orb provider must run at boot with Docker, restart on failure and support custom images";
  assert lib.assertMsg (
    service.serviceConfig.User
    == "amp-orb-provider"
    && service.serviceConfig.SupplementaryGroups == ["docker"]
    && service.serviceConfig.StateDirectoryMode == "0700"
    && service.serviceConfig.ProtectHome
    && service.serviceConfig.ProtectSystem == "strict"
  )
  "Amp orb provider must use a dedicated, sandboxed service identity";
    pkgs.runCommand "amp-orb-provider-regression" {
      nativeBuildInputs = [pkgs.bash pkgs.python3 pkgs.coreutils pkgs.util-linux];
    } ''
      # Building the service also checks both generated shell applications.
      test -x ${service.serviceConfig.ExecStart}
      cp -r ${../scripts} scripts
      bash scripts/tests/amp-orb-dispatch-test.sh
      touch "$out"
    ''
