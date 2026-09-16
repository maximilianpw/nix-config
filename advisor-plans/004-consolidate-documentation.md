# Plan 004: Consolidate active documentation and retire completed research and plans

> **Executor instructions**: Documentation deletion must preserve unresolved recovery/security work. First extract durable decisions and open work, then delete superseded narratives, then rewrite the README index. Do not edit the user's currently modified CLIProxyAPI module files. Update `advisor-plans/README.md` when complete.
>
> **Drift check (run first)**: `git diff --stat 31341e0 -- README.md BOOTSTRAP.md docs/agent-fleet-and-loops-handoff.md docs/hardware-issues.md docs/beelink-headless-checklist.md docs/homelab-architecture-and-recovery-plan.md docs/homelab-automation-ai-options.md docs/homelab-dashboard-plan.md docs/homelab-dashboard-research.md docs/tunarr-research.md docs/cliproxyapi-opencode-provider-research.md docs/config-ownership-and-recovery.md docs/homelab-recovery.md docs/media-stack.md docs/nextcloud-calendar.md`
> If dependency plans intentionally changed an in-scope path, reconcile this plan against the new code before proceeding. For any other staged, unstaged, or committed drift, STOP and report instead of applying stale excerpts.

## Status

- **Status**: DONE
- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: Plans 001 and 003 should land first so README descriptions match the final package/Fleet ownership
- **Category**: docs
- **Planned at**: commit `31341e0`, 2026-09-16

## Why this matters

The active docs directory mixes operational runbooks with completed implementation plans, dated LLM handoffs, contradictory research, and release-specific packaging dossiers. The largest stale plan is 958 lines and still describes implemented work as “Prepared” in a former worktree. Consolidating these files will make active runbooks easier to find and reduce the chance that a maintainer or agent follows superseded instructions.

## Current state

Active runbooks/decision records that must remain:

- `BOOTSTRAP.md`
- `docs/config-ownership-and-recovery.md`
- `docs/homelab-recovery.md`
- `docs/homelab-storage.md`
- `docs/media-stack.md`
- `docs/media-stack-research.md` (accepted decision record)
- `docs/atuin.md`, `docs/immich.md`, `docs/paperless.md`, `docs/leerr.md`, `docs/nextcloud-calendar.md`, `docs/wsl-setup.md`
- `docs/restore-drills/README.md`
- module-specific READMEs such as `modules/fleet/README.md` and `modules/cliproxyapi/README.md`

Superseded or contradictory material:

- `docs/agent-fleet-and-loops-handoff.md:4` addresses an implementing LLM; its Fleet contract recommendation is now implemented by `lib/fleet.nix` and documented in `modules/fleet/README.md`.
- `docs/homelab-architecture-and-recovery-plan.md:28` defines status relative to a former worktree. It proposes a recovery runbook, typed inventory, and alert rules that now exist.
- `docs/homelab-dashboard-research.md:168` recommends Beszel, while `docs/homelab-dashboard-plan.md:19` records the later Grafana/Prometheus decision and production code implements it.
- `docs/homelab-automation-ai-options.md:7` says weekly flake updates exist, while `:60` says they do not; `.github/workflows/update-flake-inputs.yml` is authoritative.
- `docs/tunarr-research.md:1` targets Tunarr 1.3.10 while `packages/tunarr.nix` packages 1.3.13. Durable packaging constraints already appear in source comments and operational guidance lives in `docs/media-stack.md`.
- `docs/cliproxyapi-opencode-provider-research.md` describes a provider implementation that has landed. The currently modified `modules/cliproxyapi/README.md` must not be overwritten by this plan.
- `README.md:7-163` manually catalogs paths, inputs, and modules. It references old paths such as `users/maxpw/packages/*.nix` and `users/maxpw/fonts.nix`.

