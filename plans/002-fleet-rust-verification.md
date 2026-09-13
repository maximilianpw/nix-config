# Fleet Rust extraction verification matrix

Required companion to `002-extract-fleet-rust.md`, planned against `fbd4b40` plus the repaired working-tree Fleet tunnel test. The executor must read the main plan for scope, architecture, and safety before using this matrix.

All automated cases use fictional hosts, temporary HOME/config directories, fake external tools, or real task-created child processes. They must never contact the user's hosts, use live launchctl, or signal existing user processes. Copy behavior assertions, not personal identity data, into the standalone repository.

## Configuration and CLI dispatch

| Case | Required result |
| --- | --- |
| No arguments | Same command as `list` |
| Help/version/completions without config | Success, no external commands |
| Missing explicit config / missing default config | Actionable setup error, no fallback to another explicitly unselected file |
| Precedence | CLI path wins over env path; env wins over XDG/HOME default |
| Schema and fields | Unsupported version, unknown fields, duplicate aliases, missing required fields fail before spawning |
| Host identity | Explicit current host determines local behavior; no inference from workstation hostname |
| Ports | Numeric range 1..65535; duplicate managed local ports rejected |
| Mapping target | Declared remote host or alias, never current host |
| Option-like target / control characters | Rejected before OpenSSH execution |
| Plain SSH aliases | Work without generated `tm-`/`fleet-forward-` aliases when optional target fields are omitted |
| `config validate` | Pure parsing/validation, success 0, invalid config 2, no networking |
| Serialization bridge | Nix-generated TOML passes the same Rust validation used for manual TOML |
| Personal projection | Every source-to-schema row in the main plan is asserted, including display_target vs SSH target and NixOS OS metadata |
| Alias target overrides | Only declared aliases may override connection targets; unspecified fields inherit canonical targets |

## Legacy command compatibility

Source: `scripts/fleet.sh`, `scripts/tests/fleet-ssh-regression-test.sh`.

| Case | Required result |
| --- | --- |
| List | Current machine line, deterministic rows, existing display fields and aliases |
| `ssh HOST` with configured tmux alias | Exec that alias, preserving its RemoteCommand and TTY policy |
| `ssh HOST` without tmux alias | Explicit remote tmux command, configured default session |
| Named SSH session | `ssh -t`, correct remote tmux path, safe session quoting |
| Session validation | Unsafe names fail before SSH/tmux; existing accepted identifier characters retained |
| Repeatable `--forward` | PORT and LOCAL:REMOTE normalize correctly, loopback bind, no ControlMaster reuse |
| Local SSH | Exec local tmux, reject forwarding to current host |
| Shell | Local SHELL fallback, remote trailing SSH argv after HOST, and local ignoring of extras preserved |
| Run | Local argv preserved; remote shell semantics documented and tested with spaces and quoting |
| Remote shell | tmux/doctor command syntax compatible with the existing fish login-shell use case |
| Unknown SSH alias | `ssh unknown` uses `tm-unknown`; shell/run use unknown; forward uses fleet-forward-unknown; doctor/t3 reject missing metadata |
| Known alias dispatch | Nix-projected alias retains its original SSH target, tm-alias, and fleet-forward-alias; doctor canonicalizes to match mappings |
| Local default tmux | PATH tmux and main default, even if remote metadata declares another executable/session |
| T3 | Declared port and optional local override, dedicated forwarding target |
| Forward aliases | list/ls, stop/delete/rm retain dispatch behavior |
| Ad-hoc remote target | Preserve data passthrough inside one -L argument; managed/doctor target validation stays separate |
| Forward discovery | Supported ps output forms, separate and joined `-L` arguments; uncertainty not silently treated as ownership |
| Port conflict | Existing forward detected; actual bind failure remains authoritative for races/non-SSH listeners |
| Managed deletion | Verified managed job/child gets pause guidance and refuses PID deletion |
| Unmanaged deletion | Revalidated disposable SSH-forward process can be stopped; unrelated or ambiguous identity refused |
| Paused managed port | An unrelated ad-hoc forward on that port is not classified as managed solely from port number |
| Ambiguous managed snapshot | Refuse a potentially managed deletion if ownership cannot be established; supervisor none does not fabricate ownership |
| Foreground behavior | stdin, terminal allocation, exit code, INT/TERM behavior preserved; no orphan wrapper/child |

Use a disposable PTY integration test for terminal behavior where supported. Argument snapshots alone do not establish signal or TTY compatibility. Never run `forward delete` against a PID discovered from the user's actual process table in tests.

## Supervisor and doctor

Source: `scripts/fleet-tunnels.sh`, repaired `scripts/tests/fleet-tunnel-regression-test.sh`, and Nix assertions in `tests/fleet-tunnel-regression.nix`.

