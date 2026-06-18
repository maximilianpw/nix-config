# Plan 001: Audit Hyprland upstream changes and config inspiration

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report - do not improvise. When done, update the status row for this plan
> in `plans/README.md` unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat e35642f..HEAD -- flake.nix flake.lock modules/desktop/hyprland.nix users/maxpw/hyprland users/maxpw/waybar users/maxpw/modules/xdg.nix users/maxpw/modules/packages/linux-desktop.nix users/maxpw/wlogout docs/hardware-issues.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `e35642f`, 2026-06-18

## Why this matters

This repo tracks Hyprland from the upstream flake input, so the desktop can move faster than stable NixOS packages and can inherit breaking config changes. Hyprland 0.53 through 0.55 introduced material config changes, Lua-first docs, layout changes, color-management features, new window-rule options, and ecosystem shifts. The audit should separate required compatibility work from optional "config inspiration" so later implementation is deliberate rather than ricing-by-copy-paste.

## Current state

Relevant files and roles:

- `flake.nix` - declares `hyprland.url = "github:hyprwm/Hyprland"` and wires the upstream package.
- `flake.lock` - currently locks Hyprland to rev `88262e1f860adc56f528ef68b2909ee33a27186b`, last modified `2026-06-15 19:21:34 UTC`.
- `modules/desktop/hyprland.nix` - enables Hyprland, `start-hyprland` through greetd, UWSM, and upstream xdg-desktop-portal-hyprland.
- `users/maxpw/modules/xdg.nix` - links the Hyprland config into `~/.config/hypr` and generates host-specific lock/idle behavior.
- `users/maxpw/hyprland/` - Lua Hyprland config split into monitors, variables, animations, autostart, keybinds, and rules.
- `users/maxpw/modules/packages/linux-desktop.nix` - installs Wayland desktop tools such as waybar, hyprpaper, hypridle, and conditionally hyprlock.
- `users/maxpw/wlogout/layout` - power menu actions; currently includes lock and hibernate actions.
- `docs/hardware-issues.md` - records main-pc GPU/idle/sleep issues. Read this before proposing idle, DPMS, hibernate, or lock-screen changes.

Current excerpts to confirm before auditing:

```nix
# flake.nix:14
hyprland.url = "github:hyprwm/Hyprland";
```

```nix
# modules/desktop/hyprland.nix:21-27
programs.hyprland = {
  enable = true;
  package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  withUWSM = true;
  xwayland.enable = true;
};
```

```lua
-- users/maxpw/hyprland/conf/keybinds.lua:10-16
hypr.combo_binds(mod, {
	{ "Return", dsp.exec_cmd("ghostty") },
	{ "Q", dsp.window.close() },
	{ "F", dsp.window.fullscreen({ action = "toggle" }) },
	{ "D", dsp.window.float({ action = "toggle" }) },
	{ "S", dsp.layout("togglesplit") },
	{ "SHIFT + S", dsp.window.pseudo() },
})
```

```lua
-- users/maxpw/hyprland/conf/windowrules.lua:84-92
hypr.workspace_rules({
	{ workspace = "1", default_name = "term", persistent = true },
	{ workspace = "2", default_name = "web", persistent = true },
	{ workspace = "3", persistent = true, layout = "master" },
	{ workspace = "4", persistent = true },
	{ workspace = "5", persistent = true },
	-- Keep the normal outer gap for single-window workspaces so there is
	-- visible separation between tiled windows and the top Waybar layer.
	{ workspace = "f[1]s[false]", gaps_out = 0, gaps_in = 0 },
})
```

```nix
# users/maxpw/modules/xdg.nix:30-45
hasLockScreen = hostname != "main-pc";

hostLua =
  if hasLockScreen
  then ''
    hl.bind("SUPER + ESCAPE", hl.dsp.exec_cmd("hyprlock"))
  ''
  else "";

hypridleConfig =
  if hasLockScreen
  then ''
    listener {
      timeout = 600
      on-timeout = hyprlock
    }
```

```markdown
<!-- docs/hardware-issues.md:34 -->
Current workaround (2026-03-04): All idle display/sleep actions removed from hypridle on main-pc.
```

Starting upstream facts captured on 2026-06-18:

- GitHub releases lists `v0.55.4` as latest, published 2026-06-11: https://github.com/hyprwm/Hyprland/releases
- Hyprland 0.55 notes say old hyprlang syntax is deprecated in favor of Lua and list new areas to review: ICC profiles, color-management changes, scrolling goodies, `auto_consuming` bind flag, device tags, `confine_pointer`, `move_into_or_create_group`, `rotatesplit`, live pinch cursor zoom, and glow decoration: https://hypr.land/news/update55/
- Hyprland 0.54 notes say `togglesplit` and `swapsplit` dispatchers were removed in favor of `layoutmsg`, and introduce per-workspace layouts plus scrolling and monocle layouts: https://hypr.land/news/update54/
- Hyprland 0.53 notes introduce `start-hyprland`, window-rule syntax overhaul, and hyprpaper 0.8 config/IPC changes: https://hypr.land/news/update53/
- The latest wiki variables page says the current docs are Lua-first and that multiple `hl.config()` invocations update only the passed values: https://wiki.hypr.land/Configuring/Basics/Variables/
- The latest monitor docs include ICC profile, VRR, 10-bit, and HDR/color-management fields: https://wiki.hypr.land/Configuring/Basics/Monitors/
- The latest window-rule docs include dynamic effects such as `persistent_size`, `confine_pointer`, `focus_on_activate`, `no_focus`, `dim_around`, `opacity`, and `border_color`: https://wiki.hypr.land/Configuring/Basics/Window-Rules/
- The latest workspace-rule docs document `persistent`, `default_name`, per-workspace `layout`, per-workspace `animation`, and smart-gap examples: https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
- `hyprctl configerrors`, `hyprctl descriptions`, `hyprctl binds`, and other read-only diagnostics are documented: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Using-hyprctl/
- Official example configuration links live at: https://wiki.hypr.land/Configuring/Example-configurations/

Repo conventions:

- Use existing Lua helper style in `users/maxpw/hyprland/lib.lua`; do not replace it with raw config syntax unless the audit proves the helper is now wrong.
- Keep platform and host conditionals in Nix modules, especially `users/maxpw/modules/xdg.nix`, rather than hardcoding host behavior in Lua files.
- Use `nix flake check --no-build` for evaluation-only validation.
- `make update` intentionally skips Hyprland; `make update-all` includes Hyprland and all inputs.
- `jj root` failed during planning, so this checkout is plain git. Use git for status/diff unless `jj root` succeeds in a future checkout.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Drift check | `git diff --stat e35642f..HEAD -- flake.nix flake.lock modules/desktop/hyprland.nix users/maxpw/hyprland users/maxpw/waybar users/maxpw/modules/xdg.nix users/maxpw/modules/packages/linux-desktop.nix users/maxpw/wlogout docs/hardware-issues.md` | Either no output or only changes you account for before continuing |
| Repo status | `git status --short` | Shows only expected working-tree changes; do not modify source during this audit |
| Nix eval baseline | `nix flake check --no-build` | Exit 0; warnings are acceptable if already known |
| Local Hyprland lock | `jq -r '.nodes.hyprland.locked | [.owner,.repo,.rev,.lastModified] | @tsv' flake.lock` | Prints `hyprwm Hyprland <rev> <unix-time>` |
| Latest release | `curl -fsSL https://api.github.com/repos/hyprwm/Hyprland/releases/latest | jq -r '.tag_name, .published_at, .html_url'` | Prints current latest tag, date, and release URL |
| Latest upstream commit | `curl -fsSL https://api.github.com/repos/hyprwm/Hyprland/commits/main | jq -r '.sha, .commit.committer.date'` | Prints current upstream main SHA and date |
| Static breakage sweep | `rg -n 'togglesplit|swapsplit|pseudotile|cm_fs_passthrough|misc:vfr|\\bvfr\\b|ignore_window|new_window_takes_over_fullscreen|inherit_fullscreen|layoutmsg|confine_pointer|persistent_size|focus_on_activate|no_focus_on_activate' users/maxpw/hyprland modules/desktop users/maxpw/modules users/maxpw/waybar users/maxpw/wlogout` | Prints candidates to inspect; matches are leads, not automatic findings |
| Runtime config errors | `hyprctl configerrors` | In a live Hyprland session, prints no config errors; if not in a Hyprland session, record "not run" |
| Runtime version | `hyprctl version` | In a live Hyprland session, prints version and commit; compare to `flake.lock` |
| Runtime JSON snapshot | `hyprctl -j monitors; hyprctl -j workspaces; hyprctl -j binds; hyprctl -j layers` | In a live session, valid JSON for each command |
| Runtime option schema | `hyprctl -j descriptions > /tmp/hyprland-descriptions.json` | Exit 0 in a live session; use only `/tmp`, not repo files |

## Scope

**In scope**:

