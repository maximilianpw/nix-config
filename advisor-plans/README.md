# Nix-config cleanup implementation plans

Follow-up cleanup planned on 2026-09-20 against commit `9482048`. The reviewed
result at `129bd42` was fast-forwarded to main. A subsequent user override keeps
the parked desktop configuration and assets for a future host; no push,
activation, restore, or live-service operation was performed.

## Current cleanup pass

| Plan | Title | Priority | Effort | Depends on | Status | Verification evidence |
|---|---|---:|---:|---|---|---|
| [010](010-trim-remaining-test-scaffolding.md) | Trim obsolete Fleet scaffolding and low-value assertions | P2 | S | — | DONE: integrated reviewed change | Coordinator review passed Alejandra, lint, three scoped regressions, shell checks, no-build evaluation, and diff checks. |
| [011](011-remove-dead-config-and-assets.md) | Remove unreachable non-desktop configuration; retain parked desktop assets | P3 | S | — | DONE: desktop removal superseded by user override | Non-desktop cleanup remains; the host hook, four Waybar dividers, and preview are restored exactly from `9482048`. Format/lint, no-build evaluation, and parked-desktop evaluation passed. |
| [012](012-reconcile-recovery-documentation.md) | Reconcile recovery instructions with archive contracts | P1 | M | — | DONE: integrated reviewed change | Evaluated archive/quiesce metadata and documentation assertions passed; no archive, restore, service-mask, activation, or quarterly drill was performed. |
| [013](013-retire-completed-documentation.md) | Retire completed plans and superseded research | P2 | S | 010, 011, 012 | DONE: exact historical set retired | Durable owner notes, deletion assertions, relative Markdown links, and diff hygiene passed; no live provider or credential probe was performed. |

Plans 001–009 were completed before baseline `9482048`; retrieve their instructions and completion notes from Git history.

Plans 010–013 remain as the current handoff and review record. Retire them only
in a later explicitly requested pass after this integrated result is reviewed.
Public `lib.hosts.*.profiles` metadata remains unchanged. After the user
override, Plan 011 retains the parked desktop files while keeping the unused
internal-argument cleanup, Joyce disabled-builder cleanup, and Linux GC
simplification.

## Considered, rejected, or deferred

- **Delete broad homelab recovery tests** — rejected. Inventory validation,
  generated backup wiring, runtime failure recovery, archive inspection, and T3
  Code snapshot behavior are separate safety layers.
- **Split `lib/homelab-services.nix` solely because it is large** — rejected. It
  is intentionally the typed service and recovery inventory.
- **Delete Fleet consumer compatibility tests because runtime moved upstream** —
  rejected. Projection, installed-package selection, trust, and generated TOML
  compatibility remain this repository's responsibility.
- **Delete exported `lib.hosts.*.profiles`** — deferred. External consumers have
  not been audited, so the public metadata shape is preserved.
- **Delete currently unused parked Hyprland configuration or assets** — rejected
  by user override. Retain them for a possible future desktop host.
- **Trim `docs/leerr.md` or move its provenance** — deferred. The package
  deliberately depends on that provenance, and the document remains an active
  enrollment and recovery guide.
- **Delete Cava or other manually used CLI packages as dead code** — rejected
  without operator evidence. Lack of a repository reference does not prove lack
  of manual use.
- **Generate `scripts/ynab-mcp-operations.json` reproducibly** — valid separate
  work requiring an upstream OpenAPI provenance decision.
- **Replace `scripts/tests/t3code-post-activation-test.sh`** — valid separate
  work. A behavioral harness needs command-path injection; it is not part of
  this deletion pass.
- **Archive completed plans elsewhere in the repository** — rejected. Git
  history is the archive.
- **Treat dated upstream-provider constraints as current verified facts** —
  rejected. Preserve them as historical constraints that require revalidation.
- **Change live systems while verifying cleanup** — rejected. This pass stops at
  source inspection, formatting, evaluation, disposable regressions, and builds.
