# Plan 010: Trim obsolete test scaffolding without losing safety coverage

> Execute only when implementation is requested. Read this plan completely, preserve unrelated work, and update this plan's row in `advisor-plans/README.md`. Do not activate, publish, push, or operate live services.
>
> Drift check: `git diff --stat 9482048 -- tests/fleet-rust-regression.nix tests/monitoring-regression.nix tests/homepage-calendar-regression.nix scripts/tests/homelab-backup-coordinator-test.sh`. Review both committed and working-tree drift. Stop if the assumptions below no longer hold.

## Status

- Status: DONE — reviewed commit `5cb7b9a`, integrated as `5f982c8` on `cleanup/2026-09-20-complete`
- Priority: P2
- Effort: S
- Risk: LOW
- Depends on: none
- Category: tests
- Planned at: commit `9482048`, 2026-09-20

## Context and current state

This is a personal Nix flake for Kim (NixOS homelab), Cuno (WSL), and Joyce (Darwin). Tests belong in `tests/*.nix` or `scripts/tests/`; `lib/checks.nix` and `make check-scripts` register them. No orphan test files were found. Do not remove entire tests to shorten the suite.

Four small sources of unnecessary maintenance remain:

1. `tests/fleet-rust-regression.nix:125–179` defines `loadCandidate`, accepting checkout paths, `getFlake`, private source files, and fallback packages. Its only repository caller, `lib/checks.nix:77–82`, supplies `fleetSrc = inputs.fleet`. Production uses `inputs.fleet.homeManagerModules.default` and `inputs.fleet.packages.${pkgs.stdenv.hostPlatform.system}.fleet` (`modules/fleet/home-manager.nix:17,64–67`). The test should use those public exports too.
2. The same test's `fleet_validate` helper probes `--help` before choosing `--config` or `FLEET_CONFIG`. `tests/fleet-installed-regression.nix:62–63` already requires `fleet --config ... config validate`.
3. `tests/monitoring-regression.nix` maintains `panelTitles`, a 21-item `expectedPanelTitles`, and these cosmetic assertions:
   ```nix
   assert lib.assertMsg (dashboard.uid == "kim-overview" && dashboard.title == "Kim Overview")
   "Kim Overview must retain its stable title and UID";
   assert lib.assertMsg (panelTitles == expectedPanelTitles)
   "Kim Overview must retain its concise panel set and order";
   ```
   The UID is not cosmetic: `lib/homelab.nix` uses it in the dashboard link.
4. `tests/homepage-calendar-regression.nix:43–44` repeats `nextcloud.extraApps.calendar.version == "6.5.4"`, already pinned in `packages/nextcloud-calendar.nix:8`. Package updates through `make update-nextcloud-apps` or the CI update inventory necessarily invalidate the duplicate literal.
5. Coordinator cases `borg-failure` (lines 200–206) and `final-status` (241–250) duplicate normal prepare/cleanup and the stronger `restart-failure` case. The former does not inject a Borg failure. The later `run_posthook_case` matrix does test Borg/cleanup exit-status precedence.

Match the existing `assert lib.assertMsg (...) "explanation";` convention. Retain behavioral invariants, not exact presentation snapshots.

## Scope

Only modify:

- `tests/fleet-rust-regression.nix`
- `tests/monitoring-regression.nix`
- `tests/homepage-calendar-regression.nix`
- `scripts/tests/homelab-backup-coordinator-test.sh`
- This plan's status and `advisor-plans/README.md`

Do not modify production code, inputs/lockfile, test registration, dashboard JSON, package definitions, or any other recovery test. In particular, retain all Fleet projection/SSH/launchd/TOML assertions and all monitoring query, datasource, security, and metric assertions.

## Steps and verification

### 1. Record baseline and simplify the Fleet test

Run `git status --short` and the three scoped Nix checks in the verification section before editing. Record any pre-existing failure rather than attributing it to cleanup.

Replace `loadCandidate` and its call with direct selection from `fleetSrc.homeManagerModules.default` and `fleetSrc.packages.${pkgs.stdenv.hostPlatform.system}.fleet`. Use the module as one element in the Home Manager module list, matching production's import convention. Remove only helpers made unused by this change. Do not rename the check or its argument.

