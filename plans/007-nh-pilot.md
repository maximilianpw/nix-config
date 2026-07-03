# Plan 007: Pilot `nh` as a partial replacement for the custom rebuild script (spike — report, minimal install)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat b31e6af..HEAD -- scripts/nixos-rebuild.sh users/maxpw/modules/packages/terminal-tools.nix Makefile`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: M (mostly evaluation, small diff)
- **Risk**: LOW (nothing existing is removed in this plan)
- **Depends on**: none
- **Category**: direction (spike)
- **Planned at**: commit `b31e6af`, 2026-07-03

## Why this matters

`scripts/nixos-rebuild.sh` is 247 lines of custom bash handling platform
detection, formatting, build, switch, generation reporting, optional commit,
and GC. `nh` (nix helper, 4.3.2 in the pinned nixpkgs) is the community
-standard wrapper providing `nh os switch` / `nh darwin switch` with tree
-formatted build output, an automatic **nvd generation diff** (exactly which
packages changed and versions, after every switch — something the script
doesn't do at all), and policy-based GC (`nh clean all --keep 5`). This spike
answers: what can nh replace, what must stay custom, and is the trade worth
it? The deliverable is a **written recommendation plus nh installed and
aliased for side-by-side use** — NOT the removal of the script.

## Current state

- `scripts/nixos-rebuild.sh` responsibilities (line refs):
  - user→host mapping + platform/WSL detection (83-124)
  - /etc/nixos symlink upkeep (145-154)
  - optional `nix flake check` (157-169), alejandra format (172-177), diff preview (180-185)
  - build (188-197) + switch via `sudo -H nixos-rebuild|darwin-rebuild switch` (200-213), log to `nixos-switch.log`
  - generation report (219-220), optional `--commit` with generation message (223-237)
  - GC: `nix-collect-garbage --delete-older-than 30d` (240-245)
- `Makefile` `rebuild` target wraps this script; the `nr` shell alias runs
  `make -C ~/nix-config rebuild` (users/maxpw/modules/shells.nix:72).
- `nh` 4.3.2 exists in the pinned nixpkgs (verified 2026-07-03). NixOS ships
  a `programs.nh` module (with `clean` options); check whether the pinned
  nix-darwin has one too (`programs.nh` may be NixOS-only — the spike
  determines this).
- Hosts: main-pc (NixOS), macbook-pro-m1 (nix-darwin + Determinate daemon,
  `nix.enable = false` — machines/macbook-pro-m1.nix:20), wsl (NixOS).
- Repo conventions: user CLI packages go in
  `users/maxpw/modules/packages/terminal-tools.nix`; aliases in
  `users/maxpw/modules/shells.nix`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Eval check | `nix flake check --no-build` | exit 0 |
| Dry-run switch (NixOS) | `nh os switch -n ~/nix-config` | prints build plan, changes nothing |
| Dry-run switch (darwin) | `nh darwin switch -n ~/nix-config` | prints build plan, changes nothing |
| Real switch comparison | `nh os switch ~/nix-config` (or `darwin`) | switch succeeds + nvd diff printed |
| GC preview | `nh clean all --dry --keep 5 --keep-since 30d` | lists what would be deleted |

## Scope

**In scope**:
- `users/maxpw/modules/packages/terminal-tools.nix` (add `pkgs.nh`)
- `users/maxpw/modules/shells.nix` (add trial aliases)
- `plans/007-nh-pilot.md` (append the findings report to this file under "## Spike report")

**Out of scope**:
- Deleting or modifying `scripts/nixos-rebuild.sh` — explicitly deferred.
- Changing the `Makefile` `rebuild` target or the `nr` alias.
- Enabling `programs.nh` NixOS/darwin modules with clean schedules —
  recommend in the report if warranted; don't enable yet.

## Git workflow

- Branch: `advisor/007-nh-pilot`
- Commit style: `feat: add nh for rebuild pilot`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Install nh and trial aliases

Add `pkgs.nh` to `home.packages` in `terminal-tools.nix` (System utilities
section, near `btop`). In `shells.nix` `shellAliases`, next to `nr`/`nup`
(lines 71-73), add:

```nix
# nh rebuild pilot (plan 007) — side-by-side with `nr`
nhs = "nh os switch ~/nix-config";
```

On darwin the command is `nh darwin switch`; since aliases are shared across
platforms, use the platform-neutral form if nh supports it (`nh os` errors on
darwin — check `nh --help`; if there is no neutral form, define the alias as
the NixOS variant and note in the report that darwin needs `nh darwin`).

**Verify**: `nix flake check --no-build` → exit 0; after `make rebuild`,
`nh --version` → `nh 4.3.2` (or newer).

### Step 2: Exercise nh on the current platform

Run and record output of:
1. `nh os switch -n ~/nix-config` (dry) — or `nh darwin switch -n` on the Mac.
2. A real switch with a trivial change (e.g. after plan 006 lands, or add a
   comment to a module): does the nvd diff correctly show changed packages?
3. `nh clean all --dry --keep 5 --keep-since 30d` — compare against the
   script's `nix-collect-garbage --delete-older-than 30d`.
4. `nh search ripgrep` — bonus utility the script has no equivalent for.

**Verify**: each command exits 0; capture outputs for the report.

### Step 3: Write the spike report

Append `## Spike report` to this plan file answering:
- Which of the script's 8 responsibilities (see Current state) nh covers /
  doesn't (expected gaps: user→host mapping, /etc/nixos symlink, alejandra
  format, auto-commit, log file).
