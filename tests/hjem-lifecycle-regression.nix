# Pins the Hjem linker behavior the Nixvim/Hjem migration relies on, using the
# CLI built from the locked input (scripts/tests/hjem-lifecycle-fixture.sh).
# This covers the linker in a disposable home only; NixOS activation units and
# the nix-darwin launch agent still need host-level verification.
{
  hjem,
  pkgs,
}: let
  hjemCli = pkgs.callPackage "${hjem}/cli/package.nix" {};
in
  pkgs.runCommandLocal "hjem-lifecycle-regression" {
    nativeBuildInputs = [pkgs.bash pkgs.coreutils pkgs.cue pkgs.diffutils pkgs.gnugrep];
    HJEM = "${hjemCli}/bin/hjem";
  } ''
    bash ${../scripts/tests/hjem-lifecycle-fixture.sh}

    # Runtime activation only warns about invalid entries (see "Hjem findings" in
    # docs/nixvim-hjem-ledger.md), so the modules' build-time schema check is the
    # guard that must keep rejecting them.
    printf '{"version":3,"files":[{"type":"symlink","target":"relative"}]}\n' > invalid.json
    export CUE_CACHE_DIR="$PWD/.cache" CUE_CONFIG_DIR="$PWD/.config"
    if cue vet -c ${hjem}/manifest/v3.cue invalid.json 2>/dev/null; then
      echo "Hjem's manifest schema no longer rejects relative targets" >&2
      exit 1
    fi
    touch "$out"
  ''