Make `fleet_validate` invoke `"$fleetBin" --config "$1" config validate` unconditionally. Keep valid TOML round-trips, Linux/Darwin comparisons, and the invalid-config exit-2 assertion.

Verify: `nix build .#checks.x86_64-linux.fleet-rust-regression --no-link` exits 0. `git grep -n -E 'loadCandidate|builtins.getFlake|FLEET_CONFIG|nix/package.nix|nix/home-manager.nix' -- tests/fleet-rust-regression.nix` returns no matches (exit 1).

### 2. Remove only cosmetic and duplicated-literal assertions

Remove `panelTitles`, `expectedPanelTitles`, the panel order assertion, and the human-readable title comparison. Retain a standalone assertion for `dashboard.uid == "kim-overview"` with an accurate message. Keep the datasource, retained-artifact, query, and required-metric checks unchanged.

Remove only the Calendar version equality and its message. Retain app ownership, immutable-app updater restrictions, service dependencies, installed commands, and secret exclusion checks.

Verify: the monitoring and Homepage scoped builds below both exit 0. `git grep -n -E 'expectedPanelTitles|panelTitles|calendar.version' -- tests/monitoring-regression.nix tests/homepage-calendar-regression.nix` returns no matches.

### 3. Remove two duplicate coordinator scenarios

Delete only the complete `new_case borg-failure` and `new_case final-status` blocks with their comments. Preserve `normal`, `restart-failure`, all actual injected-failure scenarios, and the entire `run_posthook_case` matrix.

Verify: `bash scripts/tests/homelab-backup-coordinator-test.sh` exits 0 and prints its success message; `make check-scripts` exits 0. No new test framework or fixtures are needed.

### 4. Run final gates

```sh
alejandra --check tests/fleet-rust-regression.nix tests/monitoring-regression.nix tests/homepage-calendar-regression.nix
make lint
nix build .#checks.x86_64-linux.fleet-rust-regression .#checks.x86_64-linux.monitoring-regression .#checks.x86_64-linux.homepage-calendar-regression --no-link
make check-scripts
nix flake check --no-build
git diff --check
git diff --stat
```

All commands must exit 0. Use `nix develop` if required tooling is absent. A non-Linux executor needs an already authorized Linux builder or must report Linux build checks unverified; do not set up remote infrastructure.

## Done criteria and test plan

- [x] All verification commands passed in coordinator review; no remaining environment blocker.
- [x] Fleet uses the same public module/package entry points as production.
- [x] Stable Grafana UID, query semantics, and safety assertions remain.
- [x] Calendar has one release pin, in its package definition.
- [x] Actual coordinator failure injection and posthook exit-status tests remain.
- [x] No test file, registration, or production behavior was removed.
- [x] The source diff stayed within the allowed files; plan and index are DONE.

No new tests are required: retained tests verify the behavior, and the deletion boundaries above prevent removing unique coverage.

## STOP conditions and maintenance

Stop if another repository caller requires a checkout-path Fleet candidate, the pinned public exports are absent, or a supposedly duplicate assertion protects behavior absent from the retained cases. Do not replace missing evidence with broad deletion. Fix failures introduced by the change within scope; report unrelated failures or required scope expansion.

Suggested commit, if separately requested: `Trim obsolete test scaffolding`. Future package bumps should not require cosmetic test edits. Compatibility checks should exercise public dependency exports rather than private source layout.

## Execution review

Luna implemented this plan in `/home/maxpw/nix-config-cleanup-worktrees/tests`.
The coordinator reviewed the complete four-file diff and independently passed
Alejandra, `make lint`, the three scoped Nix builds, the coordinator shell test,
`make check-scripts`, `nix flake check --no-build`, and diff checks. The worker's
initial invalid-source-path evaluation failure did not recur on the reviewer
rerun. The reviewed source commit `5cb7b9a` was cherry-picked as `5f982c8` on
the isolated integration branch. Integration into main remains separate and
unperformed.
