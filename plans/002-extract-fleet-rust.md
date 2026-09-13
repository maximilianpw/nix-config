# Plan 002: Extract Fleet into a standalone Rust package

## Status and execution contract

- Priority: P1
- Effort: L, several separately verified implementation stages
- Risk: MED; process ownership, SSH behavior, and declarative installation must remain correct
- Category: migration
- Fleet baseline: nix-config `fbd4b40`, 2026-09-12, plus the uncommitted Fleet regression repair
- Last reviewed at: `53beed1`; intervening commits did not change the Fleet sources
- Depends on: Plan 001, DONE; preserve its test repair and acceptance evidence
- Status: DONE for extraction, publication, durable nix-config pin, and Kim activation; Joyce launchd acceptance remains pending

The user chose Rust and later requested implementation. During execution, the user separately authorized a public GitHub repository, no license, the initial commit and push, and activation on Kim. No remote session, network interruption, Joyce activation, or live launchd tunnel operation was authorized or performed.

The deliverable is an independently tested Rust Fleet package plus a pinned Nix consumer integration. Kim is the first activated host; Joyce remains the launchd acceptance gate. Do not publish a crate or commit an absolute developer path to finish this plan.

## Goal

Move reusable Fleet behavior out of a personal Nix configuration without combining extraction with the proposed workspace feature. Keep OpenSSH as the transport, tmux as the current `fleet ssh` backend, and launchd as the current managed-tunnel supervisor. Herdr native sessions were proven in Plan 001, but the existing CLI does not orchestrate Herdr. That feature belongs to Plan 003 or later.

The original target was `/home/maxpw/fleet`; the implementation request overrode it with `/home/maxpw/local/fleet`. The binary name remains `fleet`. If that path already exists, inspect its ownership and ask before using it; never overwrite it. The Cargo package name can be `fleet` locally with `publish = false`. Crates.io availability, public repository naming, and licensing are publication decisions, not prerequisites for a local package.

## Baseline and drift check

Before editing:

```sh
cd /home/maxpw/nix-config
git rev-parse --short HEAD
git status --short
git diff --stat fbd4b40..HEAD -- lib/fleet.nix modules/fleet scripts/fleet.sh scripts/fleet-tunnels.sh scripts/fleet-tunnel-runner.sh tests/fleet-ssh-regression.nix tests/fleet-tunnel-regression.nix scripts/tests/fleet-tunnel-regression-test.sh flake.nix
```

Read every changed Fleet file and compare it with this plan. Concurrent homelab work advanced HEAD to `53beed1` during planning without changing Fleet sources. The unrelated working-tree file list also changed during review. Record the live status at execution rather than treating a cached list as authoritative. Preserve all unrelated changes without inspecting secret contents, staging, stashing, resetting, or attributing their failures to Fleet.

The acceptance-session repair in `scripts/tests/fleet-tunnel-regression-test.sh` is not committed. Its changes are part of the required baseline:

```sh
printf '#!%s\n' "$BASH" >"$TMPDIR/bin/launchctl"
expect_success launchctl print-disabled "gui/$(id -u)"
```

The other generated mocks also use `$BASH`; temporary-file cleanup assertions use ordinary glob loops rather than unavailable `compgen`. Copying the test from HEAD alone loses these fixes. Record a SHA-256 digest of each imported baseline file in the new repository's migration notes. Preserve provenance and existing notices; do not assign a new license without the owner's decision.

Run before porting:

```sh
nix build .#checks.x86_64-linux.fleet-ssh-regression .#checks.x86_64-linux.fleet-tunnel-regression --no-link
```

Expected: both pass. They passed in the acceptance session; rerun rather than treating the report as current execution evidence. If they fail, stop and separate baseline repair from the Rust port.

## Sources the executor must read