| Case | Required result |
| --- | --- |
| No mappings / no supervisor | Clear status; doctor can still check configured SSH host; unsupported pause/resume fail clearly |
| Job observation | One job read supplies state and PID for each observation |
| Disabled label | Exact label match; port 30000 must not pause 3000 |
| Pause | Persist disable and boot out only requested job; survive simulated relogin/activation |
| Resume already running | No redundant enable/bootstrap/kickstart |
| Resume occupied | Refuse without killing occupant or clearing existing pause intent |
| Resume missing job | Require plist, enable/bootstrap, refresh state before deciding kickstart |
| Resume loaded/stopped | Exercise actual kickstart path and failure reporting |
| Mutation failures | disable/bootout/enable/bootstrap/kickstart failures produce nonzero results and describe partial state accurately |
| Running without owned listener | Not healthy, even while SSH may be authenticating |
| Listener ownership | Job PID or direct SSH child accepted; unrelated child/grandchild rejected |
| Unavailable listener inspection | Preserve uncertainty or conservative unrelated classification; never claim verified ownership |
| IPv4/IPv6 conflict fixture | Preserve current conservative detection of unrelated same-port listeners; do not claim browser origin is unambiguous |
| SSH failure | Auth vs unavailable as supported by current diagnostics; remote probes skipped |
| Remote app down | Remote probe exit 1 means down; local listener alone is insufficient |
| Probe transport failure | SSH/probe failure or outer timeout yields unknown, not app-down |
| Paused mapping | Remote probe skipped; paused mapping alone does not fail doctor |
| Multiple mappings | SSH does not consume loop input; every intended mapping inspected |
| Alias | Doctor alias resolves to same mapping set |
| Deadlines | SSH/probe bounded by current 15s deadline and at most 2s kill grace |
| Cleanup | No leaked temporary stderr files on success, failure, or interruption |
| Output claim | Distinguish TCP listening from expected-app readiness; no generic end-to-end healthy claim |

Add explicit tests missing from the original suite, particularly loaded/stopped kickstart, paused-probe absence, mutation failures, and running-without-listener. Retain the original direct-mock-execution preflight concept in any generated-executable harness.

## Runner lifecycle

Source: `scripts/fleet-tunnel-runner.sh`.

| Case | Required result |
| --- | --- |
| Child exits before deadline | Reap child, cancel timer, preserve child exit outcome |
| Authentication hangs | Startup bound is 45s plus bounded listener probe; terminate only owned child |
| Healthy listener | Deadline is not a lifetime limit |
| Wrong process owns port | Startup fails even if another process is listening |
| INT/TERM during startup | Owned child and timer/thread resources cleaned up promptly |
| INT/TERM after startup | Same owned-child cleanup with no orphan SSH process |
| Boundary race | Child exit near deadline has deterministic outcome and cannot target reused/unrelated PID |
| Argument policy | BatchMode, connection timeout, keepalives, ExitOnForwardFailure, no ForwardAgent, no ControlMaster reuse, IPv4 loopback |
| Respawn | Runner exits; no internal infinite reconnect loop competing with launchd |

Use injected clock/deadline parameters internally for fast tests, plus real disposable process tests for reaping and signals. Production does not inherit the legacy fixture-only environment variables as public configuration.

## Packaging and Nix consumer

- Independent Cargo build/install with locked dependencies and no nix-config imports.
- Example config works with fictional ordinary SSH aliases and managed supervision disabled.
- Version/help/config validation do not require tmux, lsof, Herdr, or network access.
- Missing optional command dependency reports its name and affected operation.
- Cargo and Nix use the planned Rust 1.95.0 compiler and locked dependencies; the newer ambient Kim compiler must not hide MSRV drift.
- Nix wrappers supply all retained subprocess dependencies; Cargo-installed binaries report missing optional dependencies by operation.
- Separate package checks execute on Linux and macOS; unexecuted Darwin tests are recorded as blocked.
- Linux Darwin-module evaluation uses placeholder package references and does not require building or realizing a Darwin Rust package.
- Home Manager module emits one config destination and one package, and Darwin-only jobs.
- Existing LaunchAgent attr keys fleet-tunnel-PORT, labels, and pause semantics remain unchanged; config uses the XDG destination searched by Rust.
- Rust runner argv replaces only the executable implementation, preserving forwarding policy.
- Personal SSH blocks, known-host contents, capabilities, hosts.json contract, and shell aliases remain unchanged unless the main plan explicitly permits a correction.
- No permanent absolute checkout paths, personal host records, credentials, or generated SSH files enter the standalone package.
- Legacy oracle and Rust candidate both pass before changing installed defaults.

## Later installed acceptance gate

Local extraction did not authorize this gate. Separate approval later covered durable pinning and Kim activation: the installed version, generated config, host listing, local `run`, and current-host doctor passed. Signal/TTY behavior and real Joyce launchd/credential recovery still require acceptance beyond mocked tests. Inspect ports rather than assuming availability, preserve existing Herdr servers, and leave framework HMR, OAuth, simultaneous clients, and host reboot recovery explicitly unverified unless separately tested.
