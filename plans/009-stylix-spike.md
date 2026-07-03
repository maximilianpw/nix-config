# Plan 009: Stylix spike — prototype unified theming on two apps, measure the migration cost, report

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat b31e6af..HEAD -- flake.nix flake.lock users/maxpw/modules/xdg.nix users/maxpw/home-manager.nix`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: M (spike; full migration deliberately not in scope)
- **Risk**: LOW (spike is confined to a branch and two apps; trivially revertable)
- **Depends on**: plans/004-lint-format-gate.md and 008 (flake.nix/flake.lock contention; run last among the flake-touching plans)
- **Category**: direction (spike)
- **Planned at**: commit `b31e6af`, 2026-07-03

## Why this matters

Theming for the Linux desktop is hand-maintained per app: ghostty
(`ghostty.linux`), waybar (`users/maxpw/waybar/`), rofi, swaync, wlogout
(with a CSS templating hack), kitty, yazi — each with its own colors. A theme
change means editing 5+ files. Stylix generates coordinated colors/fonts
across app targets from one base16 scheme. Whether that's a win here depends
on how much hand-tuning survives — this spike measures it on two apps and
produces a go/no-go report instead of betting the whole desktop on it.

## Current state

- `users/maxpw/modules/xdg.nix:103-136` — Linux desktop dotfiles are wired
  via `xdg.configFile`:
  ```nix
  "ghostty/config".text = builtins.readFile ../ghostty.linux;
  ...
  "waybar".source = ../waybar;  "waybar".recursive = true;
  "rofi".source = ../rofi;      "swaync".source = ../swaync;
  "wlogout/style.css".text = builtins.replaceStrings ... ;
  ```
- **Collision constraint**: Stylix HM targets write the same
  `xdg.configFile` paths (e.g. waybar CSS). Enabling a stylix target while
  the raw file link remains produces an HM file-collision error. The spike
  must disable/limit stylix `autoEnable` and comment out the colliding lines
  for the two prototype apps only.
- `lib/mksystem.nix` — HM is wired via `homeManagerMods.home-manager`
  (line 59); stylix ships its own HM module which can be imported in
  `users/maxpw/home-manager.nix`'s `imports` list via `inputs.*`
  (`inputs` is available there — see `inputs.nix-index-database.homeModules...`
  at home-manager.nix:19).
- Platform guard convention: xdg.nix uses `isLinuxDesktop` (line 104) —
  the spike config must be Linux-desktop-only the same way.
- Hyprland/waybar deep config quality is covered by plan 001 (separate);
  this spike is only about the *theming mechanism*.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Eval check | `nix flake check --no-build` | exit 0 |
| Apply (on main-pc only) | `make rebuild` | exit 0 |
| Inspect generated ghostty theme | `grep -i "^palette\|background" ~/.config/ghostty/config` | stylix-generated colors |

## Scope

**In scope**:
- `flake.nix` (stylix input, `follows = "nixpkgs"`), `flake.lock`
- `users/maxpw/home-manager.nix` (import stylix HM module, spike config block)
- `users/maxpw/modules/xdg.nix` (comment out ONLY the ghostty + waybar lines during the spike)
- `plans/009-stylix-spike.md` (append `## Spike report`)

**Out of scope**:
- Migrating rofi, swaync, wlogout, kitty, yazi, hyprland, neovim — the spike
  is ghostty + waybar only.
- Deleting any existing theme file — comment out links, never delete sources.
- Darwin/WSL — guard everything with `isLinuxDesktop`.

## Git workflow

- Branch: `advisor/009-stylix-spike` — the spike LIVES on this branch;
  whether it merges is the report's recommendation.
- Commit style: `feat: stylix spike (ghostty + waybar)`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add stylix and a minimal scheme

`flake.nix` inputs:

```nix
stylix.url = "github:nix-vein/stylix/release-26.05";
stylix.inputs.nixpkgs.follows = "nixpkgs";
```

(If the `release-26.05` branch does not exist, check the repo's branches for
the release matching nixpkgs 26.05 — stylix publishes release branches per
NixOS release; use master only if no release branch exists, and note it.
The canonical owner is `nix-community/stylix` — verify with
`nix flake metadata github:nix-community/stylix` and prefer that owner.)

In `users/maxpw/home-manager.nix`: add `inputs.stylix.homeModules.stylix`
(check the exact attr name in stylix's flake — historically
`homeManagerModules.stylix`) to `imports`, and a config block:

```nix
stylix = lib.mkIf (!isDarwin) {
  enable = true;
  autoEnable = false;          # opt-in per target — critical, see xdg.nix collisions
  base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-material-dark-hard.yaml";
  targets.ghostty.enable = true;
  targets.waybar.enable = true;
};
```

Pick any dark scheme close to the current ghostty colors (read
`users/maxpw/ghostty.linux` first and note the current palette in the report).

**Verify**: `nix flake check --no-build` → exit 0.

### Step 2: Disable the colliding raw links

In `users/maxpw/modules/xdg.nix`, comment out (do not delete):
- `"ghostty/config".text = ...` (line 107)
- the two `"waybar"` lines (lines 112-113)

with a `# stylix spike (plan 009):` prefix so they're greppable.

**Verify**: `nix flake check --no-build` → exit 0 (an HM collision would fail eval/build here).

### Step 3: Apply on main-pc, evaluate, report

`make rebuild` on main-pc, restart waybar + open a new ghostty window, then
append `## Spike report` to this file answering:

1. Visual acceptability of ghostty + waybar under stylix (screenshot paths ok).
2. What hand-tuning was lost (waybar has custom module styling in
   `users/maxpw/waybar/` — how much survives when stylix owns the CSS?).
3. Coverage estimate: which of the remaining apps (rofi, swaync, wlogout,
   kitty, yazi, hyprland, gtk) have stylix targets in this version.
4. Recommendation: (a) full migration follow-up plan, (b) partial (stylix for
   colors, keep hand-written layout CSS), (c) revert the spike.

If the recommendation is (c), revert: uncomment the xdg.nix lines, remove the
stylix block + import + input, `nix flake lock`, rebuild.

**Verify**: report section exists with all four answers; final
`nix flake check --no-build` → exit 0 in whatever end state was chosen.

## Test plan

Visual/manual by nature. The eval checks gate correctness; acceptability is
the operator's call from the report.

## Done criteria

- [ ] `## Spike report` appended with the four answers and an (a)/(b)/(c) recommendation
- [ ] `nix flake check --no-build` → exit 0 in the branch's end state
- [ ] No theme source files deleted (`git status` shows modifications/comments only)
- [ ] Darwin/WSL configs unaffected (`nix eval --raw .#darwinConfigurations.macbook-pro-m1.system.drvPath` → exit 0)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- Stylix's module attr names or target names differ from the sketch and the
  correct names aren't findable in the input's source within a few minutes.
- Enabling the two targets triggers collisions beyond ghostty/waybar
  (something else also writes those paths) — report the collision chain.
- Rebuild on main-pc fails after Step 2 — revert the branch, report.

## Maintenance notes

- If (a)/(b) is chosen, the follow-up must decide scheme ownership vs the
  wallpaper (stylix can derive palettes from `stylix.image`) and handle the
  wlogout `@WLOGOUT_ICONS@` substitution hack (xdg.nix:118-122), which stylix
  will not replicate.
- Plan 001 (Hyprland audit) may also propose theming changes — reconcile
  before executing both.