| File in nix-config | Current responsibility |
| --- | --- |
| `scripts/fleet.sh` | Commands, SSH arguments, local-host dispatch, process-based forward discovery |
| `scripts/fleet-tunnels.sh` | launchd state, persistent pause/resume, listener ownership, doctor probes |
| `scripts/fleet-tunnel-runner.sh` | One SSH child, startup deadline, signal cleanup |
| `lib/fleet.nix` | Personal inventory projection, generated executable, SSH blocks, agent contract, LaunchAgent definitions |
| `modules/fleet/home-manager.nix` | Typed mapping options, package installation, generated files, Darwin launchd wiring |
| `modules/fleet/default-tunnels.nix` | Personal Joyce-to-Kim mappings; retain unchanged |
| `tests/fleet-ssh-regression.nix` and its shell test | Mocked SSH/tmux command contracts |
| `tests/fleet-tunnel-regression.nix` and its repaired shell test | Supervisor, diagnostics, timeout, runner, and launchd argument contracts |
| `tests/fleet-agent-forwarding-regression.nix` | ForwardAgent off; forwards absent from ordinary SSH blocks |
| `tests/fleet-trust-regression.nix` | Personal identity and server trust invariants |
| `tests/fleet-ghostty-regression.nix` | Kim's terminal support invariant |
| `plans/001-fleet-personal-workflow-results.md` | Live acceptance scope, port conflicts, cleanup, unverified behavior |
| `flake.nix`, `Makefile:71–78` | Fleet check outputs; check-scripts runs Bash syntax, ShellCheck, and shell tests directly; lint builds the pre-commit check |

Important current excerpts from `lib/fleet.nix`:

```nix
inventory = import ./inventory.nix {inherit lib;};
package = pkgs.writeShellApplication {
  name = "fleet";
  runtimeInputs = [ pkgs.openssh pkgs.tmux pkgs.bash pkgs.coreutils pkgs.gnugrep pkgs.lsof ];
  text = fleetScript;
};
```

Managed tunnel settings currently include:

```nix
RunAtLoad = true;
KeepAlive = true;
ThrottleInterval = 30;
ProcessType = "Background";
```

Keep the established labels `org.nix-community.home.fleet-tunnel-PORT`. Pause state is stored by launchd against these labels, outside the plist. Renaming them is a behavioral migration, not cosmetic cleanup.

## What the pilot establishes

Plan 001 passed remote edit/browser flow, detach/reattach, network recovery, and a separately repeated sleep/wake test on port 5173. Credential reconnect succeeded after unlocking, but a distinct blocked prompt was not captured. Do not claim the Rust implementation inherits live acceptance merely by matching mocks.

Known existing conflicts are not extraction targets:

- Kim loopback port 3000 belongs to Gotenberg.
- Joyce has Rivierabox on IPv6 loopback 3000 plus the managed IPv4 tunnel.
- Host-wide doctor can fail while the 5173 mapping works correctly.

Preserve mapping defaults and report these limitations. Do not stop those services, rename ports, change bind families, or make doctor green as part of extraction.

## Architecture and ownership

### Standalone repository

Use one Cargo package with a reusable internal library and two binaries:

- `fleet`: public CLI.
- `fleet-tunnel-runner`: supervisor entry point with a documented, stable argument contract for Nix integration.

Suggested layout, create only modules with actual responsibilities:

```text
Cargo.toml
Cargo.lock
rust-toolchain.toml
src/lib.rs
src/main.rs
src/bin/fleet-tunnel-runner.rs
src/config.rs
src/ssh.rs
src/forwards.rs
src/tunnels.rs
src/doctor.rs
src/process.rs
src/launchd.rs
tests/config.rs
tests/ssh.rs
tests/tunnels.rs
tests/runner.rs
tests/fixtures/
examples/config.toml
docs/configuration.md
docs/compatibility.md
docs/migration-baseline.md
nix/package.nix
nix/home-manager.nix
flake.nix
README.md
AGENTS.md
.github/workflows/check.yml
```

Use `clap`, `clap_complete` for generated completions, `serde`, `toml`, and `thiserror`. Keep errors that drive behavior typed; add context at the CLI boundary. Use standard subprocess facilities; add narrowly chosen Unix signal/process dependencies when runner tests establish the need. Do not introduce Tokio, an SSH implementation, a generic plugin framework, or a daemon without a concrete requirement and a separate decision.

Use Rust 1.95.0 for this port, matching the current nix-config locked nixpkgs compiler, verified during planning. The installed Kim compiler is newer at 1.98.1 and must not silently become the port's minimum requirement. Set `rust-version = "1.95"`; pin `channel = "1.95.0"` and `components = ["rustfmt", "clippy"]` in rust-toolchain.toml. Ensure the selected compiler actually reports 1.95.0 using the new dev shell or an available toolchain manager; do not assume a direct Nix-installed cargo honors rust-toolchain.toml. Seed the standalone nixpkgs pin from the consumer's locked revision, and require nix/package.nix to use that compatible rustPlatform. If dependencies cannot support 1.95.0, stop for an explicit toolchain revision decision. Generate Cargo.lock before any `--locked` command; commit it only when commits are explicitly authorized.

