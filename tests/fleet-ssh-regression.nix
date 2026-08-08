{
  lib,
  pkgs,
}: let
  mockSsh = pkgs.writeShellApplication {
    name = "ssh";
    text = ''
      printf '%s\n' "$@" >"$SSH_ARGS_LOG"
    '';
  };
  mockTmux = pkgs.writeShellApplication {
    name = "tmux";
    text = ''
      printf '%s\n' "$@" >"$TMUX_ARGS_LOG"
    '';
  };
  testPkgs =
    pkgs
    // {
      openssh = mockSsh;
      tmux = mockTmux;
    };
  fleet = import ../lib/fleet.nix {
    hostname = "joyce";
    homeDirectory = "/Users/max-vev";
    inherit lib;
    pkgs = testPkgs;
  };
in
  pkgs.runCommand "fleet-ssh-regression" {
    nativeBuildInputs = [pkgs.diffutils];
  } ''
    export FLEET_BIN=${fleet.package}/bin/fleet
    ${builtins.readFile ../scripts/tests/fleet-ssh-regression-test.sh}
  ''
