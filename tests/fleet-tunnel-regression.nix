{
  lib,
  pkgs,
}: let
  defaultTunnels = import ../modules/fleet/default-tunnels.nix;
  joyceTunnels = defaultTunnels.joyce or [];
  mockSsh = pkgs.writeShellApplication {
    name = "ssh";
    text = ''
      if [[ -n ''${FLEET_SSH_PID_LOG:-} ]]; then
        printf '%s\n' "$$" >"$FLEET_SSH_PID_LOG"
      fi
      if [[ -n ''${SSH_ARGS_LOG:-} ]]; then
        printf '%s\n' "$@" >"$SSH_ARGS_LOG"
      fi
      if [[ -n ''${SSH_ARGS_ALL:-} ]]; then
        printf '%s\n' "$@" >>"$SSH_ARGS_ALL"
        printf '\n' >>"$SSH_ARGS_ALL"
      fi
      if [[ ''${FLEET_SSH_CONSUME_STDIN:-no} == yes ]]; then
        null_stdin=no
        for arg in "$@"; do
          if [[ "$arg" == -n ]]; then null_stdin=yes; fi
        done
        if [[ "$null_stdin" == no ]]; then cat >/dev/null; fi
      fi
      case "''${FLEET_SSH_STATUS:-ok}" in
        fish-syntax)
          exec fish --no-config --no-execute -c "''${!#}"
          ;;
        hang)
          exec sleep 30
          ;;
        slow-success)
          sleep 3
          exit 0
          ;;
        unavailable)
          echo "ssh: connect to host kim port 22: Connection refused" >&2
          exit 255
          ;;
        auth)
          echo "kim: Permission denied (publickey)." >&2
          exit 255
          ;;
      esac
      for arg in "$@"; do
        case "$arg" in
          *"/dev/tcp/"*)
            case "''${FLEET_REMOTE_LISTEN:-up}" in
              down) exit 1 ;;
              ssh-failed) exit 255 ;;
              hang) exec sleep 30 ;;
            esac
            exit 0
            ;;
        esac
      done
      exit 0
    '';
  };
  mockLsof = pkgs.writeShellApplication {
    name = "lsof";
    text = ''
      for arg in "$@"; do
        if [[ "$arg" == -p && ''${FLEET_STARTUP_LISTEN:-no} == yes ]]; then
          exit 0
        fi
        case "$arg" in
          -iTCP:*)
            file="''${FLEET_LISTENER_PIDS:?}/''${arg#-iTCP:}"
            if [[ -f "$file" ]]; then
              cat "$file"
              exit 0
            fi
            ;;
        esac
      done
      exit 1
    '';
  };
  mockTmux = pkgs.writeShellApplication {
    name = "tmux";
    text = ''
      printf '%s\n' "$@" >"''${TMUX_ARGS_LOG:-/dev/null}"
    '';
  };
  testPkgs =
    pkgs
    // {
      openssh = mockSsh;
      tmux = mockTmux;
      lsof = mockLsof;
    };
  joyce = import ../lib/fleet.nix {
    hostname = "joyce";
    homeDirectory = "/Users/max-vev";
    inherit lib;
    pkgs = testPkgs;
    tunnels = joyceTunnels;
  };
  kim = import ../lib/fleet.nix {
    hostname = "kim";
    homeDirectory = "/home/maxpw";
    inherit lib;
    pkgs = testPkgs;
  };
  agent3000 = joyce.launchdAgents."fleet-tunnel-3000";
  agent5173 = joyce.launchdAgents."fleet-tunnel-5173";
  args3000 = agent3000.config.ProgramArguments;
  args5173 = agent5173.config.ProgramArguments;
  hasArg = args: needle: lib.elem needle args;
  hasNoInfix = args: needle: !(lib.any (arg: lib.hasInfix needle arg) args);
  expectedJoyceTunnels = [
    {
      host = "kim";
      localPort = 3000;
      remotePort = 3000;
    }
    {
      host = "kim";
      localPort = 5173;
      remotePort = 5173;
    }
  ];
in
  assert lib.assertMsg (joyceTunnels == expectedJoyceTunnels)
  "Joyce must declare local 3000 and 5173 localhost forwards to Kim";
  assert lib.assertMsg (defaultTunnels.kim or [] == [])
  "Kim must not declare managed localhost tunnels";
  assert lib.assertMsg (builtins.attrNames joyce.launchdAgents == ["fleet-tunnel-3000" "fleet-tunnel-5173"])
  "Joyce must supervise one launchd job per local tunnel port";
  assert lib.assertMsg (kim.launchdAgents == {})
  "Kim must not install managed tunnel launchd jobs";
  assert lib.assertMsg (
    agent3000.enable
    && agent3000.config.RunAtLoad == true
    && agent3000.config.KeepAlive == true
    && agent3000.config.ThrottleInterval == 30
    && agent3000.config.ProcessType == "Background"
    && agent3000.config.Label == "org.nix-community.home.fleet-tunnel-3000"
    && !(agent3000.config ? StandardOutPath)
    && !(agent3000.config ? StandardErrorPath)
  )
  "Joyce tunnel jobs must start at login, retry with a throttle, and avoid unbounded log files";
  assert lib.assertMsg (
    hasArg args3000 "-N"
    && hasArg args3000 "BatchMode=yes"
    && hasArg args3000 "ConnectTimeout=10"
    && hasArg args3000 "ExitOnForwardFailure=yes"
    && hasArg args3000 "ForwardAgent=no"
    && hasArg args3000 "ControlMaster=no"
    && hasArg args3000 "ControlPath=none"
    && hasArg args3000 "ServerAliveInterval=30"
    && hasArg args3000 "ServerAliveCountMax=3"
    && hasArg args3000 "127.0.0.1:3000:localhost:3000"
    && hasArg args3000 "fleet-forward-kim"
    && hasArg args5173 "127.0.0.1:5173:localhost:5173"
    && hasArg args5173 "fleet-forward-kim"
    && hasNoInfix args3000 "0.0.0.0"
    && hasNoInfix args5173 "0.0.0.0"
    && hasNoInfix args3000 "*:"
    && lib.hasSuffix "/bin/fleet-tunnel-runner" (builtins.head args3000)
    && builtins.elemAt args3000 1 == "3000"
  )
  "Managed tunnels must bind IPv4 loopback, use fleet-forward aliases, and disable multiplexing/agent forwarding";
  assert lib.assertMsg (lib.all (block: block.ForwardAgent == "no") (builtins.attrValues joyce.sshSettings))
  "Managed tunnels must inherit Fleet's no-agent-forwarding SSH blocks";
  assert lib.assertMsg (lib.all (block: !(block ? LocalForward)) (builtins.attrValues joyce.sshSettings))
  "Managed tunnels must not add LocalForward to ordinary SSH blocks";
  assert lib.assertMsg (lib.any (name: lib.hasInfix "fleet-forward-kim" name) (builtins.attrNames joyce.sshSettings))
  "Managed tunnels require the generated fleet-forward-kim SSH alias";
    pkgs.runCommand "fleet-tunnel-regression" {
      nativeBuildInputs = [pkgs.diffutils pkgs.gnugrep pkgs.fish];
    } ''
      export FLEET_BIN=${joyce.package}/bin/fleet
      export FLEET_KIM_BIN=${kim.package}/bin/fleet
      export FLEET_TUNNEL_RUNNER=${joyce.tunnelRunner}/bin/fleet-tunnel-runner
      ${builtins.readFile ../scripts/tests/fleet-tunnel-regression-test.sh}
    ''