### Personal Nix repository

Keep here:

- `lib/hosts.nix` and `lib/inventory.nix`.
- SSH configuration, keys, known-host generation, trust and tailnet policy.
- Host capabilities, personal tunnel defaults, and `FLEET.md` generation.
- Compatibility `hosts.json` output and existing shell aliases.

Do not move personal inventory, generated contracts, public identity records, secrets, or acceptance artifacts into the distributable repository. New public examples and tests use fictional hosts and temporary paths.

The standalone Home Manager module owns package installation, `config.toml` generation, and optional LaunchAgent declarations. The personal wrapper supplies settings and imports it. Exactly one module must own each destination and LaunchAgent at a time.

### Runtime configuration v1

Use TOML with precedence `--config PATH`, then `FLEET_CONFIG`, then `$XDG_CONFIG_HOME/fleet/config.toml`, falling back to `$HOME/.config/fleet/config.toml`. An explicit missing path is an error. A missing default config produces a setup error for operational commands; help, version, and shell-completion generation work without config. No silent configuration merge, hostname guessing, or implicit writes.

Proposed complete minimal example:

```toml
schema_version = 1
current_host = "laptop"

[hosts.laptop]
ssh_target = "laptop"
aliases = []
os = "darwin"
role = "interface"
user = "developer"
client_enrolled = true
gui = true
long_running_agents = false

[hosts.workbox]
ssh_target = "workbox"
forward_target = "workbox"
aliases = ["dev"]
os = "linux"
role = "compute"
user = "developer"
client_enrolled = true
gui = false
long_running_agents = true
tmux_command = "tmux"
tmux_session = "main"

[tunnels]
supervisor = "none"
mappings = []
```

Optional host fields: `display_target`, `tmux_target`, `forward_target`, `tmux_command`, `tmux_session`, `t3code_port`. Default `display_target` and `forward_target` to `ssh_target`; default tmux executable/session to `tmux`/`main`. Nix supplies `display_target = host.hostName` so list output retains the actual inventory target even when connection dispatch uses a shorter SSH alias. When `tmux_target` exists, use it for the no-session SSH path, preserving generated `tm-HOST` aliases. Otherwise construct an explicit remote tmux command. Nix emits the existing `fleet-forward-HOST` and `tm-HOST` targets for managed peers. OpenSSH owns remote login, port, and identity resolution; the `user` field is display metadata, not a competing credential configuration.

For legacy alias fidelity, add optional `hosts.<name>.alias_targets.<alias>` records containing only `ssh_target`, `tmux_target`, and `forward_target` overrides. Keys must be declared aliases. Unspecified overrides inherit the canonical host's targets; ordinary manual configs need none. Nix emits explicit target triples for every remote alias, so `fleet ssh dev` can retain `ssh tm-dev` rather than silently becoming `ssh tm-workbox`. This is data resolution, not shell/template interpolation.

A launchd mapping adds explicit `host`, `local_port`, `remote_port`, `remote_host`, and `label` fields under `[[tunnels.mappings]]`, with `supervisor = "launchd"`. Resolve plist locations from the runtime HOME, not a personal path stored in the package. Labels must use a safe restricted identifier syntax; the Home Manager module generates the existing label format. A non-Nix user may supply an already-installed compatible job; imperative job installation is deferred.

Validate schema version, unknown fields, canonical and alias uniqueness, declared current host, target strings, port range 1..65535, duplicate local ports, mapping host resolution, local-host mapping rejection, and safe remote-host syntax before spawning anything. Treat SSH targets as individual arguments; reject leading-option targets and control characters. Do not expand configuration text as shell code. Keep remote-host syntax at existing DNS/IPv4 support; broader IPv6 target parsing is deferred. Allow an unknown OS metadata string rather than limiting new users to NixOS platform names.

The required top-level fields are `schema_version`, `current_host`, and `hosts`. The required host fields are those shown in the minimal example. Default the entire tunnels section to `supervisor = "none"` and no mappings. Other defaults and optional fields are only those explicitly listed above. Managed mappings with supervisor none may be displayed as unsupervised, but they confer no process ownership.

