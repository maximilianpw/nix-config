# Plan 008: Extract the flake check registry into a focused library module

> **Executor instructions**: Preserve every public check name and derivation. This is a structure-only change. Compare check attribute names before and after. Update `advisor-plans/README.md` when complete.
>
> **Drift check (run first)**: `git diff --stat 31341e0 -- flake.nix lib/checks.nix scripts/ci/build-regression-checks.sh scripts/tests/ci-regression-selection-test.sh tests/*.nix`
> If dependency plans intentionally changed an in-scope path, reconcile this plan against the new code before proceeding. For any other staged, unstaged, or committed drift, STOP and report instead of applying stale excerpts.

## Status

- **Status**: DONE
- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: Plans 002 and 003, because they intentionally change the check set first
- **Category**: dx
- **Planned at**: commit `31341e0`, 2026-09-16

## Why this matters

`flake.nix` contains more than 120 lines of repetitive check registration and platform-specific argument plumbing. The build-selection script already consumes checks generically, so moving construction into `lib/checks.nix` will make the root flake easier to scan without changing the public check interface.

## Current state

- `flake.nix:191-316` defines all checks inline.
- Most Linux checks repeat `config = self.nixosConfigurations.kim.config`, `inherit lib`, and `pkgs = nixpkgs.legacyPackages.x86_64-linux`.
- Fleet SSH/tunnel checks are repeated for Darwin.
- `scripts/ci/build-regression-checks.sh` derives regression names from `checks.x86_64-linux`, so public names must remain stable after Plans 002/003 establish the final set.
- Existing library pattern: `flake.nix` imports `lib/mksystem.nix` with explicit dependencies rather than relying on ambient flake scope. Follow that pattern.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Baseline names | `nix eval --json .#checks --apply 'checks: builtins.mapAttrs (_: builtins.attrNames) checks'` | JSON map of platform check names |
| Format | `alejandra --check flake.nix lib/checks.nix` | exit 0 |
| Selection test | `bash scripts/tests/ci-regression-selection-test.sh` | exit 0 |
| Evaluation | `nix flake check --no-build` | exit 0 |
| Lint | `make lint` | exit 0 |
| Diff hygiene | `git diff --check` | exit 0 |

## Scope

**In scope**:
- `flake.nix`
- Create `lib/checks.nix`
- `scripts/tests/ci-regression-selection-test.sh` only if it hardcodes source layout rather than public check names

**Out of scope**:
- Renaming, adding, deleting, or weakening checks
- Changing test implementation files
- Changing CI selection policy
- Extracting packages, dev shells, templates, or system builders

## Git workflow

- Suggested branch: `advisor/008-check-registry`
- Suggested commit: `refactor: extract flake check registry`

## Steps

### Step 1: Record the final check-name baseline

After Plans 002 and 003, evaluate `.#checks` and save the JSON outside Git. This is the contract for the refactor.

**Verify**: baseline contains expected x86_64-linux and aarch64-darwin names and evaluates without builds.

### Step 2: Create `lib/checks.nix`

Implement a function with explicit arguments, likely including:

- `self`, `inputs`, `nixpkgs`, `lib`;
- `hosts` if Fleet trust checks need it;
- `desktopKim`;
- `mkPreCommitCheck`.

Return the same platform attribute set currently assigned to `checks`. Introduce small local constructors only when they remove real repetition, for example a Kim-config regression helper. Keep exceptional arguments explicit rather than hiding them in a broad generic function.

**Verify**: `alejandra --check lib/checks.nix` exits 0.

### Step 3: Replace the inline block

In `flake.nix`, replace the full inline `checks = { ... };` with one import/call. Keep dependency flow visible at the call site.

**Verify**: the post-change check-name JSON is byte-for-byte equal to the saved baseline (use `diff` on temporary files).

### Step 4: Run evaluation and lint

Run the selection test, `nix flake check --no-build`, `make lint`, and `git diff --check`.

**Verify**: all exit 0.

## Test plan

No new check behavior. The machine-checkable regression is equality of public check names plus successful evaluation/lint. If feasible, also compare `drvPath` values for representative checks before/after; differences are acceptable only when caused by source-path relocation, not changed arguments.

## Done criteria

- [ ] `flake.nix` no longer contains the large inline registry.
- [ ] `lib/checks.nix` owns check construction with explicit dependencies.
- [ ] Public check names are unchanged from the post-Plans-002/003 baseline.
- [ ] CI regression selection behavior is unchanged.
- [ ] Formatting, lint, and no-build evaluation pass.
- [ ] No test implementation changed.

## STOP conditions

- Extracting the registry changes recursive `self` evaluation semantics.
- Public check names or platforms differ.
- A helper requires hiding many exceptional dependencies or creates harder-to-read abstractions.
- CI selection changes for reasons unrelated to Plans 002/003.

## Maintenance notes

New checks should be registered in `lib/checks.nix`; check implementation remains under `tests/`. Keep the root flake focused on outputs and composition.

## Completion notes

Completed on 2026-09-16.

- After Plan 003, the extracted registry exposes the final set: 2
  `aarch64-darwin` checks and 20 `x86_64-linux` checks. The migration-only
  Fleet SSH and tunnel checks are gone, and normal regression selection now
  includes `fleet-rust-regression` beside the installed, trust, and Ghostty
  consumer checks.
- `lib/checks.nix` now owns the registry with explicit dependencies. No test
  implementation or CI selector changed.
- `alejandra --check`, the selector test, `nix flake check --no-build`,
  `make lint`, and `git diff --check` passed. Full-tree checks used a disposable
  source copy because unrelated untracked Plan 006 Nix files must remain out of
  the real index.
