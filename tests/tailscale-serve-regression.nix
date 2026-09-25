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
    config = {
      services.tailscale.package = pkgs.tailscale;
    };
    inherit lib;
    pkgs = testPkgs;
  };
  applyScript = builtins.unsafeDiscardStringContext module.config.systemd.services.tailscale-serve.serviceConfig.ExecStart;
  expectedCommand = service:
    builtins.unsafeDiscardStringContext
    "${tailscale} serve --yes --bg --service=${service.tailscaleServiceName} --https=443 ${lib.escapeShellArg (homelab.loopbackUrl service.port)}";
  expectedAdvertiseCommand = service:
    builtins.unsafeDiscardStringContext
    "${tailscale} serve advertise ${lib.escapeShellArg service.tailscaleServiceName}";
  hasExpectedCommands = lib.all (
    service: lib.hasInfix (expectedCommand service) applyScript
  ) (builtins.attrValues homelab.privateServices);
  reconcilesNamedServices =
    lib.hasInfix "serve status --json" applyScript
    && lib.hasInfix "serve clear \"$service\"" applyScript;
  drainCommand = builtins.unsafeDiscardStringContext "${tailscale} serve drain \"$service\" || return 1";
  scriptAfterDrain =
    if lib.hasInfix drainCommand applyScript
    then builtins.elemAt (lib.splitString drainCommand applyScript) 1
    else "";
  drainsBeforeMutation =
    lib.hasInfix drainCommand applyScript
    && lib.hasInfix "serve clear \"$service\"" scriptAfterDrain
    && lib.all (
      service: lib.hasInfix (expectedCommand service) scriptAfterDrain
    ) (builtins.attrValues homelab.privateServices);
  firstAdvertiseCommand = expectedAdvertiseCommand (builtins.head (builtins.attrValues homelab.privateServices));
  scriptBeforeReadvertise = builtins.head (lib.splitString firstAdvertiseCommand applyScript);
  readvertisesAfterMutation =
    lib.all (
      service: lib.hasInfix (expectedCommand service) scriptBeforeReadvertise
    ) (builtins.attrValues homelab.privateServices)
    && lib.all (
      service: lib.hasInfix (expectedAdvertiseCommand service) scriptAfterDrain
    ) (builtins.attrValues homelab.privateServices);
  validatesTailnetDomain =
    lib.hasInfix "expected_domain=${lib.escapeShellArg homelab.tailnetDomain}" applyScript
    && lib.hasInfix "stale_services=" applyScript
    && lib.hasInfix "expected *.$expected_domain:443" applyScript;
  hasValidAndLayout = !lib.hasInfix "\n &&" applyScript;
in
  assert lib.assertMsg (homelab.privateServices.forgejo.tailscaleServiceName == "svc:git")
  "Forgejo must use the git Tailscale service name";
  assert lib.assertMsg hasExpectedCommands
  "tailscale-serve must terminate HTTPS on port 443 and proxy to each HTTP loopback backend";
  assert lib.assertMsg (!lib.hasInfix "serve set-config" applyScript)
  "tailscale-serve must not use the non-round-trippable Tailscale Services config-file path";
  assert lib.assertMsg reconcilesNamedServices
  "tailscale-serve must clear stale named services that are absent from the declarative inventory";
  assert lib.assertMsg drainsBeforeMutation
  "tailscale-serve must drain existing service hosts before clearing or re-serving them";
  assert lib.assertMsg readvertisesAfterMutation
  "tailscale-serve must advertise desired service hosts after rebuilding their endpoint configuration";
  assert lib.assertMsg validatesTailnetDomain
  "tailscale-serve must reapply and validate named services after a tailnet domain rename";
  assert lib.assertMsg hasValidAndLayout
  "tailscale-serve commands must keep && on the preceding command line";
    pkgs.runCommand "tailscale-serve-regression" {} ''
      touch "$out"
    ''
