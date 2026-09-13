# Fleet Rust extraction results

## Verdict

The standalone Rust extraction is complete and published at <https://github.com/maximilianpw/fleet>.

The user selected `/home/maxpw/local/fleet` instead of the plan's original `/home/maxpw/fleet` path. The public repository has no license, as requested.

- Initial extraction commit: `3c8ec46b526d08673bbd29f362742dc79bde7965`
- Initial Git archive SHA-256: `206ac06093d82811c53f3435e461bcf665aa67cf1e877580a1d426f93eb01d3e`
- Current nix-config pin: `5b725c2adc939ae5012e51cff465c444bac9b6ac`
- Current pin NAR hash: `sha256-jF7rAFYZXPG4RL8DB5gF2Kkva9Z3vxg89rsaP4hZ24I=`
- Visibility: public
- Crates.io publishing: disabled with `publish = false`
- Installed-host cutover: Kim activated successfully
- Installed Kim generation: `/nix/store/s01jkq8v60xaw2qbfq85lm51yab2krij-nixos-system-kim-26.05.20260911.21a67dc`
- Live Fleet process changes: none; Kim has no managed tunnel mappings

The Rust package is now the Home Manager-installed default from the pinned `fleet` flake input. The legacy Bash implementation remains in nix-config only as a regression oracle while Joyce's launchd acceptance is pending.

## Stage results

| Stage | Result | Evidence |
| --- | --- | --- |
| Baseline | PASS | Both legacy Fleet regression derivations built before the port. |
| A: package and config | PASS | Rust 1.95 configuration parser, validation, precedence, help/version/completions, and `config validate`; 42 config tests. |
| B: CLI and SSH behavior | PASS | list, ssh, shell, run, forward, T3, aliases, PTY/exec behavior, process discovery, and managed-delete protection; 38 SSH/forward tests. |
| C: supervisor, doctor, runner | PASS | launchd state model, pause/resume, listener ownership, deadlines, diagnostics, signals, and child cleanup; 36 tunnel tests and 13 runner tests. |
| D: independent packaging | PASS on Linux | Cargo release build/install and standalone Nix package/checks passed with Rust 1.95.0. |
| D: Darwin package/runtime | PASS in CI | GitHub's macOS 14 runners passed Cargo fmt, Clippy, all tests, and the aarch64-darwin Nix package/check. Real launchd acceptance remains pending. |
| E: Home Manager module | PASS by evaluation | Typed snake_case settings, one package/config destination, Linux without launchd jobs, and Darwin job attributes validated with a placeholder package. |
| F: nix-config consumer | PASS | Personal v1 projection, candidate package/module, legacy checks, and the parameterized integration derivation passed. |
| G: repository publication | PASS | Public GitHub repository and initial commit created and pushed with user authorization. |
| G: durable nix-config pin and Kim activation | PASS | `flake.lock` pins the published commit; the real module owns the package/config, Kim built and activated, and installed local commands passed. Joyce launchd acceptance remains pending. |

## Baseline and provenance

Execution started from nix-config HEAD `f9637f5`. The listed committed Fleet sources had no drift from `fbd4b40`. The repaired working-tree tunnel regression remained part of the baseline. Unrelated untracked `plans/` content and the existing test repair were not staged, reset, or committed.

Baseline regression command:

```sh
nix build .#checks.x86_64-linux.fleet-ssh-regression \
  .#checks.x86_64-linux.fleet-tunnel-regression --no-link
```

Result: PASS.

Imported-source SHA-256 values:

```text
0035027039e1db6412009e32464b18dac8b1413d7c9dd327b3bfec7f9284efdd  scripts/fleet.sh
16d28b76867851e7c5b1143c2d1656be8dc4b27f40a4db1812826e01dcc4b1c5  scripts/fleet-tunnels.sh
85f59b5b55f8a7c24834836db2f87e5a8dffdd03dadc06726264da270f317e8c  scripts/fleet-tunnel-runner.sh
fb10ae8187fc8f336b243672f8eb0f5acdbbce7474d7bc211618a5d11f71bc87  lib/fleet.nix
bd9758475f17c17c50bc8e639bf2ac0240ae483e55f62a27c4b68c97b8bf6848  modules/fleet/home-manager.nix
4f19509de46fd961c7d945d6df656a938d4b7ad8bae879e0722ae938eed3e5ab  modules/fleet/default-tunnels.nix
d944dda45ddd539895188fcfc51d02b51b09ba658cb39760aceed4a51b4d2fd7  tests/fleet-ssh-regression.nix
5c9f094d9946ae9d1306dfb492ccffe6a0a718452aac3ab0a98638de24e66927  scripts/tests/fleet-ssh-regression-test.sh
dfdfda55e41a649b6355626240f4b81929f14e1c736e9509e537a98ecaef9cbb  tests/fleet-tunnel-regression.nix
000a78ca795b678ca1bf93f014a4371169c957e9347030a926bdc367a4d9334f  scripts/tests/fleet-tunnel-regression-test.sh
e08b877cca6e8b2149abcc8977190d1673695ef462a762986e5e2ba15009ceef  tests/fleet-agent-forwarding-regression.nix
e146baf9dc90a7694e8d893b35d8c619d2a8ac44bfb009e6399c24d3cb65c555  tests/fleet-trust-regression.nix
f411fbdc9c7fa096cd9f1eec3716ecfb8b5c24ab87be408ec3dfae489eda2621  tests/fleet-ghostty-regression.nix
1285e502ca5257f48887ee0910a9c9f2d180405f2d3b5aae094b8c6d8b511bff  plans/001-fleet-personal-workflow-results.md
```

The standalone repository records the same provenance in `docs/migration-baseline.md` without personal inventory, credentials, or absolute developer checkout paths.

## Standalone verification

The final Rust suite has 129 integration tests. All tests use fictional hosts, fake executables, temporary state, or task-created child processes.

Passed with the ambient compiler and again through the pinned Nix development shell:

```sh
cargo fmt --all --check
cargo clippy --locked --all-targets -- -D warnings
FLEET_REQUIRE_FISH=1 cargo test --locked --all-targets
cargo build --locked --release

nix develop path:$PWD -c rustc --version
nix develop path:$PWD -c cargo clippy --locked --all-targets -- -D warnings
nix develop path:$PWD -c cargo test --locked --all-targets
```

The Nix shell reported:

```text
rustc 1.95.0 (59807616e 2026-04-14)
```

Cargo install verification passed:

```sh
cargo install --locked --path . --root "$PWD/target/fleet-install-test" --force
"$PWD/target/fleet-install-test/bin/fleet" --version
"$PWD/target/fleet-install-test/bin/fleet" --config examples/config.toml config validate
```

Version output:

```text
fleet 0.1.0
```

Standalone Nix verification passed:

```sh
alejandra --check flake.nix nix
actionlint .github/workflows/check.yml
nix build "path:$PWD#fleet" \
  "path:$PWD#checks.x86_64-linux.fleet" \
  "path:$PWD#checks.x86_64-linux.home-manager" \
  "path:$PWD#checks.x86_64-linux.alejandra" --no-link
nix flake check --no-build --all-systems "path:$PWD"
```

The flake exposes `packages.<system>.default`, `packages.<system>.fleet`, `checks.<system>.fleet`, and `homeManagerModules.default` for `x86_64-linux` and `aarch64-darwin`. Nix builds the crate and runs its tests with the pinned nixpkgs Rust 1.95.0 toolchain.

