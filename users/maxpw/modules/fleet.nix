{
  config,
  lib,
  pkgs,
  hostname,
  ...
}: let
  inherit (lib) concatStringsSep escapeShellArg filterAttrs mapAttrs' mapAttrsToList nameValuePair;

  fleetHosts = {
    main-pc = {
      hostName = "main-pc";
      user = "maxpw";
      aliases = ["main" "desktop"];
      tmuxSession = "main";
      tmuxCommand = "/run/current-system/sw/bin/tmux";
      role = "nixos-desktop";
      t3codePort = 51000;
    };

    macbook-pro-m1 = {
      hostName = "macbook-pro-m1";
      user = "max-vev";
      aliases = ["mac" "mbp"];
      tmuxSession = "main";
      tmuxCommand = "/etc/profiles/per-user/max-vev/bin/tmux";
      role = "darwin-brain";
    };
  };

  remoteHosts = filterAttrs (name: _: name != hostname) fleetHosts;
  localHost = fleetHosts.${hostname} or null;
  localHostNames =
    if localHost == null
    then []
    else [hostname] ++ (localHost.aliases or []);
  localHostPattern = concatStringsSep "|" localHostNames;

  hostPatterns = name: host: concatStringsSep " " ([name] ++ (host.aliases or []));
  tmuxHostPatterns = name: host: concatStringsSep " " (map (alias: "tm-${alias}") ([name] ++ (host.aliases or [])));
  caseHostPatterns = name: host: concatStringsSep "|" ([name] ++ (host.aliases or []));

  baseSshOptions = {
    AddKeysToAgent = "yes";
    Compression = "yes";
    ControlMaster = "auto";
    ControlPath = "${config.home.homeDirectory}/.ssh/control-%C";
    ControlPersist = "10m";
    ForwardAgent = "yes";
    ServerAliveCountMax = "3";
    ServerAliveInterval = "30";
    StrictHostKeyChecking = "accept-new";
  };

  mkPlainBlock = name: host:
    nameValuePair (hostPatterns name host) {
      hostname = host.hostName;
      user = host.user;
      port = host.port or 22;
      extraOptions = baseSshOptions;
    };

  mkTmuxBlock = name: host:
    nameValuePair (tmuxHostPatterns name host) (let
      session = host.tmuxSession or "main";
      tmuxCommand = host.tmuxCommand or "tmux";
    in {
      hostname = host.hostName;
      user = host.user;
      port = host.port or 22;
      extraOptions =
        baseSshOptions
        // {
          RequestTTY = "yes";
          RemoteCommand = "${tmuxCommand} new-session -A -s ${session}";
        };
    });

  remoteTmuxRows =
    mapAttrsToList (
      name: host: let
        tmuxCommand = host.tmuxCommand or "tmux";
      in ''
        ${caseHostPatterns name host}) printf '%s\n' ${escapeShellArg tmuxCommand} ;;
      ''
    )
    fleetHosts;

  hostRows =
    mapAttrsToList (
      name: host: let
        aliases = concatStringsSep "," (host.aliases or []);
        role = host.role or "";
      in ''
        printf '%-18s %-12s %-24s %-16s %s\n' ${escapeShellArg name} ${escapeShellArg host.user} ${escapeShellArg host.hostName} ${escapeShellArg role} ${escapeShellArg aliases}
      ''
    )
    fleetHosts;

  fleet = pkgs.writeShellApplication {
    name = "fleet";
    runtimeInputs = [
      pkgs.openssh
      pkgs.tmux
    ];
    text = ''
      set -eu

      is_local_host() {
        ${
        if localHostNames == []
        then ''
          return 1
        ''
        else ''
          case "$1" in
            ${localHostPattern}) return 0 ;;
            *) return 1 ;;
          esac
        ''
      }
      }

      validate_session() {
        case "$1" in
          *[!A-Za-z0-9_.-]*)
            echo "fleet: session names may only contain A-Z, a-z, 0-9, _, ., and -" >&2
            exit 2
            ;;
        esac
      }

      remote_tmux_command() {
        case "$1" in
          ${concatStringsSep "\n        " remoteTmuxRows}
          *) printf '%s\n' tmux ;;
        esac
      }

      usage() {
        printf '%s\n' \
          'usage:' \
          '  fleet list' \
          '  fleet ssh HOST [SESSION]' \
          '  fleet shell HOST' \
          '  fleet run HOST COMMAND...' \
          '  fleet forward HOST LOCAL_PORT REMOTE_PORT [REMOTE_HOST]' \
          '  fleet t3 HOST [LOCAL_PORT]' \
          "" \
          'examples:' \
          '  fleet ssh main-pc' \
          '  fleet run main-pc btop' \
          '  fleet forward main-pc 3000 3000' \
          '  fleet t3 main-pc 51001'
      }

      cmd="''${1:-list}"

      case "$cmd" in
        list)
          printf '%-18s %-12s %-24s %-16s %s\n' HOST USER TARGET ROLE ALIASES
          ${concatStringsSep "\n        " hostRows}
          ;;
        ssh)
          if [ "$#" -lt 2 ]; then
            usage >&2
            exit 2
          fi
          host="$2"
          session="''${3:-}"
          if [ -n "$session" ]; then
            validate_session "$session"
          fi
          if is_local_host "$host"; then
            session="''${session:-main}"
            validate_session "$session"
            exec tmux new-session -A -s "$session"
          fi
          if [ -n "$session" ]; then
            tmux_command="$(remote_tmux_command "$host")"
            exec ssh -t "$host" "$tmux_command new-session -A -s $session"
          fi
          exec ssh "tm-$host"
          ;;
        shell)
          if [ "$#" -lt 2 ]; then
            usage >&2
            exit 2
          fi
          shift
          if is_local_host "$1"; then
            exec "''${SHELL:-/bin/sh}"
          fi
          exec ssh "$@"
          ;;
        run)
          if [ "$#" -lt 3 ]; then
            usage >&2
            exit 2
          fi
          host="$2"
          shift 2
          if is_local_host "$host"; then
            exec "$@"
          fi
          exec ssh "$host" "$@"
          ;;
        forward)
          if [ "$#" -lt 4 ]; then
            usage >&2
            exit 2
          fi
          host="$2"
          local_port="$3"
          remote_port="$4"
          remote_host="''${5:-127.0.0.1}"
          exec ssh -N -L "127.0.0.1:$local_port:$remote_host:$remote_port" "$host"
          ;;
        t3)
          if [ "$#" -lt 2 ]; then
            usage >&2
            exit 2
          fi
          host="$2"
          local_port="''${3:-51000}"
          exec ssh -N -L "127.0.0.1:$local_port:127.0.0.1:51000" "$host"
          ;;
        -h|--help|help)
          usage
          ;;
        *)
          echo "fleet: unknown command: $cmd" >&2
          usage >&2
          exit 2
          ;;
      esac
    '';
  };

  fleetAliases = {
    fl = "fleet list";
    fs = "fleet ssh";
    fsh = "fleet shell";
    fr = "fleet run";
  };
in {
  home.packages = [fleet];

  home.file.".config/fleet/hosts.json".text = builtins.toJSON fleetHosts;

  programs.ssh.matchBlocks =
    (mapAttrs' mkPlainBlock remoteHosts)
    // (mapAttrs' mkTmuxBlock remoteHosts);

  programs.bash.shellAliases = fleetAliases;
  programs.zsh.shellAliases = fleetAliases;
  programs.fish.shellAliases = fleetAliases;
  programs.nushell.shellAliases = fleetAliases;
}
