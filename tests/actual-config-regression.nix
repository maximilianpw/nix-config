{
  config,
  lib,
  pkgs,
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  endpoint = (homelab.endpoints config.homelab.tailnet.domain).actual;
  actual = config.services.actual;
in
  assert lib.assertMsg actual.enable
  "Actual Budget must be enabled";
  assert lib.assertMsg (!actual.openFirewall)
  "Actual Budget must not open a host firewall port";
  assert lib.assertMsg (
    actual.settings.hostname
    == "127.0.0.1"
    && actual.settings.port == endpoint.port
  )
  "Actual Budget must bind only its declared loopback endpoint";
  assert lib.assertMsg (
    actual.settings.loginMethod
    == "password"
    && actual.settings.allowedLoginMethods == ["password"]
  )
  "Actual Budget must only accept its password authentication method";
  assert lib.assertMsg (
    builtins.elem "actual.service" homelab.backup.archiveUnits
    && builtins.elem "/var/lib/actual" config.custom.backup.manifestMetadata.expectedPrimaryStatePaths
    && builtins.elem "/var/lib/actual" config.custom.backup.manifestMetadata.expectedArchivePaths
    && config.custom.backup.manifestMetadata.applicationVersions.actual == actual.package.version
  )
  "Actual Budget state must be quiesced, archived, and tied to its package version";
    pkgs.runCommand "actual-config-regression" {} ''
      touch "$out"
    ''
