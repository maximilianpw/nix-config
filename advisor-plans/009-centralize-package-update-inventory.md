# Plan 009: Centralize the repo-local package update inventory

> **Executor instructions**: Preserve the intentional behavior difference between local best-effort updates and CI failure reporting. Centralize only the package list and shared invocation shape. Update `advisor-plans/README.md` when complete.
>
> **Drift check (run first)**: `git diff --stat 31341e0 -- Makefile scripts/ci/update-packages.sh .github/workflows/update-packages.yml flake.nix packages/*.nix`
> If dependency plans intentionally changed an in-scope path, reconcile this plan against the new code before proceeding. For any other staged, unstaged, or committed drift, STOP and report instead of applying stale excerpts.

## Status

- **Status**: DONE
- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: Plan 001, because removing local Jellyfin definitions confirms the final set of update-managed custom packages
- **Category**: dx
- **Planned at**: commit `31341e0`, 2026-09-16

## Why this matters

The default custom-package list is duplicated in `Makefile` and the GitHub Actions workflow, while local and CI update loops live in separate places. A package addition/removal can silently produce different update coverage. One repo-owned source of truth will make local and scheduled updates agree without forcing identical error handling.

## Current state

- `Makefile:60` hardcodes:

```make
for pkg in helium obsidian cliproxyapi cua-driver nextcloud-calendar tunarr; do \
```

- `.github/workflows/update-packages.yml:22` repeats the same list in `DEFAULT_PACKAGES` and calls it the single source of truth.
- `scripts/ci/update-packages.sh` reads `PACKAGES` or `DEFAULT_PACKAGES`, loops through packages, and records failures in `$GITHUB_OUTPUT`.
- Local `make update-packages` is intentionally best-effort because Linux-only packages may not build/update on macOS.
- CI intentionally records failed package names while continuing so successful bumps can still produce a PR.

## Target design

Use this exact design:

- Create `scripts/ci/update-packages-list.txt`, one package name per non-empty line and no inline comments.
- Extend `scripts/ci/update-packages.sh` with one optional `--local` argument.
- In both modes, `PACKAGES` remains a space-separated override. When unset/empty, read the ordered defaults from the list file.
- Default (CI) mode continues collecting failures and writing `failed_packages` to `$GITHUB_OUTPUT`.
- `--local` mode continues after failures, prints `(skipped: <package>)`, and exits 0 after attempting all packages.
- `make update-packages` prints its existing explanatory text and invokes `scripts/ci/update-packages.sh --local`.
- The workflow removes `DEFAULT_PACKAGES`; it passes only the optional dispatch input as `PACKAGES`.

Do not derive the list from all flake package outputs because some outputs come from inputs or are not managed by `nix-update` here.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Shell syntax | `bash -n scripts/ci/update-packages.sh scripts/tests/update-packages-test.sh` | exit 0 |
| ShellCheck | `shellcheck --severity=warning scripts/ci/update-packages.sh scripts/tests/update-packages-test.sh` | exit 0 |
| Default list | `scripts/ci/update-packages.sh --print-defaults` | prints the six expected names, one per line |
| Focused regression | `bash scripts/tests/update-packages-test.sh` | exit 0 |
| Script suite | `make check-scripts` | exit 0 |
| Diff hygiene | `git diff --check` | exit 0 |

## Scope

**In scope**:
- `Makefile`
- `scripts/ci/update-packages.sh`
- `.github/workflows/update-packages.yml`
- Create `scripts/ci/update-packages-list.txt`
- Create `scripts/tests/update-packages-test.sh`

**Out of scope**:
- Running `nix-update` against every package during implementation
- Changing workflow schedule, permissions, PR behavior, or activation policy
- Updating package versions or `flake.lock`
- Including packages supplied by `llm-agents`
- Making local updates fail hard on an unsupported platform

## Git workflow

- Suggested branch: `advisor/009-update-inventory`
- Suggested commit: `refactor: centralize package update inventory`

## Steps

### Step 1: Create the shared package list

Create `scripts/ci/update-packages-list.txt` with exactly one package per line, no comments or blanks. Preserve this exact logical set after Plan 001:

- helium
- obsidian
- cliproxyapi
- cua-driver
- nextcloud-calendar
- tunarr

If the actual package set has changed, reconcile against `packages/*.nix`, `flake.nix`, and existing update-script support rather than guessing.

Add `--print-defaults` to `scripts/ci/update-packages.sh`; it must print the normalized list and exit without invoking Nix.

**Verify**: `scripts/ci/update-packages.sh --print-defaults` prints exactly six lines in the order above.

### Step 2: Make local updates consume the shared list

Change `make update-packages` to invoke `scripts/ci/update-packages.sh --local`. Preserve the explanatory macOS/Linux note. In the script, local mode must attempt every selected package with the existing `nix run .#nix-update -- --flake --use-update-script` invocation, print `(skipped: <package>)` for failures, and exit 0 after the loop.

**Verify**: the focused regression test uses a fake `nix` on PATH and proves all defaults are attempted after one injected failure.

### Step 3: Make CI consume the same list

Remove the workflow `DEFAULT_PACKAGES` environment entry. Keep workflow-dispatch `packages` as an override and pass it as `PACKAGES`. In default script mode, load the file when `PACKAGES` is empty and continue writing `failed_packages` to `$GITHUB_OUTPUT`.

**Verify**: the focused regression uses a fake `nix` and temporary `GITHUB_OUTPUT` to confirm failure collection and continued attempts.

### Step 4: Add a regression test

Create `scripts/tests/update-packages-test.sh`. It must verify:

- `--print-defaults` order/content;
- explicit `PACKAGES` override in both modes;
- all items are attempted after a middle failure;
- CI mode writes the failed package to a temporary `GITHUB_OUTPUT`;
- local mode prints the skipped package and exits 0;
- unknown CLI arguments fail nonzero.

Follow existing shell test conventions so `make check-scripts` discovers it.

**Verify**: the new test and `make check-scripts` pass.

## Test plan

Use fake commands and temporary files; no network or real package updates. Assert exact attempted package names and failure output.

## Done criteria

- [x] One repository-owned source defines the default update package list.
- [x] Make and GitHub Actions consume that source.
- [x] Dispatch overrides still work.
- [x] Local unsupported-package failures remain best-effort.
- [x] CI still records failed package names and continues.
- [x] Shell syntax, ShellCheck, and regression tests pass.
- [x] No package or lockfile was updated as a side effect.

## STOP conditions

- A listed package lacks a compatible `nix-update` update script and is intentionally handled elsewhere.
- Centralization would require parsing `flake.nix` with fragile text matching.
- Tests cannot avoid running real network/package updates.
- Workflow behavior would need permission, schedule, or PR-policy changes.

## Maintenance notes

When adding a repo-local package, reviewers should decide explicitly whether it belongs in the shared update inventory. Packages coming from flake inputs remain updated through input updates, not this list.

## Completion notes

Completed on 2026-09-16 after the portable test-harness fixes made the
mandatory `make check-scripts` gate pass on both Joyce and Kim.

- The shared list contains the planned six packages. Make and GitHub Actions now
  use that list while `PACKAGES` remains an override.
- Shell syntax, ShellCheck, the focused fake-`nix` regression, `make lint`,
  `nix flake check --no-build`, and `git diff --check` passed. No real package
  update or network request ran.
- The full suite reaches and passes the package update inventory regression on
  macOS with BSD host tools and on x86_64 Linux with GNU host tools. The Kim run
  used the repository's Nix development shell to supply ShellCheck.
