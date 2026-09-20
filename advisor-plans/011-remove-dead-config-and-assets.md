# Plan 011: Remove unreachable non-desktop configuration and retain parked desktop assets

> Execute only when implementation is requested. Preserve unrelated work and update this plan and its index row. Building/evaluation is permitted; activation, deployment, publishing, and live cleanup are not.
>
> Drift check: `git diff --stat 9482048 -- flake.nix lib/mksystem.nix machines/joyce.nix modules/core/nix-settings.nix users/maxpw/modules/xdg.nix users/maxpw/waybar`. Reconcile changes against the evidence below before editing.

## Status

- Status: DONE — non-desktop cleanup retained; desktop removal superseded by user override
- Priority: P3
- Effort: S
- Risk: LOW for current hosts; exported inventory compatibility is deliberately preserved
- Depends on: none
- Category: tech-debt
- Planned at: commit `9482048`, 2026-09-20

## User override

After the reviewed cleanup reached main at `129bd42`, the user chose to retain
the parked Hyprland setup for a possible future desktop host. The generated
`host.lua` hook, four unused Waybar divider definitions, and preview image are
therefore restored exactly from `9482048`. The internal unused-argument cleanup,
Joyce disabled-builder removal, and Linux GC simplification remain approved.
Historical removal instructions and evidence below are superseded only for
those three desktop paths.

## Context and evidence

The flake owns Kim (NixOS), Cuno (WSL), Joyce (Darwin), and an intentionally parked/evaluable Kim desktop profile. Keep that profile. Chezmoi and external Pi/Fleet ownership are not part of this change.

- `lib/mksystem.nix:15,42,49` accepts `profiles ? []` and forwards `currentSystem = system` and `currentSystemProfiles = profiles`. No repository module reads either forwarded argument. `flake.nix:132` passes profiles and `:143` appends `"desktop"`; desktop behavior actually uses `linuxDesktop`.
- **Public API boundary:** `flake.nix` exports `lib.hosts`. `lib/inventory.nix:43` declares `profiles`, and `lib/hosts.nix` populates it. External consumers were not audited. Keep these public metadata fields; remove only the unused internal plumbing.
- `machines/joyce.nix:23–44` has an inactive `linux-builder = { enable = false; ... };` recipe beneath `nix.enable = false`. Determinate owns Joyce's daemon. Keep `nix.enable = false`, `/etc/nix/nix.custom.conf`, and every stateVersion unchanged.
- `modules/core/nix-settings.nix:34–40` branches on `pkgs.stdenv.isDarwin` for GC scheduling, but its only imports are `users/maxpw/nixos.nix` and `users/maxpw/wsl.nix`. Joyce explicitly does not import it.
- `users/maxpw/modules/xdg.nix:30–35` generates:
  ```nix
  hostLua =
    if hasLockScreen
    then ''
      hl.bind("SUPER + ESCAPE", hl.dsp.exec_cmd("hyprlock"))
    ''
    else "";
  ```
  It deploys this as `"hypr/host.lua".text = hostLua` at line 142. `users/maxpw/hyprland/hyprland.lua` loads six `conf.*` modules, none of which loads `host`. Keep `hasLockScreen`: it still controls `hypridleConfig`.
- `users/maxpw/waybar/modules.jsonc:12–19,32–39` declares unused `custom/left_div#2`, `#3`, `#7`, and `#8`. They are absent from the layout and nested audio group.
- `users/maxpw/waybar/previews/mechabar-stalenhag-preview.png` is a 2,067,949-byte reference screenshot with no tracked references. Home Manager nevertheless includes it through `"waybar".source = ../waybar; "waybar".recursive = true` (`xdg.nix:117–118`). It has no runtime role; Git preserves the reference image.

## Scope

Only modify:

- `flake.nix`
- `lib/mksystem.nix`
- `machines/joyce.nix`
- `modules/core/nix-settings.nix`
- `users/maxpw/modules/xdg.nix` (desktop removal superseded; retain baseline content)
- `users/maxpw/waybar/modules.jsonc` (desktop removal superseded; retain baseline content)
- `users/maxpw/waybar/previews/mechabar-stalenhag-preview.png` (retain baseline binary)
- This plan and `advisor-plans/README.md` status

Do not edit `lib/hosts.nix`, `lib/inventory.nix`, hardware configs, stateVersions, inputs/lockfile, live files, wallpapers, active Hyprland modules, Waybar layout, or package lists. Do not remove migration activation safeguards elsewhere. Do not remove the public `profiles` metadata without a separately scoped external-consumer audit.

## Steps and verification

### 1. Confirm the reference graph and capture a baseline

Run:

```sh
git status --short
git grep -n -E '\bcurrentSystemProfiles\b|\bcurrentSystem\b|\bprofiles\b' -- '*.nix'
git grep -n 'core/nix-settings.nix' -- '*.nix'
git grep -n -E 'host.lua|left_div#(2|3|7|8)|mechabar-stalenhag-preview' -- users
nix flake check --no-build
```