The Nix projection is closed and tested:

| Personal source | Runtime field |
| --- | --- |
| hostname / inventory key | current_host / hosts table key |
| remote inventory key | ssh_target, never host.hostName |
| host.hostName | display_target |
| host.user, role, aliases, os, gui | user, role, aliases, os, gui |
| host.client != null | client_enrolled, rendered as yes/no in list |
| host.longRunningAgents | long_running_agents |
| host.tmuxCommand, tmuxSession, optional t3codePort | tmux_command, tmux_session, optional t3code_port |
| remote canonical key or alias token | ssh_target = token, tmux_target = tm-token, forward_target = fleet-forward-token, using alias_targets for aliases |
| localInventoryHost.darwin | tunnels.supervisor launchd or none |
| mapping host, localPort, remotePort, remoteHost or localhost | host, local_port, remote_port, remote_host |
| mapping localPort | label org.nix-community.home.fleet-tunnel-PORT |

List preserves column order HOST USER TARGET ROLE CLIENT ALIASES, sorted canonical host names, comma-joined aliases without spaces, and the existing yes/no client display. Do not project SSH public keys, identity-agent paths, or additional inventory fields outside this schema.

Runtime configuration is read-only. There is no workspace state store in this extraction. Keep existing external `hosts.json` and `FLEET.md` compatibility exports generated by Nix; the Rust CLI does not synthesize user credentials or agent instructions.

## Compatibility contract

Read `plans/002-fleet-rust-verification.md` before porting commands; it is the required test matrix for this plan. Every row must have a Rust test or a stated platform acceptance gate.

Preserve:

- `fleet` defaulting to list; help, command aliases, display fields and ordering.
- SSH/tmux session behavior, local-host behavior, and existing ad-hoc forwarding.
- Foreground attachment and tunnel process lifetimes, exit codes, signals, and TTY behavior.
- No agent forwarding; managed loopback binds; no multiplexing on managed and attachment-scoped forwards.
- launchd pause persistence, unrelated-listener protection, startup timeout, and doctor distinctions.
- Existing `run` semantics: local command uses argv; remote command follows OpenSSH remote-shell joining. Do not silently promise argv fidelity remotely. Document and test spaces/quoting and a fish remote shell. A future explicit argv-safe command mode is separate scope.
- `shell HOST` accepts trailing SSH arguments, including option-like arguments after HOST; local-host shell currently ignores extras. Model clap parsing accordingly and test both paths.
- Local `ssh` uses PATH tmux and default session main, independent of configured remote tmux executable/session.
- Ad-hoc `forward` retains existing remote-target string handling, including bracketed address forms passed to OpenSSH; the restrictive DNS/IPv4 validation above applies to managed mapping/doctor targets. Treat ad-hoc targets as data inside one -L argument, not executable shell text.

Do not require configuration-host membership for every legacy SSH pass-through if the old command accepted an SSH alias. Preserve command-specific fallback behavior while rejecting option-like targets. Configuration-backed commands such as doctor and t3 still require declared metadata. Pin these distinctions in tests rather than applying a global canonicalization refactor.

Permitted explicit v1 additions: `--version`, `completions SHELL`, and `config validate`, with corresponding help text. Permitted differences: config/setup diagnostics, consistent early rejection of invalid/out-of-range ports and option-like host targets, and managed-process delete protection. For the last item, identify the actual managed job or its direct SSH child, not just a matching port number. Show `fleet tunnel pause PORT` for verified managed forwards and refuse PID deletion of them. A paused managed port occupied by an unrelated ad-hoc forward must not be mislabeled as owned. Managed protection requires a launchd job/child identity; supervisor none retains unmanaged behavior. If an active launchd mapping may own a candidate but its snapshot cannot be read reliably, refuse deletion rather than guess. Record these differences in compatibility notes and tests; no other silent redesign.

## Ordered stages

### Stage A: Capture baseline and create the Rust package

After baseline checks pass, initialize only the new local directory and scaffold the package, configuration docs, example, and test helpers. Implement the read-only `fleet config validate` command alongside parsing so subsequent packaging checks can consume it. Keep source control local; no commits, remotes, or pushes without instruction. Write a short AGENTS.md naming commands and the safety limits for disposable tests.

