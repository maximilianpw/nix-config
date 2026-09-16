# Plan 001: Replace the temporary Jellyfin package forks with locked nixpkgs-unstable packages

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving on. If a STOP condition occurs, stop and report rather than improvising. When complete, update this plan's row in `advisor-plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 31341e0 -- flake.nix packages/jellyfin.nix packages/jellyfin-web.nix packages/jellyfin-ffmpeg.nix packages/jellyfin/nuget-deps.json tests/media-stack-regression.nix docs/media-stack.md`
> This command includes committed, staged, and unstaged changes. If any in-scope file has drifted for reasons other than an explicitly completed prerequisite, STOP and report instead of applying stale excerpts.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: MED
- **Depends on**: none
- **Category**: dependencies
- **Planned at**: commit `31341e0`, 2026-09-16

## Why this matters

The repository carries copied Jellyfin 12 package definitions only because the pinned package set did not previously contain that release. The locked `nixpkgs-unstable` input now evaluates to Jellyfin 12.0, Jellyfin Web 12.0, and Jellyfin FFmpeg 8.1.2-4—the same versions as the local overrides. Switching to the upstream derivations removes three hand-maintained package files and an 887-line generated NuGet dependency file.

## Current state

- `flake.nix:97-122` exposes `unstable` but still overlays local Jellyfin packages:

```nix
unstable = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system};
...
# Keep Jellyfin's server, web client, and patched FFmpeg together until
# nixpkgs carries 12.0. Remove these overrides as one upgrade.
jellyfin = final.callPackage ./packages/jellyfin.nix {};
jellyfin-web = final.callPackage ./packages/jellyfin-web.nix {inherit (prev) jellyfin-web;};
jellyfin-ffmpeg = final.callPackage ./packages/jellyfin-ffmpeg.nix {};
```

- `packages/jellyfin.nix` pins server `12.0.0` and uses `packages/jellyfin/nuget-deps.json`.
- `packages/jellyfin-web.nix` pins web `12.0.0`.
- `packages/jellyfin-ffmpeg.nix` pins `8.1.2-4`.
- A read-only evaluation at planning time returned:

```json
{"jellyfin":"12.0","jellyfin-ffmpeg":"8.1.2-4","jellyfin-web":"12.0"}
```

- `tests/media-stack-regression.nix` already checks that server, web, and FFmpeg remain a compatible set. Preserve that contract.

Repository convention: custom overlays live in the second overlay function in `flake.nix`; use the existing `unstable` binding rather than importing nixpkgs again.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Confirm upstream versions | `nix eval --impure --json --expr 'let f = builtins.getFlake ("git+file://" + toString ./.); p = f.inputs.nixpkgs-unstable.legacyPackages.x86_64-linux; in { jellyfin = p.jellyfin.version; jellyfin-web = p.jellyfin-web.version; jellyfin-ffmpeg = p.jellyfin-ffmpeg.version; }'` | JSON reports Jellyfin 12.0, web 12.0, FFmpeg 8.1.2-4 or newer mutually compatible versions |
| Format | `alejandra --check flake.nix tests/media-stack-regression.nix` | exit 0 |
| Nix lint | `make lint` | exit 0 |
| Targeted regression | `nix build .#checks.x86_64-linux.media-stack-regression --no-link` | exit 0 |
| Host build | `nix build .#nixosConfigurations.kim.config.system.build.toplevel --no-link` | exit 0 |
| Diff hygiene | `git diff --check` | exit 0 |

## Scope

**In scope**:
- `flake.nix`
- `packages/jellyfin.nix` (delete)
- `packages/jellyfin-web.nix` (delete)
- `packages/jellyfin-ffmpeg.nix` (delete)
- `packages/jellyfin/nuget-deps.json` and now-empty directory (delete)
- `tests/media-stack-regression.nix` only if an assertion must be made implementation-neutral while preserving the compatibility contract
- `docs/media-stack.md` only to replace the obsolete local-package/NuGet instructions in the Jellyfin 12 upgrade section with locked-upstream package ownership; preserve migration and activation warnings

**Out of scope**:
- Jellyfin service configuration, state, migration, activation, or live host operations
- Version upgrades beyond the locked upstream packages
- Changes to media paths, users, permissions, or transcoding policy

## Git workflow

- Suggested branch: `advisor/001-upstream-jellyfin`
- Use a focused commit such as `refactor: use upstream Jellyfin packages`.
- Do not push, deploy, rebuild-switch, or operate Kim.

## Steps

### Step 1: Reconfirm the upstream package set

Run the version evaluation command above. Also inspect `inputs.nixpkgs-unstable.legacyPackages.x86_64-linux` to confirm all three attributes exist.

**Verify**: the command exits 0 and the versions are compatible with the current `tests/media-stack-regression.nix` contract.