GitHub Actions run [34753878095](https://github.com/maximilianpw/fleet/actions/runs/34753878095) passed all four jobs:

- Cargo on Ubuntu
- Cargo on macOS 14
- Nix package and Home Manager checks on Ubuntu
- aarch64-darwin Nix package/check on macOS 14

## Consumer verification

The following nix-config checks passed after the consumer changes:

```sh
alejandra --check lib/fleet.nix tests/fleet-rust-integration.nix
make lint
nix build \
  .#checks.x86_64-linux.fleet-ssh-regression \
  .#checks.x86_64-linux.fleet-tunnel-regression \
  .#checks.x86_64-linux.fleet-agent-forwarding-regression \
  .#checks.x86_64-linux.fleet-trust-regression --no-link
git diff --check
```

The integration check first passed against the explicit local candidate path. Gate G then added a durable GitHub input, currently pinned to `5b725c2adc939ae5012e51cff465c444bac9b6ac`, and promoted the same test into the flake checks without adding an absolute developer path. `tests/fleet-installed-regression.nix` additionally verifies that Kim and Joyce each select exactly one package from the pinned input, generated TOML validates, Kim has no Fleet launchd jobs, and Joyce retains the two expected labels using the Rust runner.

```sh
nix build \
  .#checks.x86_64-linux.fleet-rust-integration \
  .#checks.x86_64-linux.fleet-installed-regression \
  .#checks.x86_64-linux.fleet-ssh-regression \
  .#checks.x86_64-linux.fleet-tunnel-regression \
  .#checks.x86_64-linux.fleet-agent-forwarding-regression \
  .#checks.x86_64-linux.fleet-trust-regression --no-link
make build
```

Kim activation required an interactive sudo terminal. The user ran `make rebuild`; the resulting system generation matched the previously built candidate.

`nix flake check --no-build` still fails while evaluating the unrelated `eval-kim-desktop` check in man-db with `path '...-source' is not valid`. The scoped Fleet checks and `make lint` pass, and the failure predates or lies outside the Fleet file allowlist.

## Darwin rebuild follow-up

A real Joyce build exposed scheduler-sensitive runner tests: test-only 80 ms startup and 100 ms listener-probe deadlines could expire before mock child processes ran. The production deadline remained 45 seconds and was not implicated. Linux reproduced the failure under single-CPU scheduler pressure. Commit `5b725c2adc939ae5012e51cff465c444bac9b6ac` gives ordinary ownership tests a two-second scheduling budget, retains short deadlines only in deadline-specific cases, and extends PID observation to five seconds. The original stressed runner command then passed three consecutive times, followed by all Cargo and Linux Nix checks. GitHub Actions run `34755974406` passed all four jobs, including the aarch64-darwin Nix package build that exercises the previously failing check phase.

## Compatibility notes

The port preserves the Bash command model and adds only the planned v1 commands and diagnostics:

- no arguments run `list`
- OpenSSH remains the transport and tmux remains the attachment backend
- local shell/run use native argv; remote run keeps OpenSSH remote-shell joining
- plain SSH and shell attachments use Unix exec replacement
- local tmux always uses PATH `tmux` and session `main`
- unknown aliases keep command-specific legacy fallbacks
- managed forwards bind `127.0.0.1`, disable agent forwarding and multiplexing, and retain the existing launchd labels
- doctor separates SSH reachability, listener ownership, supervisor state, and remote TCP readiness
- the runner owns one SSH child, uses a 45-second startup deadline, reaps it on INT/TERM, and leaves restart policy to launchd
- managed delete protection refuses verified jobs/direct children and fails closed when process identity is uncertain
- missing `ps` is reported only for commands that need forward inspection; plain `fleet ssh HOST` does not require it

Deliberate v1 additions are `--version`, `completions SHELL`, and `config validate`. Invalid ports, unsafe targets, unsafe tmux command strings, unsupported schemas, and invalid mappings fail before spawning.

Detailed personal port conflicts from Plan 001 remain unchanged. The extraction did not stop services, change mappings, or make host-wide doctor results green.

## Installed Kim acceptance

The installed profile resolves `/etc/profiles/per-user/maxpw/bin/fleet` to Rust Fleet 0.1.0. These live commands passed after activation:

```sh
fleet --version
fleet config validate
fleet list
fleet run kim printf 'fleet-installed-local-run-ok\n'
fleet run main-pc printf 'fleet-installed-alias-ok\n'
fleet doctor kim
fleet doctor main
```

The local run printed the sentinel, and doctor correctly skipped SSH for the current host and reported no managed tunnels.

## Remaining gates

- Joyce still needs separately approved activation and real launchd tunnel acceptance, including status, pause/resume, listener ownership, sleep/wake, and credential recovery.
- Installed interactive SSH/tmux behavior still needs a real cross-machine TTY acceptance run.
- Removing the Bash scripts and legacy checks must wait until the Joyce and interactive installed acceptance gates pass.