Design tests to run without real hosts or the user's home. Use temporary HOME/config/state directories and fake executables injected through a narrow internal process interface or a test PATH. Production executable selection must not depend on inherited fixture-only environment switches. Configured launchd semantics must be testable with a fake backend on Linux without pretending real launchd exists there.

Verify in `/home/maxpw/fleet`:

```sh
cargo fmt --all --check
cargo clippy --locked --all-targets -- -D warnings
cargo test --locked --test config
```

Expected: config tests pass, invalid config spawns no subprocesses, help/version work with an empty HOME. Keep dependency versions resolved in Cargo.lock; initial lock generation precedes use of `--locked`.

### Stage B: Port list, shell, run, SSH, and ad-hoc forwards

Port command argument construction and use Unix exec replacement for plain shell/SSH attachment where practical. Preserve stdin and TTY passthrough, native exit status, and signal behavior. `Command::status` alone is not a substitute for exec when it leaves a wrapper with different signal semantics.

Translate existing shell test assertions into independent Rust integration tests using fictional hosts. Add coverage for shell/run/forward/t3/unknown-alias paths, which the current SSH suite does not cover. Do not claim those new assertions were copied from existing tests. The existing Nix renderer imports the personal inventory directly, so Bash-versus-Rust comparison belongs to Stage F in nix-config, where both candidates use that same inventory. Exact SSH argv and diagnostics with scripted consumers are comparison targets; do not validate both implementations solely against expectations copied from new Rust code.

Forward discovery parses observed process output, not guessed shell quoting. The legacy ps-based discovery has limitations; preserve supported cases and document uncertainty. Never identify a deletable process from a stored PID alone. Re-observe ownership before signaling; if identity is ambiguous, refuse.

Verify:

```sh
cargo test --locked --test ssh
cargo test --locked --test config
cargo clippy --locked --all-targets -- -D warnings
```

Expected: matrix command cases pass; no test contacts a real SSH target or signals an existing user process.

### Stage C: Port supervisor, runner, and doctor

Port the observable state model before lifecycle mutations. Distinguish supervisor state, listener ownership, and remote probe results. Capture state and PID from one launchd job read. Track errors and unknown states rather than interpreting a failed probe as a successful absence check.

The runner must own exactly one foreground SSH child and its startup deadline. Preserve the current command-line contract: local port followed by SSH arguments. Honor bounded startup, keepalives, no multiplexing, and cleanup on INT/TERM. Use monotonic deadlines, reap children, and verify own-child listener binding. A healthy listener has no maximum lifetime. launchd, not the runner, restarts failed tunnels. Process cleanup is limited to owned children; never use broad name-based kills.

Doctor preserves the existing SSH and remote-probe deadlines. Provide the same internal deadline injection used for runner tests so simulated timeout tests run quickly without changing production defaults or exposing test environment switches. Remote probes still use Bash plus timeout for v1; document these conditional dependencies rather than claiming arbitrary remote platforms already work. Parse launchctl output through tested fixtures, keeping real supervisor calls behind one concrete module.

Verify:

```sh
cargo test --locked --test tunnels
cargo test --locked --test runner
cargo test --locked --all-targets
```

Expected: full matrix passes, including deadlines, cleanup, direct-child ownership, and managed delete protection. Use real disposable child processes for signal tests, not only mocks that assert a kill call occurred.

### Stage D: Package independently and prove non-Nix operation

Implement `nix/package.nix` with `rustPlatform.buildRustPackage` and the locked Cargo dependencies. Expose `packages.<system>.default`, `packages.<system>.fleet`, and `checks.<system>.fleet` in the standalone flake. Initial supported targets: `x86_64-linux` and `aarch64-darwin`. Add other targets only after verification; Windows is out of scope.

Install both binaries and generated completions. Wrap the Nix binaries with a deterministic PATH for retained subprocess dependencies: openssh, tmux, lsof, and platform process tools where required. Include GNU coreutils if any local timeout command remains; Apple utilities are not interchangeable with GNU timeout flags. launchctl remains an OS-provided command, while remote Bash/timeout remain remote doctor prerequisites. Check remaining subprocess calls to determine whether local Bash is still needed after the Rust port. Do not impose every optional dependency merely to run `fleet list`.

Verify:

```sh
cargo build --locked --release
cargo install --locked --path . --root "$TMPDIR/fleet-install"
nix build "path:$PWD#fleet" "path:$PWD#checks.x86_64-linux.fleet" --no-link
```

