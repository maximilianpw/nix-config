# Plan 006: Wire up nix-index + comma properly and keep dev shells in Nushell via nix-your-shell

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat b31e6af..HEAD -- users/maxpw/home-manager.nix users/maxpw/modules/packages/dev-tools.nix users/maxpw/modules/shells.nix`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `b31e6af`, 2026-07-03

## Why this matters

Two half-wired conveniences:

1. The repo imports the `nix-index-database` Home Manager module
   (prebuilt binary→package index) and installs the raw `comma` package, but
   never enables either integration — so `comma` has no prebuilt database to
   look packages up in, and "command not found" package suggestions are off.
   Three lines of config finish the job the inputs were added for.
2. Nushell is the primary interactive shell, but `nix develop` / `nix-shell`
   drop into bash. The config already works around this for fish with the
   `fnix` alias — `nix-your-shell` fixes it properly for nushell (and fish)
   by re-execing the calling shell inside the dev environment.

## Current state

- `users/maxpw/home-manager.nix:18-19`:
  ```nix
  imports = [
    inputs.nix-index-database.homeModules.nix-index
  ```
  Nothing anywhere sets `programs.nix-index.enable` or
  `programs.nix-index-database.comma.enable`
  (`grep -rn "programs.nix-index" users/` → no matches).
- `users/maxpw/modules/packages/dev-tools.nix:44` — `pkgs.comma` in
  `home.packages`.
- The pinned `nix-index-database` input's home module (verified in the input
  source, `home-manager-module.nix`) provides
  `programs.nix-index-database.comma.enable`, which installs a comma wrapped
  to use the prebuilt database. Leaving the raw `pkgs.comma` installed as
  well would put two `comma` binaries in the profile → remove the raw one.
- The pinned home-manager (release-26.05) has
  `modules/programs/nix-your-shell.nix` with `enableNushellIntegration`
  (verified), and pinned nixpkgs has `nix-your-shell` 1.4.10.
- `users/maxpw/modules/shells.nix` — nushell config at lines 93-128
  (`programs.nushell`), fish at 170-200, `fnix = "nix-shell --run fish"`
  alias at line 78 (keep it; harmless).
- Convention: `programs.*` config lives in the topical module —
  shell-related programs (carapace, zoxide, starship) are enabled in
  `users/maxpw/modules/shells.nix:153-168`; follow that pattern for
  nix-your-shell. nix-index is cross-shell infrastructure — put it in
  `home-manager.nix` next to the module import.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Eval check | `nix flake check --no-build` | exit 0 |
| Apply | `make rebuild` | exit 0 |
| comma works | `, hello` | prints "Hello, world!" without a manual index build |
| nix-locate works | `nix-locate --top-level bin/hello \| head -1` | a `hello.out` line, instantly (prebuilt db) |
| dev shell stays in nu (run from nushell) | `nix develop nixpkgs#hello -c $env.SHELL` — simpler: `nix-shell -p hello` then `echo $nu.home-path` | you are in nushell, not bash |

## Scope

**In scope** (the only files you should modify):
- `users/maxpw/home-manager.nix`
- `users/maxpw/modules/packages/dev-tools.nix` (remove one line)
- `users/maxpw/modules/shells.nix`

**Out of scope**:
- `flake.nix` — no new inputs needed; everything is already pinned.
- The `fnix` alias (shells.nix:78) — keep it.
- `programs.command-not-found` — the nix-index HM module handles the
  shell-integration side itself; don't add manual hooks.

## Git workflow

- Branch: `advisor/006-comma-nix-your-shell`
- Commit style: conventional (`feat: wire nix-index database and comma`, `feat: keep dev shells in nushell via nix-your-shell`).
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Enable nix-index + comma

In `users/maxpw/home-manager.nix`, in the top-level returned attrset (e.g.
after the `programs.direnv` block at lines 63-66), add:

```nix
programs.nix-index.enable = true;
programs.nix-index-database.comma.enable = true;
```

In `users/maxpw/modules/packages/dev-tools.nix`, delete line 44
(`pkgs.comma`) — the comma.enable option installs a wrapped comma and two
copies would collide in the profile.

**Verify**: `nix flake check --no-build` → exit 0, and
`grep -n "pkgs.comma" users/maxpw/modules/packages/dev-tools.nix` → no matches.

### Step 2: Enable nix-your-shell

In `users/maxpw/modules/shells.nix`, next to the other `programs.*` blocks
(after `programs.starship`, line 166-168), add:

```nix
programs.nix-your-shell = {
  enable = true;
  enableNushellIntegration = true;
  enableFishIntegration = true;
};
```

If `enableFishIntegration` doesn't exist as an option (check with the eval in
Verify), drop that line — nushell is the one that matters.

**Verify**: `nix flake check --no-build` → exit 0.

### Step 3: Apply and functionally verify

`make rebuild`, then **in a fresh nushell**:

1. `, hello` → runs GNU hello without prompting to build an index.
2. `nix-locate --top-level bin/rg | head -1` → returns instantly with a
   ripgrep line (prebuilt database present).
3. `nix-shell -p hello` → the shell you land in is nushell
   (`version | get build_os` works / prompt is your starship nu prompt), and
   `hello` is on PATH.
4. `exit`, then in fish: `nix-shell -p hello` → lands in fish (if fish
   integration was enabled).

## Test plan

Step 3 is the functional test. Record the four outcomes in the completion
report. There is no CI coverage for runtime shell behavior — eval checks
(`nix flake check`) are the merge gate.

## Done criteria

- [ ] `nix flake check --no-build` → exit 0
- [ ] `programs.nix-index.enable` and `programs.nix-index-database.comma.enable` set in `home-manager.nix`; raw `pkgs.comma` removed from dev-tools.nix
- [ ] `programs.nix-your-shell` enabled in shells.nix with nushell integration
- [ ] After rebuild: `, hello` works; `nix-shell -p hello` from nushell lands in nushell
- [ ] `git status` shows only the three in-scope files modified
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The rebuild reports a package collision on `comma` — you missed a second
  installation site; `grep -rn comma users/ modules/` and report.
- `programs.nix-your-shell` doesn't exist in this home-manager version
  (eval error "option does not exist") — the pin moved; report instead of
  vendoring the module.
- After rebuild, `nix-shell -p hello` from nushell still lands in bash —
  check that `~/.config/nushell/config.nu` sources the nix-your-shell hook
  (the HM module appends it); if the custom `configFile.source = ../config.nu`
  in shells.nix:96 overrides HM's generated additions, report this conflict —
  resolving custom-config-vs-module-generated-config layering is an operator
  decision.

## Maintenance notes

- The custom `config.nu` (shells.nix:96) is the most likely source of
  surprises — HM modules add nushell integration via `extraConfig`-style
  snippets, and load order matters. The third STOP condition covers it.
- comma cache: comma uses the prebuilt index from nix-index-database, updated
  weekly upstream; `nix flake update nix-index-database` refreshes it.
- Reviewer: the whole diff should be ~10 lines plus one deletion.
