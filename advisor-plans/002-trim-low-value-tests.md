# Plan 002: Remove duplicate and cosmetic regressions while keeping operational safety coverage

> **Executor instructions**: Follow each step and verification gate. Do not remove homelab backup/recovery tests. If a STOP condition occurs, stop and report. Update `advisor-plans/README.md` when complete.
>
> **Drift check (run first)**: `git diff --stat 31341e0 -- flake.nix Makefile tests/homepage-calendar-regression.nix tests/fleet-agent-forwarding-regression.nix tests/fleet-ssh-regression.nix tests/fleet-tunnel-regression.nix scripts/tests/fleet-ssh-regression-test.sh scripts/tests/fleet-tunnel-regression-test.sh`
> If dependency plans intentionally changed an in-scope path, reconcile this plan against the new code before proceeding. For any other staged, unstaged, or committed drift, STOP and report instead of applying stale excerpts.

## Status

- **Status**: DONE
- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `31341e0`, 2026-09-16

## Why this matters

Several checks enforce personal dashboard ordering or duplicate another test rather than protecting runtime behavior. In addition, `make check-scripts` appears to run two Fleet fixtures that immediately skip because their required binaries are only supplied by Nix checks. This plan removes low-value assertions and makes test ownership honest without touching recovery, backup, ingress, security, or service-state coverage.

## Current state

- `tests/homepage-calendar-regression.nix:32-163` hardcodes all bookmark groups, names, URLs, and card ordering.
- The same file's assertions from approximately line 164 onward protect operational contracts: loopback monitors, Nextcloud app ownership, updater behavior, and exclusion of a bearer calendar URL. Those assertions must remain.
- `tests/fleet-agent-forwarding-regression.nix` contains only two invariants:

```nix
assert lib.assertMsg (lib.all (block: block.ForwardAgent == "no") blocks) ...;
assert lib.assertMsg (lib.all (block: !(block ? LocalForward)) blocks) ...;
```

- `tests/fleet-tunnel-regression.nix:167-170` already checks both invariants against the same Joyce Fleet projection.
- `Makefile:75` runs `scripts/tests/*-test.sh` directly.
- `scripts/tests/fleet-ssh-regression-test.sh:4` and `scripts/tests/fleet-tunnel-regression-test.sh:4` return success without testing when their Nix-provided environment is absent.
- The actual owners are `tests/fleet-ssh-regression.nix` and `tests/fleet-tunnel-regression.nix`, which embed these scripts with the required binaries.

Important preservation rule: retain `tests/homelab-inventory-regression.nix`, `tests/homelab-backup-regression.nix`, `scripts/tests/homelab-backup-coordinator-test.sh`, `scripts/tests/homelab-backup-inspect-test.sh`, and `scripts/tests/t3code-backup-test.sh` unchanged.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Shell suite | `make check-scripts` | exit 0 |
| Nix format | `alejandra --check flake.nix tests/homepage-calendar-regression.nix tests/fleet-ssh-regression.nix tests/fleet-tunnel-regression.nix` | exit 0 |
| Nix lint | `make lint` | exit 0 |
| Homepage check | `nix build .#checks.x86_64-linux.homepage-calendar-regression --no-link` | exit 0 |
| Fleet SSH check | `nix build .#checks.x86_64-linux.fleet-ssh-regression --no-link` | exit 0 until Plan 003 later removes it |
| Fleet tunnel check | `nix build .#checks.x86_64-linux.fleet-tunnel-regression --no-link` | exit 0 until Plan 003 later removes it |
| Evaluation | `nix flake check --no-build` | exit 0 |
| Diff hygiene | `git diff --check` | exit 0 |

## Scope

**In scope**:
- `tests/homepage-calendar-regression.nix`
- `tests/fleet-agent-forwarding-regression.nix` (delete)
- `flake.nix`
- Rename `scripts/tests/fleet-ssh-regression-test.sh` to `scripts/tests/fleet-ssh-regression-fixture.sh`
- Rename `scripts/tests/fleet-tunnel-regression-test.sh` to `scripts/tests/fleet-tunnel-regression-fixture.sh`
- `tests/fleet-ssh-regression.nix`
- `tests/fleet-tunnel-regression.nix`

**Out of scope**:
- Any homelab backup/recovery test
- Fleet implementation changes
- Dashboard production configuration
- Changing Nextcloud application ownership or updater behavior
- Rewriting `scripts/tests/t3code-post-activation-test.sh`; that is a separate test-quality improvement, not deletion cleanup

## Git workflow

- Suggested branch: `advisor/002-trim-tests`
- Suggested commit: `test: remove cosmetic and duplicate regressions`
- Do not push or activate configurations.

## Steps

### Step 1: Capture pre-existing user work

Before editing, preserve a machine-comparable patch for the four known dirty files:

```bash
git diff --binary -- modules/cliproxyapi/README.md modules/cliproxyapi/darwin.nix modules/cliproxyapi/home-manager.nix users/maxpw/modules/agent-tools.nix > /tmp/plan-002-preexisting.patch
```

**Verify**: `/tmp/plan-002-preexisting.patch` exists. Do not stage, restore, or edit those files.

### Step 2: Remove Homepage presentation snapshots

Delete helpers and assertions used only to enforce:

- bookmark group order;
- exact bookmark names and URLs;
- absence of bookmark descriptions;
- exact Applications and Operations card order;
- current-tab navigation (`homepage.settings.target == "_self"`), which is presentation preference rather than a safety boundary.