### Step 2: Redirect the overlay

In `flake.nix`, replace the three `callPackage` expressions with explicit aliases to the already-bound `unstable` set. Keep the three names (`jellyfin`, `jellyfin-web`, `jellyfin-ffmpeg`) unchanged so consumers do not change.

Target shape:

```nix
inherit (unstable) jellyfin jellyfin-web jellyfin-ffmpeg;
```

Update the adjacent comment so it explains that these packages intentionally move together from unstable; remove the obsolete “until nixpkgs carries 12.0” wording.

**Verify**: `nix eval --raw .#packages.x86_64-linux.jellyfin.version` exits 0 and reports the upstream version.

### Step 3: Delete the local package copies

Delete the three package files and `packages/jellyfin/nuget-deps.json`. Remove the `packages/jellyfin/` directory if empty. Search for references to the deleted paths.

**Verify**: `git grep -n 'packages/jellyfin\|./jellyfin.nix\|./jellyfin-web.nix\|./jellyfin-ffmpeg.nix' -- ':!advisor-plans/**'` returns no stale source references.

### Step 4: Update the active Jellyfin upgrade runbook

In `docs/media-stack.md`, preserve the Jellyfin 12 database migration, plugin, compatibility, build-without-activation, and rollback warnings. Replace only the paragraph claiming the three local package files and generated NuGet manifest are current. State that the coordinated server/web/FFmpeg packages come from the locked `nixpkgs-unstable` input and should still be upgraded together.

**Verify**: `git grep -n 'packages/jellyfin\|nuget-deps.json' -- docs/media-stack.md` returns no matches.

### Step 5: Preserve the compatibility regression

Run the media regression. If it fails only because assertions depend on local derivation internals, rewrite those assertions to verify observable requirements: the configured server package is the overlay package, server/web versions remain compatible, FFmpeg stays at the required major version, and state paths remain unchanged. Do not claim or test transitive dependency linkage unless the upstream derivation exposes a stable passthru for it. Do not weaken service security, storage, or media behavior assertions.

**Verify**: `nix build .#checks.x86_64-linux.media-stack-regression --no-link` exits 0.

### Step 6: Build Kim without activation

Build the system closure to prove the upstream packages compose with the complete host.

**Verify**: `nix build .#nixosConfigurations.kim.config.system.build.toplevel --no-link` exits 0. Do not run `nixos-rebuild switch`.

## Test plan

No new test file is expected. The existing media-stack regression is the acceptance test. If it reveals an implementation-specific assertion, preserve the same behavior using upstream-neutral assertions.

## Done criteria

- [ ] `flake.nix` sources all three Jellyfin packages from the locked unstable input.
- [ ] The local Jellyfin package files and generated NuGet dependency file are deleted.
- [ ] No source or active-runbook references to the deleted paths remain.
- [ ] Jellyfin migration/activation warnings remain in `docs/media-stack.md`.
- [ ] `alejandra --check flake.nix tests/media-stack-regression.nix` exits 0.
- [ ] `make lint` exits 0.
- [ ] The media regression builds successfully.
- [ ] The Kim system closure builds successfully without activation.
- [ ] No unrelated files are modified.

## STOP conditions

- Upstream no longer provides all three coupled packages.
- The upstream server/web major versions differ.
- Passing the regression would require weakening runtime sandbox, media permissions, or transcoding assertions.
- The host build reveals a state migration or live activation requirement.

## Maintenance notes

Future Jellyfin upgrades should update the locked upstream input rather than reintroducing copied derivations. Reviewers should confirm that the server, web client, and patched FFmpeg still move as a compatible unit.

## Completion notes

Completed on 2026-09-16.

- The locked upstream package versions evaluate as Jellyfin 12.0, Jellyfin Web
  12.0, and Jellyfin FFmpeg 8.1.2-4.
- Alejandra, `make lint`, `nix flake check --no-build`, and `git diff --check`
  passed. `nix flake check --no-build --all-systems` evaluated the
  `media-stack-regression`, `eval-kim`, and all three upstream Jellyfin package
  outputs successfully. The command later failed in the separate
  `eval-kim-desktop` check because a referenced Nix store path was invalid.
- The initial `x86_64-linux` media regression and Kim system closure checks were
  environment-limited on `aarch64-darwin`. Later current-tree verification for
  Plan 006 built both successfully on Kim from a disposable source snapshot:
  `/nix/store/5lx0rdxsxqnjicnkf0hbsppdc6gwma93-media-stack-regression.drv` and
  `/nix/store/xrp7pnkn7ffi5f81f21mh3r8nsj09kgc-nixos-system-kim-26.05.20260911.21a67dc.drv`.
  No configuration was activated by those builds.
