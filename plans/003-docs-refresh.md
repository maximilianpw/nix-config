# Plan 003: Make CLAUDE.md, README.md, and BOOTSTRAP.md match the actual repo

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat b31e6af..HEAD -- CLAUDE.md README.md BOOTSTRAP.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: docs
- **Planned at**: commit `b31e6af`, 2026-07-03

## Why this matters

CLAUDE.md is loaded into every Claude Code session in this repo and README.md
is the human entry point — both currently describe a repo that no longer
exists. The nixpkgs version is wrong (25.11 vs actual 26.05), README documents
a `modules/desktop/gnome.nix` that was deleted, the module trees omit seven
imported Home Manager modules, and the entire `homelab/` subsystem (nine
services running on main-pc) is absent from CLAUDE.md. Agents navigating by
these docs make wrong assumptions every session; that is a recurring cost.

## Current state

Facts verified against the tree at commit `b31e6af` (2026-07-03):

**Version drift** — flake.nix:5 is `github:nixos/nixpkgs/nixos-26.05`, but:
- `CLAUDE.md:104`: "Stable is `nixpkgs` (25.11)."
- `README.md:51`: "Inputs: nixpkgs 25.11, ... home-manager 25.11, nix-darwin 25.11 ..."
- `machines/main-pc.nix:88` comment: "unmaintained and marked insecure in nixpkgs 25.11" — leave this one alone; it records when the workaround was added.

**Ghost module** — `README.md:91-92` documents `modules/desktop/gnome.nix`
("GDM (Wayland), GNOME desktop, ..."). `ls modules/desktop/` → only
`hyprland.nix`.

**README layout tree drift** — `README.md:7-47` shows `fonts.nix`,
`neovim.nix`, `packages/` as direct children of `users/maxpw/` — they live in
`users/maxpw/modules/`. The tree also omits: `homelab/` (9 files), `secrets/`,
`templates/`, `Makefile`, `machines/wsl.nix` is present but
`machines/hardware/main-pc-disko.nix` is not, `packages/` shows only
`helium.nix` (there are four packages), and `modules/core/` shows two files
(there are five).

**CLAUDE.md module tree gaps** — the tree at CLAUDE.md:52-80:
- `modules/core/` line lists "nix-settings.nix, security.nix, sops.nix"; the
  directory also contains `shells.nix` (system-level shell registration:
  nushell/fish/bash/zsh as login shells) and `remote-dev.nix` (Tailscale +
  mosh + tmux for the fleet; trusts `tailscale0` in the firewall).
- `users/maxpw/modules/` omits these imported modules (see
  `users/maxpw/home-manager.nix:18-38` for the authoritative import list):
  `vcs/jujutsu.nix`, `agent-tools.nix`, `fleet.nix`, `t3code-server.nix`,
  `syncthing.nix`, `himalaya.nix`, `packages/custom-scripts.nix`.
- `homelab/` is not mentioned anywhere in CLAUDE.md. It is imported by
  `machines/main-pc.nix:9` (`../homelab`) and contains: `cloudflared.nix`
  (Cloudflare tunnel, ingress for all services), `home-assistant.nix`,
  `homepage.nix` (dashboard), `miniflux.nix`, `nextcloud.nix`,
  `paperless.nix`, `storage.nix`, `syncthing.nix`, `uptime-kuma.nix`,
  aggregated by `default.nix`.
- The fleet workflow (`users/maxpw/modules/fleet.nix`,
  `modules/core/remote-dev.nix`) has full usage docs in
  `docs/remote-dev-fleet.md`, which CLAUDE.md never references.

**BOOTSTRAP.md papercut** — the troubleshooting advice
`cat ~/nix-config/nixos-switch.log` (near line 204) doesn't note that on a
fresh macOS bootstrap the log doesn't exist until the first rebuild attempt.

**Convention**: docs are plain GitHub-flavored markdown; keep the existing
heading structure and tone; do not restructure sections, only correct facts.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| List actual HM imports | `grep -n 'modules/' users/maxpw/home-manager.nix` | 18 import lines |
| List actual core modules | `ls modules/core/` | 5 files |
| List homelab services | `ls homelab/` | 10 files (9 services + default.nix) |
| Confirm no gnome module | `ls modules/desktop/` | `hyprland.nix` only |

## Scope

**In scope** (the only files you should modify):
- `CLAUDE.md`
- `README.md`
- `BOOTSTRAP.md`