Create TMPDIR as a task-owned temporary directory first. Expected: installed binaries support help/version, example config, fictional-host integration tests, and useful missing-dependency errors without nix-config. The installed version string identifies package version; documentation explains how to check the executable path for a shadowed installation.

Create Linux and macOS Cargo CI jobs using synthetic fixtures, with no credentials or live connectivity. Writing CI config is local work; publishing it is not authorized. A Linux-only pass does not count as Darwin verification. Run macOS checks when an approved Darwin development environment is available, or mark that gate BLOCKED.

### Stage E: Add the optional Home Manager module

Expose `homeManagerModules.default` with `programs.fleet.enable`, `.package`, and `.settings`. The settings option is a typed submodule that uses exactly the TOML snake_case field names and nesting specified above, including alias_targets; avoid a second camelCase translation layer. Generate `xdg.configFile."fleet/config.toml"` from settings so the file matches XDG-first runtime lookup. Add optional managed jobs only for launchd settings on Darwin, with attr keys `launchd.agents."fleet-tunnel-PORT"` and Labels `org.nix-community.home.fleet-tunnel-PORT`. Settings generation must use the same schema examples covered by Rust tests.

The module installs exactly one `fleet` package and config destination. It must not generate SSH identities, overwrite `~/.ssh/config`, register Herdr machines, or install public keys. Provide a manual TOML example that works with ordinary SSH aliases and `supervisor = "none"` outside Nix.

Pin a Home Manager flake input for module checks using the consumer's current locked revision, with nixpkgs following the standalone package's pin. Expose a `checks.x86_64-linux.home-manager` derivation in the standalone flake. On Linux, evaluate Darwin module outputs using a placeholder package path with no Darwin build dependency; extract only generated config text and job attributes. Validate both emitted configs with the real Linux Rust package. Do not build a Darwin activation package or reference a Darwin Rust output as a Linux build input. Actual macOS package/runtime verification remains Stage D's separate platform gate.

Verify with `nix build "path:$PWD#checks.x86_64-linux.home-manager" --no-link`, using disposable Home Manager evaluations for Linux and Darwin:

- Generated config is accepted by Rust's config validator, tested without executing operational commands.
- Linux has no launchd jobs.
- Darwin job labels, runner arguments, keepalive settings, and config destinations match the baseline.
- Invalid settings fail evaluation or config validation before activation.

Use Stage A's public read-only `fleet config validate` command as the config bridge, exit 0 for a valid config and 2 for invalid config. It must spawn no SSH or supervisor commands.

### Stage F: Prepare and test the nix-config consumer, without switching hosts

Create `tests/fleet-rust-integration.nix` as a callable check accepting `fleetSrc`. It loads the candidate's Nix package/module from an explicitly supplied source path and tests fictional module settings plus the personal projection. This check is a local integration harness, not a permanent absolute-path input.

Refactor `lib/fleet.nix` carefully so it can emit v1 settings from the inventory while retaining existing SSH settings, known-host exports, agent contract, aliases, and legacy package during migration. A test-only or explicitly selected candidate package must not silently change the installed default.

Make the callable check accept `{ lib, pkgs, fleetSrc, homeManager }` and return a Linux check derivation. `homeManager` is the locked Home Manager flake input, used for disposable Linux and Darwin module evaluations. Run it with the following local-only command:

```sh
nix build --impure --no-link --expr '
  let
    cfg = builtins.getFlake "path:/home/maxpw/nix-config";
    pkgs = cfg.inputs.nixpkgs.legacyPackages.x86_64-linux;
  in import /home/maxpw/nix-config/tests/fleet-rust-integration.nix {
    inherit pkgs;
    lib = pkgs.lib;
    fleetSrc = /home/maxpw/fleet;
    homeManager = cfg.inputs.home-manager;
  }
'
```

Expected: candidate config, package, and module assertions pass without activation. These absolute paths are caller-side local verification arguments, never production inputs. No local path may be written to flake.lock or left as a permanent production dependency. Using the `path:` source includes untracked test files without staging unrelated changes.

Preserve the original baseline check names until Rust has equivalent coverage. Add an explicit candidate integration check rather than replacing the passing oracle prematurely. At this stage keep the legacy Bash scripts available in nix-config, not as a second installed binary.

Nix verification:

