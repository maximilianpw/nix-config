{
  lib,
  pkgs,
}: let
  mockHerdr = pkgs.writeShellApplication {
    name = "herdr";
    text = ''
      printf '%s\n' "$@" >"$HERDR_ARGS_LOG"
    '';
  };
  mockSsh = pkgs.writeShellApplication {
    name = "ssh";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      control_path=
      operation=
      {
        printf '%s\n' ---
        while [ "$#" -gt 0 ]; do
          case "$1" in
            -S)
              printf '%s\n' -S '<control>'
              shift
              control_path="$1"
              ;;
            -O)
              printf '%s\n' -O
              shift
              operation="$1"
              printf '%s\n' "$1"
              ;;
            *)
              printf '%s\n' "$1"
              ;;
          esac
          shift
        done
      } >>"$SSH_ARGS_LOG"

      if [ "$operation" = exit ]; then
        rm -f "$control_path"
      elif [ -n "$control_path" ]; then
        mkdir -p "$(dirname "$control_path")"
        touch "$control_path"
      fi
    '';
  };
  testPkgs =
    pkgs
    // {
      herdr = mockHerdr;
      openssh = mockSsh;
    };
  fleet = import ../lib/fleet.nix {
    hostname = "joyce";
    homeDirectory = "/Users/max-vev";
    inherit lib;
    pkgs = testPkgs;
  };
in
  pkgs.runCommand "fleet-herdr-regression" {
    nativeBuildInputs = [pkgs.diffutils];
  } ''
    export HERDR_ARGS_LOG="$TMPDIR/herdr-args"
    export SSH_ARGS_LOG="$TMPDIR/ssh-args"

    ${fleet.package}/bin/fleet herdr kim agents
    printf '%s\n' --remote kim --session agents >"$TMPDIR/expected-remote"
    diff -u "$TMPDIR/expected-remote" "$HERDR_ARGS_LOG"

    ${fleet.package}/bin/fleet herdr kim
    printf '%s\n' --remote kim >"$TMPDIR/expected-default"
    diff -u "$TMPDIR/expected-default" "$HERDR_ARGS_LOG"

    ${fleet.package}/bin/fleet herdr joyce local
    printf '%s\n' --session local >"$TMPDIR/expected-local"
    diff -u "$TMPDIR/expected-local" "$HERDR_ARGS_LOG"

    : >"$SSH_ARGS_LOG"
    ${fleet.package}/bin/fleet herdr kim agents --forward 3000 --forward 4000:5000
    printf '%s\n' --remote kim --session agents >"$TMPDIR/expected-forwarded-herdr"
    diff -u "$TMPDIR/expected-forwarded-herdr" "$HERDR_ARGS_LOG"
    printf '%s\n' \
      --- \
      -o ExitOnForwardFailure=yes \
      -o ForwardAgent=no \
      -o ControlMaster=yes \
      -o ControlPersist=no \
      -S '<control>' \
      -f -N \
      -L 127.0.0.1:3000:localhost:3000 \
      -L 127.0.0.1:4000:localhost:5000 \
      fleet-forward-kim \
      --- \
      -S '<control>' \
      -O exit \
      fleet-forward-kim >"$TMPDIR/expected-ssh"
    diff -u "$TMPDIR/expected-ssh" "$SSH_ARGS_LOG"

    rm "$HERDR_ARGS_LOG"
    if ${fleet.package}/bin/fleet herdr kim invalid/session; then
      echo "fleet herdr accepted an unsafe session name" >&2
      exit 1
    fi
    test ! -e "$HERDR_ARGS_LOG"

    if HERDR_ENV=1 ${fleet.package}/bin/fleet herdr kim; then
      echo "fleet herdr allowed a nested Herdr client" >&2
      exit 1
    fi
    test ! -e "$HERDR_ARGS_LOG"

    rm "$SSH_ARGS_LOG"
    if ${fleet.package}/bin/fleet herdr kim --forward 3000:invalid; then
      echo "fleet herdr accepted an invalid forward" >&2
      exit 1
    fi
    test ! -e "$HERDR_ARGS_LOG"
    test ! -e "$SSH_ARGS_LOG"

    if ${fleet.package}/bin/fleet herdr joyce --forward 3000; then
      echo "fleet herdr accepted a local-host forward" >&2
      exit 1
    fi
    test ! -e "$HERDR_ARGS_LOG"
    test ! -e "$SSH_ARGS_LOG"

    touch "$out"
  ''