- Create or update `plans/hyprland-audit-results.md` with the audit report.
- Update this plan's status row in `plans/README.md`.
- Read and inspect:
  - `flake.nix`
  - `flake.lock`
  - `modules/desktop/hyprland.nix`
  - `users/maxpw/hyprland/**`
  - `users/maxpw/waybar/**`
  - `users/maxpw/modules/xdg.nix`
  - `users/maxpw/modules/packages/linux-desktop.nix`
  - `users/maxpw/wlogout/**`
  - `docs/hardware-issues.md`

**Out of scope**:

- Do not edit Hyprland, Waybar, Nix module, package, wlogout, or hardware docs in this audit.
- Do not run `nix flake update`, `make update`, `make update-all`, `make rebuild`, `hyprctl dispatch ...`, or any command that changes compositor state.
- Do not copy large external configs into this repo. Inspiration must become small, justified candidate changes.
- Do not re-enable DPMS, hibernate, or suspend behavior on `main-pc` without explicitly addressing `docs/hardware-issues.md`.

## Git workflow

- Branch: no branch is required for the audit report. If the operator asks for a branch, use `advisor/001-hyprland-audit`.
- Commit: do not commit unless the operator asks.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Establish local and upstream baselines

Confirm the drift check, current working tree, Nix eval baseline, locked Hyprland rev, latest upstream release, and latest upstream main commit. Record all values in `plans/hyprland-audit-results.md` under "Baseline".

Important interpretation rule: because `flake.nix` tracks `github:hyprwm/Hyprland`, the local lock may be newer than the latest release tag. If local lock is newer than latest release, compare against both latest release notes and upstream main changes since the release.

**Verify**: Run the first six commands in "Commands you will need". Expected: `nix flake check --no-build` exits 0 and the report contains local lock, latest release, and upstream main values.

### Step 2: Review official upstream change sources

Read the official sources listed in "Current state" and record only changes that can plausibly affect this repo. Use the following buckets:

- Required compatibility: removed/renamed options, dispatchers, syntax, package/version coupling.
- Runtime health: config errors, crashes, portal/session startup, `start-hyprland`, UWSM, xdg-desktop-portal-hyprland.
- Workflow improvements: binds, layouts, workspaces, groups, special workspace behavior, per-workspace layout rules.
- Visual/monitor improvements: ICC, VRR, HDR/color management, glow, animation styles, smart gaps.
- Ecosystem tools: hyprpaper, hypridle, hyprlock, hyprsunset, hyprpolkitagent, hyprsysteminfo, hyprland-guiutils.

**Verify**: The report has a "Source review" section with at least one paragraph per bucket and direct URLs for every upstream source used.

### Step 3: Run a static compatibility sweep

Use the static breakage sweep command and manually inspect every match. At minimum, inspect the current `togglesplit` binding in `users/maxpw/hyprland/conf/keybinds.lua:15` against the 0.54 release note that says `togglesplit` dispatchers were removed in favor of `layoutmsg`.

Do not assume a match is a bug. For each candidate, determine:

- Is the code using a removed Hyprland option or dispatcher?
- Is the code using a compatibility wrapper from `hl.dsp` that still emits valid Lua/current Hyprland semantics?
- Would `hyprctl configerrors` or `hyprctl -j descriptions` catch it?
- What exact file would an implementation later touch?

**Verify**: The report has a "Compatibility findings" table with columns: finding, evidence, impact, suggested next action, confidence. Include "no finding" rows for high-risk checked items that are clean.

### Step 4: Run live-session diagnostics when available

If the executor is inside the user's live Hyprland session, run the read-only `hyprctl` commands from the commands table. Capture key results in the report; do not paste huge JSON dumps. If not inside Hyprland, record that runtime diagnostics were not run and list the exact commands for the user to run later.

Pay special attention to:

- `hyprctl configerrors`
- `hyprctl version` versus `flake.lock`
- `hyprctl -j binds` entries for `SUPER+S`, layout-related binds, and special workspace binds
- `hyprctl -j layers` for waybar/rofi/swaync/wlogout layer names that current layer rules match
- `hyprctl -j monitors` for monitor names, VRR capability, scale, refresh, and color-management candidates

**Verify**: The report has a "Runtime diagnostics" section that either includes results or explicitly says "not run" with reason.

### Step 5: Audit local host-specific safety boundaries

Read `docs/hardware-issues.md`, `users/maxpw/modules/xdg.nix`, `users/maxpw/hyprland/hypridle.conf`, and `users/maxpw/wlogout/layout`.

Check:

