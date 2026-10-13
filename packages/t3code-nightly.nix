# Temporary nightly pin on llm-agents' build recipe, not a second package recipe.
# Remove this override when llm-agents provides a matching nightly output.
{
  lib,
  fetchFromGitHub,
  rustPlatform,
  llm,
}: let
  version = "0.0.46-nightly.20261011.2994";
  appName = "T3 Code (Nightly)";
  upstream = llm.t3code.unwrapped;
  src = fetchFromGitHub {
    owner = "pingdotgg";
    repo = "t3code";
    tag = "v${version}";
    hash = "sha256-pmPFSlF2hIPdqsqgzbFiv3ylrKoSumznFMKBX7obvOg=";
  };
  pnpmDeps = upstream.pnpmDeps.override {
    inherit src version;
    hash = "sha256-reXWayWahyOJKTDp6GyOq9n5TsS4BpAMclWycpIxygo=";
  };
  resourceMonitor = upstream.resourceMonitor.overrideAttrs (_: {
    inherit src version;
    sourceRoot = "${src.name}/native/resource-monitor";
    cargoDeps = rustPlatform.fetchCargoVendor {
      inherit src;
      sourceRoot = "${src.name}/native/resource-monitor";
      hash = "sha256-5cmG2daM1bVOA23gjjoalbx0fEL1hmqV6WZov0sUZp8=";
    };
  });
  unwrapped = upstream.overrideAttrs (old:
    assert lib.assertMsg (lib.hasInfix "update-release-package-versions.ts ${upstream.version}" old.preBuild && lib.replaceStrings [(toString upstream.resourceMonitor)] [""] old.installPhase != old.installPhase && (!upstream.stdenv.hostPlatform.isDarwin || lib.hasInfix upstream.appName old.installPhase))
    "T3 Code nightly override: upstream build hooks changed; review version, monitor, and branding substitutions"; {
      inherit src version pnpmDeps;
      # These values are interpolated in upstream's let, outside overrideAttrs.
      preBuild = lib.replaceStrings [upstream.version] [version] old.preBuild;
      installPhase =
        lib.replaceStrings
        [(toString upstream.resourceMonitor) upstream.appName]
        [(toString resourceMonitor) appName]
        old.installPhase;
      postInstall =
        old.postInstall
        + ''
          substituteInPlace "$desktop/share/applications/t3code.desktop" \
            --replace-fail '${upstream.appName}' '${appName}'
        '';
      passthru = old.passthru // {inherit appName resourceMonitor;};
      meta =
        old.meta
        // {
          changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
        };
    });
  t3code = llm.t3code.override {t3code-unwrapped = unwrapped;};
in {
  inherit t3code;
  t3code-desktop = llm.t3code-desktop.override {inherit t3code;};
}
