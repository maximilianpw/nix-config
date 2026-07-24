# Implementation Plans

Plans 001–009 (2026-06-18 / 2026-07-03 audits) were implemented and their
files removed on 2026-07-03; see git history for their contents. Each
executor: read the plan fully before starting, honor its STOP conditions,
and update your row when done.

## Execution order and status

| Plan | Title | Priority | Effort | Depends on | Status |
|------|-------|----------|--------|------------|--------|
| 010 | Agent fleet contract + read-only report commands (codex-first) | P2 | M | - (commit WIP first; edits AGENTS.md/CLAUDE.md, see plan hazard note) | DONE |

Status values: TODO | IN PROGRESS | DONE | BLOCKED (with one-line reason) | REJECTED (with one-line rationale)

## Dispatch prompt template (per subagent)

> Read `/path/to/repo/plans/NNN-<slug>.md` in full and execute it exactly.
> Run its drift check first. Honor every verification gate and STOP
> condition. Do not modify files outside the plan's in-scope list. Report:
> steps completed, verification outputs, and any STOP condition hit. Do not
> update plans/README.md (the dispatcher maintains the index).

## Findings considered and rejected

Recorded so they are not re-audited next run (2026-07-03 audit):

- Unquoted `$session` in fleet home-manager module — already constrained by
  `validate_session` regex upstream; quote opportunistically if editing the file.
- `bash -c` command chain in machines/kim.nix — quoting is correct;
  readability-only.
- Shell aliases spread across shells.nix / agent-tools.nix / fleet modules —
  HM merges attrsets safely; consolidation not worth the churn.
- Hardcoded `~/nix-config` in scripts/ — documented repo convention (CLAUDE.md).
- Syncthing `insecureSkipHostcheck = true` (homelab/syncthing.nix) —
  deliberate, commented, GUI password-protected behind the Cloudflare tunnel.
- Cloudflare tunnel UUID in git (homelab/cloudflared.nix) — UUIDs are not
  secrets; credentials are in sops.
- Darwin numeric vs NixOS string `stateVersion` — correct per platform.
- flake.lock staleness — checked 2026-07-03; all inputs from June 2026.
- `hyprland`/`llm-agents` inputs without `follows` — deliberate (upstream
  caches / fresh deps).
- immich, vaultwarden, prometheus+grafana, devenv, agenix, mac-app-util,
  flake-parts, homepage↔home-assistant widget integration — evaluated as
  direction candidates and rejected as poor fits (duplicate existing choices:
  1Password, uptime-kuma, direnv+templates, sops-nix; or no evidence of need).
- lanzaboote (secure boot) and impermanence (ephemeral root) — plausible fits
  flagged to the operator, declined for now; revisit on explicit request.
- Bounded agent loop command, prompt-debt check script, scheduled timers,
  agent secret isolation — from `docs/agent-fleet-and-loops-handoff.md`,
  deferred with rationale in plan 010's "Deliberately out of scope" section.