- Whether `main-pc` still avoids idle DPMS/sleep behavior through generated Home Manager config.
- Whether `wlogout` still exposes hibernate or lock actions that conflict with main-pc safety or package availability.
- Whether hyprlock is conditionally installed consistently with generated binds and actions.
- Whether hyprpaper's current startup IPC workaround is still needed after the locked Hyprland/hyprpaper versions.

**Verify**: The report has a "Host safety" section with explicit recommendations for `main-pc` and non-`main-pc` hosts.

### Step 6: Curate config inspiration

Use official docs first, then the official example configuration page. Optional third-party repos can be skimmed, but every candidate must map to a local problem or workflow improvement. Do not recommend visual churn without a reason.

Candidate categories to evaluate:

- Replace or modernize deprecated layout dispatchers with current `layoutmsg` patterns.
- Use 0.54 per-workspace layout support more intentionally: for example master on workspace 3, monocle/scrolling only if it fits real use.
- Add useful window rules such as `persistent_size` for recurrent floating dialogs, `confine_pointer` only for games/fullscreen cases, or per-app opacity/focus behavior where there is a real annoyance.
- Review smart gaps against latest workspace-rule examples, especially preserving the Waybar top gap.
- Consider per-monitor VRR/ICC/color-management fields only if `hyprctl -j monitors` and actual hardware support justify it.
- Review glow/animation settings against performance and readability. Avoid `borderangle`/`shadowangle` loop animation because the docs warn it forces continuous rendering.
- Check whether Hypr ecosystem tools such as `hyprsysteminfo`, `hyprsunset`, `hyprpolkitagent`, or `hyprland-guiutils` replace current ad-hoc or older tooling.
- Review official example configs for patterns, not code: module organization, workspace conventions, power menu safety, screenshots/recording workflow, notification center behavior, and status bar interaction.

**Verify**: The report has a "Candidate improvements" table with columns: idea, source, local fit, files likely touched, effort, risk, reject/keep. Keep no more than 8 candidate ideas.

### Step 7: Produce follow-up implementation plans

After ranking findings, create follow-up plan files only for candidates worth implementing. Use the numbering after this file, for example:

- `plans/002-modernize-hyprland-layout-binds.md`
- `plans/003-tighten-hyprland-host-power-safety.md`
- `plans/004-refresh-hyprland-visual-and-monitor-rules.md`

Each follow-up plan must be self-contained, must list exact source files to edit, and must include verification gates. If the audit produces no implementation-worthy candidates, do not create empty plans; record that in `plans/hyprland-audit-results.md`.

**Verify**: The report has a "Recommended next plans" section. If any new plan files are created, `plans/README.md` includes them in dependency order.

## Test plan

This plan is an audit/report task, not a config implementation. Verification is:

- `nix flake check --no-build` exits 0 before any recommendations are treated as actionable.
- `plans/hyprland-audit-results.md` exists and includes the required sections:
  - Baseline
  - Source review
  - Compatibility findings
  - Runtime diagnostics
  - Host safety
  - Candidate improvements
  - Recommended next plans
- `git diff --stat` shows no source config changes outside `plans/`.
- If runtime diagnostics are available, `hyprctl configerrors` output is recorded.

## Done criteria

All must hold:

- [ ] `plans/hyprland-audit-results.md` exists with the required sections.
- [ ] Every compatibility finding has evidence with file/line references or upstream URL references.
- [ ] Every inspiration candidate has a keep/reject decision and no more than 8 candidates are kept.
- [ ] Any generated follow-up implementation plan is self-contained and listed in `plans/README.md`.
- [ ] `git diff --stat` shows only `plans/` changes.
- [ ] `plans/README.md` status for plan 001 is updated to DONE or BLOCKED with a one-line reason.

## STOP conditions

Stop and report back if:

- Any in-scope source file differs materially from the excerpts above and the correct audit scope is unclear.
- Official upstream docs disagree with each other on a config option and the runtime `hyprctl descriptions` command is unavailable to resolve it.
- `nix flake check --no-build` fails for reasons unrelated to known dirty-tree warnings.
- The audit appears to require modifying actual config files to continue.
- Any proposed idle, DPMS, suspend, hibernate, or lock-screen change could affect `main-pc` and has not accounted for `docs/hardware-issues.md`.

## Maintenance notes

- Re-run this audit after any future Hyprland major/minor release or after `make update-all`.
- Because `make update` skips Hyprland, stale Hyprland input is expected unless `make update-all` or direct input updates are used.
- Prefer upstream docs and runtime `hyprctl descriptions` over examples from third-party dotfiles.
- Review future changes with particular attention to host-specific power behavior, because `main-pc` has documented AMD display-controller crashes on DPMS/hibernate paths.