- Darwin support quality (does `nh darwin switch` work with the Determinate
  daemon / `sudo` handling?).
- Recommendation: one of (a) adopt nh as the switch+GC engine inside the
  script, (b) adopt nh aliases alongside untouched script, (c) drop nh.
  With a 2-3 sentence rationale.

**Verify**: the section exists and answers all three questions.

## Test plan

The spike's exercise steps are the test. Nothing existing changes behavior:
the only durable diff is one package and one alias.

## Done criteria

- [ ] `nh --version` works after rebuild
- [ ] `nhs` alias defined; `nix flake check --no-build` → exit 0
- [ ] Dry-run, real switch, and clean-dry outputs recorded
- [ ] `## Spike report` appended to this file with a clear (a)/(b)/(c) recommendation
- [ ] `scripts/nixos-rebuild.sh`, `Makefile` untouched (`git diff --stat` confirms)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- `nh os switch` (or `darwin`) errors in a way suggesting daemon or sudo
  incompatibility on the Mac (Determinate-managed daemon) — record the error
  in the report as the darwin answer, and continue with the Linux evaluation
  only; do NOT attempt to reconfigure the Nix daemon.
- A real switch via nh leaves the system in an unexpected generation —
  `make rollback` and report.

## Maintenance notes

- If the recommendation is (a), a follow-up plan should refactor
  `nixos-rebuild.sh` to delegate build/switch/GC to nh while keeping mapping,
  format, and commit logic — do not do it in this plan.
- `nh clean` policies (`--keep 5`) are generation-count-based; the current
  script is purely age-based. If both run, the stricter one wins — harmless.

## Spike report

### Script responsibility coverage

`nh` covers the build/switch engine and adds the useful nvd-style package diff
that the custom script does not currently provide. The dry-run on this Mac
showed the expected package diff, including `nh 4.3.2`, `nh-unwrapped 4.3.2`,
and `nix-output-monitor 2.1.8`.

`nh` does not cover the custom script's user-to-host mapping, `/etc/nixos`
symlink upkeep, `nix flake check` gate, alejandra formatting, source diff
preview, optional auto-commit, generation log file, or generation-report
wrapper behavior. It can handle GC policy in principle via `nh clean all
--keep 5 --keep-since 30d`, but the exact dry-run command tried to invoke
`sudo` in this non-interactive session and failed before listing deletions.

### Darwin support

`nh darwin switch -n ~/nix-config` does not work out of the box here because
`nh` infers the machine hostname as `Maximilians-MacBook-Pro`, while the flake
exports `darwinConfigurations.macbook-pro-m1`. The same dry-run succeeds with
`-H macbook-pro-m1`, which means Darwin support is usable only if the caller
supplies the configured host name or the script keeps doing that mapping.

No Determinate-daemon or switch-time sudo incompatibility was observed because
no real switch was run. The successful dry-run printed `> Activating
configuration`, but `/run/current-system` remained
`/nix/store/bgh6rghw43nvlbdiv9zib1gvalvvh6h6-darwin-system-26.05.adda04f`,
so the `-n` run did not switch the system. `nix-darwin` in this flake does not
expose `programs.nh` (`nix eval` could not resolve
`darwinConfigurations.macbook-pro-m1.options.programs.nh`), while the NixOS
configuration exposes `programs.nh.enable` as a boolean option.

### Recommendation

