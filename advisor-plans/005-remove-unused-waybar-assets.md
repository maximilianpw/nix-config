# Plan 005: Remove unused Waybar theme and Cava module assets

> **Executor instructions**: Confirm there is no intentional manual use before deleting. Follow the verification gates and update `advisor-plans/README.md` when complete.
>
> **Drift check (run first)**: `git diff --stat 31341e0 -- users/maxpw/waybar/style.css users/maxpw/waybar/config.jsonc users/maxpw/waybar/modules.jsonc users/maxpw/waybar/themes/kanagawa.css users/maxpw/waybar/scripts/cava.sh users/maxpw/modules/packages/linux-desktop.nix users/maxpw/modules/xdg.nix`
> If dependency plans intentionally changed an in-scope path, reconcile this plan against the new code before proceeding. For any other staged, unstaged, or committed drift, STOP and report instead of applying stale excerpts.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `31341e0`, 2026-09-16

## Why this matters

Home Manager recursively deploys the entire Waybar directory, including an unreferenced Kanagawa palette and an unused Cava visualization script. Removing these files makes the installed configuration match the active configuration and reduces ambiguity about which theme/modules are maintained.

## Current state

- `users/maxpw/modules/xdg.nix:117-118` recursively deploys `users/maxpw/waybar/`.
- `users/maxpw/waybar/style.css:1` imports only:

```css
@import 'themes/mechabar.css';
```

- No tracked source references `themes/kanagawa.css`.
- `users/maxpw/waybar/config.jsonc` lists active modules and does not include a Cava module.
- No tracked source invokes `users/maxpw/waybar/scripts/cava.sh`.
- `users/maxpw/modules/packages/linux-desktop.nix:40` installs `pkgs.cava`; this package could still be used manually, so package removal requires a human-intent check.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Reference scan | `git grep -n -i 'kanagawa.css\|cava.sh\|custom/cava' -- ':!advisor-plans/**'` | no active references |
| Format | `alejandra --check users/maxpw/modules/packages/linux-desktop.nix users/maxpw/modules/xdg.nix` | exit 0 if Nix files changed |
| Nix lint | `make lint` | exit 0 if a Nix file changed |
| Evaluation | `nix flake check --no-build` | exit 0 |
| Diff hygiene | `git diff --check` | exit 0 |

## Scope

**In scope**:
- Delete `users/maxpw/waybar/themes/kanagawa.css`
- Delete `users/maxpw/waybar/scripts/cava.sh`
- `users/maxpw/modules/packages/linux-desktop.nix` only if the user confirms the `cava` CLI/package is not used manually

**Out of scope**:
- Redesigning Waybar
- Changing `themes/mechabar.css`, `style.css`, module order, or previews
- Removing any other desktop package

## Git workflow

- Suggested branch: `advisor/005-waybar-dead-assets`
- Suggested commit: `chore: remove unused Waybar assets`

## Steps

### Step 1: Confirm non-use

Search the repository for both files and relevant module names. Ask the operator whether `cava` is used manually outside Waybar before removing the package.

**Verify**: no source reference exists; operator answer is recorded for package retention/removal.

### Step 2: Delete dead files

Delete the unused stylesheet and script. If manual Cava use is not wanted, also remove `pkgs.cava` from the Linux desktop package list. Otherwise retain the package and mention manual ownership in the completion report.

**Verify**: `git grep` returns no stale references.

### Step 3: Evaluate

Run formatting for modified Nix files, `make lint` if a Nix file changed, then `nix flake check --no-build` and `git diff --check`.

**Verify**: all exit 0.

## Test plan

No new tests. Evaluation proves recursive Home Manager source generation accepts the reduced directory.

## Done criteria

- [ ] Unused Kanagawa stylesheet is deleted.
- [ ] Unused Cava Waybar script is deleted.
- [ ] `pkgs.cava` is removed only with confirmation that manual CLI use is obsolete.
- [ ] No active references remain.
- [ ] Nix formatting and `make lint` pass if the package list changed; evaluation and diff checks pass.

## STOP conditions

- Any active Waybar include/module references either file.
- The operator says Cava is used manually; retain the package.
- Evaluation indicates generated configuration expects one of the deleted files.

## Maintenance notes

Because the Waybar tree is deployed recursively, every tracked file should be presumed installed. Keep alternative themes outside the deployed tree unless they are intentionally selectable.

## Completion notes

Completed on 2026-09-16.

- Deleted only `themes/kanagawa.css` and `scripts/cava.sh`; no active source
  referenced either asset.
- Retained `pkgs.cava` because manual CLI use has not been ruled out.
- `nix flake check --no-build` and `git diff --check` passed. No Nix file
  changed, so Plan 005 did not require formatting or lint reruns.