```sh
alejandra --check lib/fleet.nix tests/fleet-rust-integration.nix
make lint
nix flake check --no-build
nix build .#checks.x86_64-linux.fleet-ssh-regression .#checks.x86_64-linux.fleet-tunnel-regression .#checks.x86_64-linux.fleet-agent-forwarding-regression .#checks.x86_64-linux.fleet-trust-regression --no-link
git diff --check
```

Also run the new parameterized candidate integration check. Expected: both legacy and Rust candidate coverage pass, personal SSH policy unchanged, and only one package/config/job owner in each evaluated configuration. Record unrelated failures without modifying the homelab or secrets work.

### Gate G: Durable pin and later activation

Stop with a locally verified extraction report. Ask the user for the repository destination, visibility, license, and authorization before publishing or pushing. After an approved durable revision exists, a follow-up can add and lock the Fleet input, import its module, and select the Rust package in the personal wrapper.

A source-level default-package change must still not activate hosts. Host activation needs its own approval and an installed-version check. The Rust runner changes LaunchAgent ProgramArguments and may cause existing jobs to restart on activation; do not describe that as disruption-free. Preserve labels to retain pause intent.

Repeat a scoped, approved live acceptance test before retiring the legacy implementation. Include terminal signal/TTY behavior, managed tunnel recovery, and credential recovery. Reuse the acceptance principles from Plan 001 but inspect current port occupancy and ask before choosing the test mapping. Never assume 3000 or 5173 is free.

Only after accepted Rust behavior should a later cleanup remove the old scripts/rendering and retire duplicated tests. No change to Herdr servers is needed for extraction.

## Permitted file changes during implementation

New repository: files under `/home/maxpw/fleet` for the layout above, package docs, fixtures, and CI only. No personal data or credentials.

In nix-config:

- `lib/fleet.nix`: projection and candidate injection support while preserving installed baseline.
- `tests/fleet-rust-integration.nix`: new parameterized candidate check.
- Existing Fleet regression files only where necessary to support candidate comparison; preserve the working-tree repair and independent legacy assertions.
- `modules/fleet/README.md`: accurate extraction status and correction of the nonexistent Herdr catalog generator claim.
- This plan, its verification matrix, `plans/README.md`, and `plans/002-fleet-rust-results.md`.

Gate G follow-up work was later authorized and completed in `flake.nix`, `flake.lock`, `modules/fleet/home-manager.nix`, and `tests/fleet-installed-regression.nix`. The parameterized check remains as an independent package/module boundary test. Inventory/trust/default-tunnel files, Herdr configuration, and all unrelated working-tree changes remain out of scope.

## Completion report and done criteria

Write `plans/002-fleet-rust-results.md` with per-stage PASS/FAIL/BLOCKED, baseline digests, exact commands, and deliberate compatibility differences. Record the new repository's status and candidate source digest without committing or publishing it.

Local extraction is DONE only when:

- Cargo formatting, Clippy, all integration tests, and release build pass.
- Both binaries install with Cargo without depending on nix-config or shell-language runtimes for their own implementation.
- Independent Nix package build and parameterized consumer check pass.
- The complete verification matrix has evidence; missing Darwin execution leaves the cross-platform gate BLOCKED.
- Runtime config drives fictional hosts, no template markers or personal inventory are compiled into Rust binaries.
- The configured SSH command, agent-forwarding policy, managed labels, and personal trust exports remain correct.
- The original extraction phase changed no active host configuration or live process; the separately authorized Gate G activated Kim without managed tunnel changes.
- All task changes are within the extraction or Gate G allowlists and unrelated work remains intact.
- The durable pin and Kim activation are recorded as complete; Joyce and interactive cross-machine acceptance remain explicit gates.

## STOP conditions

Stop and report if baseline tests fail, the target directory contains unrelated work, native signal behavior cannot be bounded by disposable tests, OpenSSH behavior would need an SSH-library rewrite, schema design requires secrets, or implementing the port requires changing personal trust or services. Seek a separate decision for public distribution, new supervisor backends, dynamic tunnel installation, workspace orchestration, or remote process startup.

## Maintenance notes

Version the runtime schema independently from human table formatting. Keep the runner entry-point contract stable for declarative consumers. Inspect configuration compatibility and pause persistence on future upgrades. Workspace IDs, Herdr ownership, application identity, and port allocation remain future design work; do not add speculative fields or a state database during extraction.
