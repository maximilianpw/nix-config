{
  lib,
  pkgs,
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  tailscale = lib.getExe pkgs.tailscale;
  testPkgs =
    pkgs
    // {
      writeShellScript = _: text: text;
      writeText = _: text: text;
    };
  module = import ../homelab/tailscale-serve.nix {
    config.services.tailscale = {
      enable = true;
      package = pkgs.tailscale;
    };
    inherit lib;
    pkgs = testPkgs;
  };
  applyScript = builtins.unsafeDiscardStringContext module.config.systemd.services.tailscale-serve.serviceConfig.ExecStart;
  expectedCommand = name: service:
    builtins.unsafeDiscardStringContext
    "${tailscale} serve --yes --bg --service=svc:${name} --https=443 ${lib.escapeShellArg (homelab.loopbackUrl service.port)}";
  hasExpectedCommands = lib.all (
    name: lib.hasInfix (expectedCommand name homelab.privateServices.${name}) applyScript
  ) (builtins.attrNames homelab.privateServices);
  hasValidAndLayout = !lib.hasInfix "\n &&" applyScript;
in
  assert lib.assertMsg hasExpectedCommands
  "tailscale-serve must terminate HTTPS on port 443 and proxy to each HTTP loopback backend";
  assert lib.assertMsg (!lib.hasInfix "serve set-config" applyScript)
  "tailscale-serve must not use the non-round-trippable Tailscale Services config-file path";
  assert lib.assertMsg hasValidAndLayout
  "tailscale-serve commands must keep && on the preceding command line";
    pkgs.runCommand "tailscale-serve-regression" {} ''
      touch "$out"
    ''