(b) Adopt `nh` aliases alongside the untouched script for now. `nh` is useful
for readable build output, package diffs, search, and an eventual GC policy,
but the custom script still carries important repo-specific behavior: host
mapping, formatting/check gates, symlink upkeep, commit/log behavior, and
non-interactive ergonomics. A follow-up can revisit using `nh` inside the
script after the Mac host mapping and clean/sudo behavior are designed
explicitly.

### Verification output notes

Drift check:

```text
 users/maxpw/modules/packages/terminal-tools.nix | 7 +++++++
 1 file changed, 7 insertions(+)
```

The drift was compatible with the plan: it only added network/remote-access
packages, and the `System utilities` section near `pkgs.btop` still existed.

`nix flake check --no-build` exited 0. The output included the existing SSH
option deprecation warnings and ended with:

```text
checking flake output 'devShells'...
checking derivation devShells.aarch64-darwin.default...
derivation evaluated to /nix/store/4zc9j61259i7n3nnladkc3n3lwwjbm7c-nix-shell.drv
warning: The check omitted these incompatible systems: aarch64-linux, x86_64-linux
Use '--all-systems' to check all.
```

`nix shell nixpkgs#nh -c nh --version`:

```text
nh 4.3.2
```

`nix shell nixpkgs#nh -c nh darwin switch -n ~/nix-config` exited 1:

```text
> Building Darwin configuration
warning: Git tree '/Users/max-vev/nix-config' has uncommitted changes
error: flake 'git+file:///Users/max-vev/nix-config' does not provide attribute 'packages.aarch64-darwin.darwinConfigurations.Maximilians-MacBook-Pro.config.system.build.toplevel', 'legacyPackages.aarch64-darwin.darwinConfigurations.Maximilians-MacBook-Pro.config.system.build.toplevel' or 'darwinConfigurations.Maximilians-MacBook-Pro.config.system.build.toplevel'
Error:
   0: Failed to build Darwin configuration
   1: Command exited with status ExitStatus(Exited(1))
```

`nix shell nixpkgs#nh -c nh darwin switch -n --no-nom -H macbook-pro-m1
~/nix-config` exited 0. The compact rerun output included:

```text
> Building Darwin configuration
warning: Git tree '/Users/max-vev/nix-config' has uncommitted changes
<<< /run/current-system
>>> /nix/store/bq2lirfdvcsgnip6ddpzjxr3l5y6rb48-darwin-system-26.05.adda04f

CHANGED
[C.] comma                             2.4.1-fish-completions, <others> -> <others>
[C.] rsync                             <others> -> 3.4.4-fish-completions, <others>

ADDED
[A.] autossh                           1.4g, 1.4g-fish-completions
[A.] mosh                              1.4.0, 1.4.0-fish-completions
[A.] nh                                4.3.2, 4.3.2-fish-completions
[A.] nh-unwrapped                      4.3.2
[A.] nix-output-monitor                2.1.8
[A.] sshfs-fuse                        3.7.6, 3.7.6-fish-completions, 3.7.6-man

REMOVED
[R.] hm_config.yaml                    <none>

SIZE: 13.4 GiB -> 13.5 GiB
DIFF: 101 MiB
> Activating configuration
```

`readlink /run/current-system` after the dry-run:

```text
/nix/store/bgh6rghw43nvlbdiv9zib1gvalvvh6h6-darwin-system-26.05.adda04f
```

Real switch: not run, because the dispatcher explicitly prohibited system
switches for this execution.

`nix shell nixpkgs#nh -c nh clean all --dry --keep 5 --keep-since 30d` exited
1:

```text
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
```

`nix shell nixpkgs#nh -c nh -e none clean all --dry --keep 5 --keep-since 30d`
exited 101:

```text
The application panicked (crashed).
Message:  Failed to create self-elevation command:
   0: Failed to resolve elevation program
   1: Elevation disabled via --elevation-strategy=none

Location:
   crates/nh-core/src/command.rs:220
Location: crates/nh-core/src/util.rs:372

Please report the bug at https://github.com/nix-community/nh/issues
```

`nix shell nixpkgs#nh -c nh search ripgrep` exited 0 and ended with:

```text
ripgrep (15.1.0)
  Utility that combines the usability of The Silver Searcher with the raw speed
  of grep
  Homepage: https://github.com/BurntSushi/ripgrep
  Defined at: pkgs/by-name/ri/ripgrep/package.nix
  GitHub link: https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/ri/ripgrep/package.nix
```