Durable unresolved work that must not disappear includes off-site backup choice, independent secret/key recovery, completed restore drills, external alert delivery, provider control-plane policy/drift, and any still-desired Homepage calendar agenda work.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Reference scan | `git grep -n 'homelab-architecture-and-recovery-plan\|homelab-dashboard-plan\|homelab-dashboard-research\|agent-fleet-and-loops-handoff\|tunarr-research\|cliproxyapi-opencode-provider-research' -- ':!advisor-plans/**'` | only intentional references before deletion; none afterward |
| Link scan | `rg -n '\]\([^)]*\.md[^)]*\)' README.md BOOTSTRAP.md docs modules | inspect all changed links |
| Docs check | `git diff --check` | exit 0 |
| Repo evaluation | `nix flake check --no-build` | exit 0; documentation changes did not accidentally alter source |

## Scope

**In scope**:
- `README.md`
- Create `docs/README.md` as a short documentation index
- Create `docs/homelab-backlog.md` as the single concise home for unresolved cross-service work
- Create `docs/agent-tooling-backlog.md` as the concise replacement for still-unresolved agent workflow ideas
- `docs/config-ownership-and-recovery.md` and `docs/homelab-recovery.md` for durable invariants/open-work links
- `docs/beelink-headless-checklist.md`
- Delete or sharply reduce:
  - `docs/agent-fleet-and-loops-handoff.md`
  - `docs/hardware-issues.md`
  - `docs/homelab-architecture-and-recovery-plan.md`
  - `docs/homelab-automation-ai-options.md`
  - `docs/homelab-dashboard-plan.md`
  - `docs/homelab-dashboard-research.md`
  - `docs/tunarr-research.md`
  - `docs/cliproxyapi-opencode-provider-research.md`
- Minor link repairs in active docs caused by these deletions

**Out of scope**:
- `modules/cliproxyapi/README.md`, `modules/cliproxyapi/darwin.nix`, `modules/cliproxyapi/home-manager.nix`, and `users/maxpw/modules/agent-tools.nix` because they already contain user changes
- Rewriting active operational procedures without evidence
- Deleting `docs/media-stack-research.md`; it is explicitly an accepted decision record
- Deleting `docs/leerr.md`; the package currently depends on it for provenance and it contains active operations/recovery material
- Publishing issues or moving files outside the repository

## Git workflow

- Suggested branch: `advisor/004-doc-consolidation`
- Prefer two commits: `docs: preserve unresolved homelab backlog`, then `docs: retire superseded plans and research`.
- Do not push or publish issues without explicit authorization.

## Steps

### Step 1: Build a keep/delete/extract matrix

For each candidate document, classify every section as one of:

- active runbook—move only if there is a better authoritative file;
- durable decision/invariant—merge into an active runbook or concise decision record;
- unresolved backlog—move to `docs/homelab-backlog.md` with owner/gate and no stale status language;
- completed implementation narrative or superseded alternative—delete.

Use source configuration and tests as truth. Do not preserve prose merely because it is long.

**Verify**: every unresolved item from the architecture, dashboard, and automation documents has a destination before deletion.

### Step 2: Preserve unresolved agent-tooling work

Before deleting `docs/agent-fleet-and-loops-handoff.md`, create `docs/agent-tooling-backlog.md` with these exact dispositions:

- **Fleet contract**: mark implemented; point to `modules/fleet/README.md`, `users/maxpw/agents/shared/AGENTS.md`, and generated `~/.config/fleet/FLEET.md`. Do not copy the old research narrative.
- **Bounded execution loop**: mark implemented by repository `AGENTS.md` execution/delegation policy and its verification commands. Do not add another prompt file merely to duplicate policy.
- **Scheduled read-only reports**: retain as deferred. Preserve the proposed health, prompt-debt, Fleet-drift, and agent-tooling-update report types; state that they must write reports only and must not edit the repo by default.
- **Prompt-debt validation**: retain as deferred. Preserve checks for missing commands/files, generated-file edit warnings, inventory aliases, oversized policies, and duplicated rules.
- **Unattended credential isolation**: retain as deferred security work. Correct the stale handoff claim: current Fleet SSH blocks disable agent forwarding by default. Preserve the need for low-privilege, short-lived credentials and human approval for destructive operations.
- **Open decisions**: preserve report destination, whether implementation belongs in external `pi-config`, the first unattended host (if any), and the credential/operation allowlist.

Keep this replacement short and link to it from `docs/README.md`. It is a backlog, not instructions to an implementing LLM.

**Verify**:

```bash
git grep -n 'Scheduled read-only reports\|Prompt-debt validation\|Unattended credential isolation\|report destination\|pi-config' -- docs/agent-tooling-backlog.md
```

The command must find each retained topic before the handoff is deleted.

### Step 3: Preserve unresolved recovery and operations work

Create `docs/homelab-backlog.md`. Keep it concise and organized by concrete gate, not historical phases. At minimum assess and preserve:

- off-site encrypted backup destination;
- independent SOPS/identity/key recovery;
- real restore-drill records;
- external heartbeat and alert destinations;
- Cloudflare/Tailscale policy ownership and drift audits;
- optional storage migration/encryption;
- deferred Homepage calendar agenda and secret handling, if still desired;
- any container-retention policy still unresolved.

Link this backlog from `docs/config-ownership-and-recovery.md` or `docs/homelab-recovery.md` without duplicating the procedures.

**Verify**: `git grep -n 'off-site\|restore drill\|heartbeat\|drift\|calendar agenda' docs/homelab-backlog.md docs/config-ownership-and-recovery.md docs/homelab-recovery.md` shows the retained work.

### Step 4: Delete completed plans and handoffs

Delete the LLM handoff, architecture plan, dashboard plan/research, and automation/AI status document after Step 2. Do not archive them under another active docs directory; Git history is the archive.

For `docs/hardware-issues.md`, retain only enduring hardware constraints not already in the headless checklist. Prefer merging the display-hotplug/suspend facts into `docs/beelink-headless-checklist.md` and deleting the standalone incident file. Remove completed transition language such as old kernel/libvirt checks from the checklist.

**Verify**: references to deleted filenames are gone.

### Step 5: Retire version-specific implementation dossiers

Delete `docs/tunarr-research.md` after confirming these durable facts remain near code or in `docs/media-stack.md`:

- do not patch/strip the appended-payload Tunarr executable;
- patch only Meilisearch;
- FFmpeg and Meilisearch path behavior;
- absolute database path and loopback binding;
- operational setup/recovery instructions.

For `docs/cliproxyapi-opencode-provider-research.md`, first inspect Git status:

- If the user's modified `modules/cliproxyapi/README.md` has been committed/landed before this plan starts, confirm that the landed README and `modules/cliproxyapi/config.nix` preserve provider ownership plus protocol/prefix/auth constraints, then delete the research dossier.
- If that README is still dirty or its change was discarded, **retain the research dossier in this plan** and mark its deletion deferred. Do not use uncommitted out-of-scope text as the sole replacement for durable documentation.

Do not edit the modified README in this plan.

**Verify**: every deleted dossier has a committed, in-scope or already-landed authoritative replacement for its non-obvious constraints.

### Step 6: Rewrite the root README

Replace the large tree/input/module catalogs with:

1. a short statement of repository purpose and hosts;
2. an ownership map pointing to `lib/hosts.nix`, `lib/homelab-services.nix`, `machines/`, `homelab/`, `modules/`, `users/maxpw/`, and the external chezmoi/Pi/Fleet ownership boundaries;
3. exact build/check commands from `AGENTS.md` and `Makefile`;
4. a link to `docs/README.md`;
5. safety notes: no automatic activation, secrets stay in SOPS, Determinate owns Joyce's daemon, and state versions are not upgrade knobs.

Do not manually enumerate every input, file, package, or service.

**Verify**: every path named in README exists; stale paths `users/maxpw/packages` and `users/maxpw/fonts.nix` are absent.

### Step 7: Add the documentation index

Create `docs/README.md` with lifecycle categories:

- **Start here / ownership**
- **Recovery and storage**
- **Service runbooks**
- **Platform setup**
- **Accepted decisions**
- **Open backlog**

List only active files. Label `docs/media-stack-research.md` as an accepted decision record despite its filename.

**Verify**: every tracked `docs/*.md` file is either listed or deliberately excluded with a comment in the index.

### Step 8: Validate links and diff

Run the reference and Markdown-link scans. Manually check changed relative links. Run `git diff --check` and `nix flake check --no-build`.

**Verify**: all commands succeed and no modified user-owned CLIProxyAPI files appear in this plan's diff.

## Test plan

Documentation-only verification:

- `git diff --check`;
- grep for deleted filenames and stale paths;
- confirm every unresolved operational item has a surviving location;
- `nix flake check --no-build` as a repository sanity check.

## Done criteria

- [ ] Completed plans/research/handoffs are deleted rather than moved into another active folder.
- [ ] Unresolved recovery and operations work survives in one concise backlog.
- [ ] Unresolved scheduled-report, prompt-debt, and credential-isolation ideas survive in `docs/agent-tooling-backlog.md` with stale claims corrected.
- [ ] Active runbooks remain intact.
- [ ] The Tunarr dossier is no longer active documentation.
- [ ] The CLIProxyAPI dossier is deleted only if its authoritative replacement is committed; otherwise its deferral is recorded.
- [ ] Root README is a concise ownership and workflow map, not a catalog.
- [ ] `docs/README.md` clearly identifies authoritative docs.
- [ ] No stale links or paths remain.
- [ ] User-modified CLIProxyAPI files are untouched.

## STOP conditions

- Any scheduled-report, prompt-debt, credential-isolation, or open agent-tooling decision from the handoff has no explicit destination in `docs/agent-tooling-backlog.md`.
- An unresolved destructive recovery/storage decision has no safe destination.
- A candidate research file is still the only record of a required package provenance or operational workaround.
- The user's CLIProxyAPI README is still uncommitted or does not contain enough durable context; retain the provider research and report the deferral rather than deleting it.
- A deleted file is referenced by automation rather than documentation only.
- The cleanup would require changing live operational instructions without source evidence.

## Maintenance notes

Use Git history as the archive for completed plans. Future research should either become a short accepted decision record, an active runbook, or a tracked backlog item once implementation lands.

## Completion notes

Completed on 2026-09-16 after Plan 003's final Joyce acceptance passed. Current
Fleet documentation now assigns runtime and tunnel supervision to the pinned
standalone input and keeps only inventory, policy, trust, generated files, and
consumer compatibility checks in this repository.

- Unresolved recovery, alerting, provider-policy, storage, calendar, container,
  and security work now lives in `docs/homelab-backlog.md` with concrete gates.
- Deferred reports, prompt-debt checks, credential isolation, and agent-tooling
  decisions now live in `docs/agent-tooling-backlog.md`.
- The completed Fleet handoff, homelab architecture and dashboard plans,
  superseded dashboard research, automation status narrative, hardware incident
  file, and version-specific Tunarr dossier were deleted. Active runbooks and
  the accepted media-stack decision record remain.
- The protected `modules/cliproxyapi/README.md` change is still uncommitted, so
  `docs/cliproxyapi-opencode-provider-research.md` was retained as required by
  the plan's STOP rule. Its later deletion remains deferred until the
  authoritative replacement has landed and can be reviewed.
- The root README is now an ownership and workflow map. `docs/README.md` lists
  every maintained Markdown document and labels the retained provider research.
- Deleted-filename scans, backlog-topic scans, Markdown-link review,
  `git diff --check`, and `nix flake check --no-build` against a disposable
  full-tree source copy passed.