Retain assertions that every service monitor uses loopback, Nextcloud uses its status endpoint, declarative apps remain explicit, broad app updates remain disabled, the targeted updater retains its user/dependencies/timer, required commands remain installed, and no deferred calendar bearer URL enters rendered config.

After deleting assertions, remove now-unused local helpers such as `bookmarkGroups`, `bookmarksIn`, `bookmarkSummary`, `cardNames`, and `allBookmarks`.

**Verify**: `nix build .#checks.x86_64-linux.homepage-calendar-regression --no-link` exits 0.

### Step 3: Delete the duplicate Fleet forwarding check

Delete `tests/fleet-agent-forwarding-regression.nix` and its `flake.nix` registration. Do not remove the equivalent assertions from `tests/fleet-tunnel-regression.nix` in this plan.

**Verify**:

```bash
nix eval --json .#checks.x86_64-linux --apply builtins.attrNames | grep -qv 'fleet-agent-forwarding-regression'
```

and `nix build .#checks.x86_64-linux.fleet-tunnel-regression --no-link` exits 0.

### Step 4: Rename Nix-owned Fleet fixture scripts

Rename the two embedded shell scripts from `*-test.sh` to `*-fixture.sh`, and update the `builtins.readFile` references in their Nix wrappers. The new names must no longer match `scripts/tests/*-test.sh`, but the general `scripts/tests/*.sh` syntax and ShellCheck loops must still include them.

Do not replace their Nix environment guards with live host behavior. These remain disposable fixtures.

**Verify**:

- `test -z "$(find scripts/tests -maxdepth 1 -name 'fleet-*-test.sh' -print)"` exits 0.
- `grep -q 'scripts/tests/\*-test.sh' Makefile` confirms the direct-run loop still targets only true tests.
- `grep -q 'scripts/tests/\*.sh' Makefile` confirms syntax/ShellCheck still includes fixtures.
- `make check-scripts` exits 0.
- Both scoped Nix Fleet checks still pass.

### Step 5: Run evaluation and inspect the diff

**Verify**:

- `alejandra --check flake.nix tests/homepage-calendar-regression.nix tests/fleet-ssh-regression.nix tests/fleet-tunnel-regression.nix` exits 0.
- `make lint` exits 0.
- `nix flake check --no-build` exits 0.
- `git diff --check` exits 0.
- `git diff --binary -- modules/cliproxyapi/README.md modules/cliproxyapi/darwin.nix modules/cliproxyapi/home-manager.nix users/maxpw/modules/agent-tools.nix | cmp -s /tmp/plan-002-preexisting.patch -` exits 0, proving pre-existing user work is byte-for-byte unchanged.
- `git status --short` shows the four known pre-existing paths plus only this plan's in-scope paths and `advisor-plans/README.md`.

## Test plan

No new behavior tests are required. This is a subtraction plan: each removed assertion must either be cosmetic or duplicated, and every retained operational assertion must still execute in its original Nix check.

## Done criteria

- [x] Exact bookmark and service-card snapshots are gone.
- [x] Operational Homepage/Nextcloud assertions remain and pass.
- [x] `fleet-agent-forwarding-regression` and its registration are gone.
- [x] ForwardAgent and LocalForward invariants still exist in the broader Fleet tunnel regression.
- [x] Fleet fixture scripts no longer match the standalone test glob.
- [x] Fixture scripts remain syntax-checked and ShellChecked.
- [x] `make check-scripts`, `alejandra --check`, `make lint`, the three scoped Nix checks, and `nix flake check --no-build` pass.
- [x] Backup and recovery production behavior is unchanged; later portability work changed only test fixtures and assertions.
- [x] The four pre-existing user diffs are byte-for-byte unchanged from the captured patch.

## STOP conditions

- A proposed Homepage assertion is the only protection against a secret entering generated configuration.
- Removing a helper would also remove loopback, updater, app-ownership, or secret-exclusion coverage.
- The renamed Fleet fixtures stop running inside their Nix derivations.
- `make check-scripts` no longer syntax-checks or ShellChecks the fixtures.
- Any recovery/backup test appears to require modification.

## Maintenance notes

Configuration tests should focus on service boundaries, exposure, ownership, secrets, recovery, and state. Personal bookmark order and visual arrangement are better reviewed as ordinary configuration diffs.

## Completion notes

Completed on 2026-09-16 after repairing the portable test harness and passing
the mandatory `make check-scripts` gate on both Joyce and Kim.

- Alejandra, `make lint`, `nix flake check --no-build`, and `git diff --check`
  passed. The Homepage, Fleet SSH, and Fleet tunnel `x86_64-linux`
  derivations evaluated successfully.
- The Fleet SSH and tunnel checks built successfully on both
  `aarch64-darwin` and `x86_64-linux`, executing both renamed fixtures. The
  Linux builds ran on Kim from a disposable source snapshot.
- Portable fixtures now validate the production GNU tar, date, chown, and chmod
  interfaces while allowing the tests to run with BSD host tools. Mode checks,
  line-count assertions, temporary-path comparisons, and the Kim-specific
  preflight fixture are portable across macOS and Linux.
- The renamed Fleet fixtures no longer match the direct-run glob, remain
  covered by syntax and ShellCheck, and pass in their owning Nix checks.
- The four protected user diffs remained byte-for-byte identical to the patch
  captured before this plan. Production backup and recovery scripts did not
  change.