**Out of scope**:
- Any `.nix` file — this is a docs-only plan.
- `docs/*.md` — remote-dev-fleet.md, wsl-setup.md, hardware-issues.md are accurate enough; only *link* to them.
- `machines/main-pc.nix:88` comment (historical note, correct as written).
- `users/maxpw/agents/**` — agent prompt files, not repo docs.

## Git workflow

- Branch: `advisor/003-docs-refresh`
- Commit style: `docs: <what>` (repo history uses conventional prefixes).
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Fix the nixpkgs version references

- `CLAUDE.md:104`: change "(25.11)" → "(26.05)".
- `README.md:51`: change all three "25.11" occurrences → "26.05".

**Verify**: `grep -n "25\.11" CLAUDE.md README.md` → no matches.

### Step 2: Remove the ghost gnome module from README

Delete the `modules/desktop/gnome.nix` entry (README.md:91-92, the bullet and
its description line). Keep the `modules/desktop/hyprland.nix` entry.

**Verify**: `grep -n "gnome" README.md` → no matches.

### Step 3: Correct the README repository-layout tree

Rewrite the tree at README.md:7-47 to match `ls`-verified reality. It must
include at minimum: `homelab/` (one line per service is not needed — a single
line "9 self-hosted services behind a Cloudflare tunnel" suffices),
`secrets/`, `templates/`, `Makefile`, all four `packages/*.nix`, all five
`modules/core/*.nix`, and `users/maxpw/modules/` as the parent of the module
files (fonts, neovim, packages/, etc.). Verify each path you write with
`ls` before writing it.

**Verify**: for every path in the new tree, `test -e <path>` → exit 0
(spot-check at least: `homelab/default.nix`, `modules/core/remote-dev.nix`,
`users/maxpw/modules/fonts.nix`, `packages/coderabbit.nix`).

### Step 4: Complete the CLAUDE.md module layout and document homelab + fleet

In the CLAUDE.md tree (lines 52-80):
- Add to the `modules/core/` line: `shells.nix`, `remote-dev.nix` with
  short role descriptions (from "Current state" above).
- Add the seven missing user modules with one-phrase descriptions:
  `vcs/jujutsu.nix` (jj config), `agent-tools.nix` (LLM agent CLIs + aliases),
  `fleet.nix` (fleet CLI + SSH matchblocks for remote dev),
  `t3code-server.nix`, `syncthing.nix` (user-level), `himalaya.nix` (email),
  `packages/custom-scripts.nix`.
- Add a `homelab/` entry to the tree and a short subsection under
  "Architecture" (2-4 sentences): imported by `machines/main-pc.nix`, services
  exposed via Cloudflare tunnel (`cloudflared.nix` ingress), secrets via
  sops-nix, most services bind 127.0.0.1.
- Add one sentence referencing `docs/remote-dev-fleet.md` for fleet usage.

**Verify**: `grep -c "homelab" CLAUDE.md` → ≥ 2; `grep -n "fleet.nix\|remote-dev.nix\|himalaya" CLAUDE.md` → all present.

### Step 5: BOOTSTRAP.md log-file note

At the troubleshooting line referencing `nixos-switch.log` (~line 204), add:
"(created on first rebuild; on a fresh macOS bootstrap it won't exist yet —
check `log show --last 10m --level=error` instead)".

**Verify**: `grep -n "first rebuild" BOOTSTRAP.md` → 1 match.

## Test plan

Docs-only; the verification greps above are the tests. Additionally run
`nix flake check --no-build` once at the end to prove no `.nix` file was
accidentally touched → exit 0.

## Done criteria

- [ ] `grep -rn "25\.11" CLAUDE.md README.md` → no matches
- [ ] `grep -n "gnome" README.md` → no matches
- [ ] CLAUDE.md mentions homelab/, fleet.nix, remote-dev.nix, and docs/remote-dev-fleet.md
- [ ] Every path named in the README tree exists on disk
- [ ] `git status` shows only CLAUDE.md, README.md, BOOTSTRAP.md modified
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The actual file layout differs from the "Current state" inventory above
  (e.g. `modules/core/` no longer has 5 files) — re-verify with `ls` and
  report the delta rather than guessing.
- You find yourself wanting to restructure or rewrite prose beyond factual
  corrections — that's scope creep; note the suggestion and move on.

## Maintenance notes

- This drift accumulated because nothing prompts a docs update on structural
  change. The lint plan (004) does not cover docs; consider a future
  CLAUDE.md line item in the `add-package`/`rebuild` skills reminding agents
  to update the module tree when adding modules.
- Reviewer: diff should be almost entirely factual corrections; flag any
  reworded sections that change meaning.