Expected references match the evidence above, and evaluation passes. References in these plan files are not consumers. If baseline evaluation is blocked, record it and do not claim later equivalence.

### 2. Remove unused internal module arguments and disabled Darwin branches

Remove the `profiles` parameter from `mkSystem`, its `currentSystemProfiles` forwarding, and unused `currentSystem` forwarding. Remove `profiles` from the `mkConfiguredSystem` inherit list and the parked desktop override. Keep `system`, `linuxDesktop`, `currentSystemName`, and other consumed arguments intact. Keep all exported host records unchanged.

Delete the disabled `nix.linux-builder` recipe in Joyce; retain `nix.enable = false` and all Determinate configuration.

In `modules/core/nix-settings.nix`, keep the `lib.mkIf config.nix.enable` guard and simplify GC to the existing Linux attributes: `automatic = true`, `options = "--delete-older-than 30d"`, `dates = "weekly"`, `persistent = true`. Remove the now-unused `pkgs` argument if no other use remains. Match surrounding Nix attribute-set style.

Verify: `nix flake check --no-build` exits 0; `git grep -n -E 'currentSystemProfiles|currentSystem =|profiles' -- lib/mksystem.nix flake.nix` returns no matches. `nix eval --json .#lib.hosts --apply 'hosts: builtins.mapAttrs (_: host: host.profiles) hosts'` still returns the three original profile lists.

### 3. Historical desktop-removal step — superseded

Do not apply this removal after the user override. The following records the
original reviewed implementation only.

Delete only the `hostLua` binding and `hypr/host.lua` declaration; keep `hasLockScreen` and idle configuration. Do not reconnect the unused hook, which would introduce a new keybinding rather than clean up existing behavior.

Remove the four unused divider objects, preserving valid JSONC commas. Delete only the preview PNG; keep the two wallpapers, active scripts, theme, CSS, and layout unchanged. Do not run filesystem cleanup against deployed Home Manager destinations.

Verify:

```sh
! git grep -n -E 'hostLua|hypr/host.lua|left_div#(2|3|7|8)' -- users
test ! -e users/maxpw/waybar/previews/mechabar-stalenhag-preview.png
nix eval --raw .#checks.x86_64-linux.eval-kim-desktop.drvPath
```

All exit 0. Nix can copy invalid JSONC without parsing it, so also run this one-off syntax check, which passed against the baseline. It removes comments while preserving quoted strings; no new dependency or permanent test is needed:

```sh
python3 - <<'PY'
import json, pathlib, re
p = pathlib.Path('users/maxpw/waybar/modules.jsonc')
text = re.sub(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/', lambda m: m[0] if m[0].startswith('"') else ' ', p.read_text())
modules = json.loads(text)
assert all(f'custom/left_div#{i}' not in modules for i in (2, 3, 7, 8))
print('Waybar JSONC syntax and removals passed')
PY
```

Expected: exit 0 and the success message.

### 4. Final verification

```sh
alejandra --check flake.nix lib/mksystem.nix machines/joyce.nix modules/core/nix-settings.nix users/maxpw/modules/xdg.nix
make lint
nix flake check --no-build
nix eval --raw .#checks.x86_64-linux.eval-kim-desktop.drvPath
git diff --check
git diff --stat
```

Every command must exit 0. Use `nix develop` for missing repository tools. No full host build or activation is required for these unreachable branches; the desktop evaluation must remain intact.

## Done criteria and test plan

- [x] Public `lib.hosts` metadata remains unchanged.
- [x] No unused profile/system argument forwarding remains.
- [x] Joyce still has `nix.enable = false`; Linux GC behavior is unchanged.
- [x] The parked desktop evaluates.
- [x] The `host.lua` hook, four Waybar dividers, and preview PNG match `9482048` exactly and are intentionally retained.
- [x] The desktop-removal portion is explicitly superseded; only the approved non-desktop cleanup remains.
- [x] The follow-up diff stays within the three restored files, root README, this plan, and its index.

## STOP conditions and maintenance

Stop if a consumer of the supposedly unused arguments/hook/dividers is found, the shared Nix settings module gains a Darwin importer, or a change requires touching public inventory schema. Do not infer external compatibility merely from local grep. If the screenshot is explicitly documented as a deliverable by new changes, report rather than delete it.

Suggested commit if requested: `Remove unreachable configuration and preview assets`. Future desktop-only assets should distinguish runtime files from reference screenshots so recursive Home Manager deployment does not ship both.

## Execution review

Luna implemented this plan in `/home/maxpw/nix-config-cleanup-worktrees/config`.
The coordinator reviewed the seven-file diff and independently passed format,
lint, no-build flake evaluation, parked-desktop and Joyce derivation evaluation,
complete public `lib.hosts` equality against baseline, and Waybar syntax/removal
checks. A missing generated pre-commit configuration was corrected; all four
configured hooks subsequently passed for all files. The amended commit
`3b90095` was cherry-picked as `32a059c`, and the reviewed integrated tree later
reached main at `129bd42`. That historical desktop-removal evidence is now
superseded by the user override above; no configuration was activated.
