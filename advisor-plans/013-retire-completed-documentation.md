# Plan 013: Retire completed plans and superseded research

> Execute only when implementation is requested. Git history is the archive: do not move old files into another archive directory. Preserve unrelated work, keep active plans, and update this plan's status in the index. No publishing or live verification is authorized.
>
> Drift check: `git diff --stat 9482048 -- plans advisor-plans docs/README.md docs/agent-tooling-backlog.md modules/fleet/README.md modules/cliproxyapi/README.md docs/cliproxyapi-opencode-provider-research.md`. Plans 010–013 and their index entries were added after the baseline commit and are expected additions. Reconcile intervening implementation outcomes; stop on unexpected changes to retirement candidates.

## Status

- Status: DONE — exact historical set retired and durable constraints moved to maintained owners
- Priority: P2
- Effort: S
- Risk: LOW after preserving unique decisions and open work
- Depends on: 010, 011, 012 (finish the code/test/recovery pass before final documentation retirement)
- Category: docs
- Planned at: commit `9482048`, 2026-09-20

## Context and current state

`docs/README.md:3–4` says: “Git history is the archive for completed plans and superseded research.” Yet the repository retains:

- Six Fleet plans/results totaling 1,166 lines under `plans/`.
- Nine completed cleanup instructions plus their index under `advisor-plans/`, totaling 1,911 lines before this second pass.
- A 461-line CLIProxyAPI research dossier retained pending an uncommitted replacement README.

The Fleet status is contradictory: `plans/README.md:10` says Joyce launchd acceptance is pending and line 22 says preserve the Bash implementation, while `plans/002-fleet-rust-results.md:19–21` records completed acceptance and removal of that implementation. The final results' `Final Joyce acceptance` section distinguishes tested reconnect/pause/resume from physical sleep/wake and locked-credential disruption that were not forced for the final Rust candidate. Do not turn these limitations into claims of success or reintroduce a completed migration as open work.

`advisor-plans/README.md` marks 001–009 DONE. Its rejected/deferred ledger remains useful, especially preservation of layered recovery tests, Leerr provenance, manually used packages, and Git-based archival. Detailed stale working-tree snapshots and executor commands no longer belong in active docs.

The CLIProxyAPI replacement is committed (last README change at audit: `1e3996a`; clean source working tree). `modules/cliproxyapi/README.md` correctly documents Kim-only server ownership. The research at `docs/cliproxyapi-opencode-provider-research.md:401–407` still describes all platforms calling a server renderer. However, sections 5.4 and 6 retain unique deferred protocol/auth constraints and unanswered experiments; preserve a concise version before deleting the dossier.

Use existing concise owner documentation as the pattern: `modules/cliproxyapi/README.md` owns operation/configuration, `modules/fleet/README.md` owns consumer/runtime boundaries, and `docs/agent-tooling-backlog.md` owns unresolved agent workflow decisions. Do not create replacement historical reports.

## Scope

Delete only these historical files:

- `plans/README.md`
- `plans/001-prove-fleet-personal-workflow.md`
- `plans/001-fleet-personal-workflow-results.md`
- `plans/002-extract-fleet-rust.md`
- `plans/002-fleet-rust-results.md`
- `plans/002-fleet-rust-verification.md`
- `advisor-plans/001-use-upstream-jellyfin-packages.md`
- `advisor-plans/002-trim-low-value-tests.md`
- `advisor-plans/003-retire-legacy-fleet.md`
- `advisor-plans/004-consolidate-documentation.md`
- `advisor-plans/005-remove-unused-waybar-assets.md`
- `advisor-plans/006-split-media-module.md`
- `advisor-plans/007-decentralize-backup-version-metadata.md`
- `advisor-plans/008-extract-flake-check-registry.md`
- `advisor-plans/009-centralize-package-update-inventory.md`
- `docs/cliproxyapi-opencode-provider-research.md`

May edit only:

- `advisor-plans/README.md`
- `modules/fleet/README.md`
- `modules/cliproxyapi/README.md`
- `docs/agent-tooling-backlog.md`
- `docs/README.md`
- This plan's status/completion notes

Do not delete plans 010–013 in this execution; they are the current handoff/review record. Retire them only in a later explicitly requested pass after implementation review. Do not edit recovery docs here (plan 012 owns them), accepted media decisions, Leerr provenance, source, tests, agent instructions, or operational data.

## Steps and verification

### 1. Confirm retirement eligibility and preserve a compact decision ledger

Run `git status --short`. Read each retirement candidate fully and verify its completion notes against the maintained owners. Check index rows 010–012 are DONE or explicitly accepted as blocked with their remaining work preserved; otherwise defer this final pass.

Rewrite `advisor-plans/README.md` as a concise current index for 010–013, with their statuses, dependencies, verification notes, and the useful considered/rejected/deferred ledger. Remove old working-tree warnings, completed dependency graphs, and links to 001–009. Record historical 001–009 completion in at most one sentence with baseline commit `9482048` for retrieval.

Keep the ledger's important distinctions: recovery safety layers are not redundant, public host metadata has unaudited external consumers, Leerr provenance is deliberate, Cava/manual CLI packages are not proven dead, YNAB operation generation and T3 Code source-text-test replacement are separate deferred work. Do not copy obsolete plan steps.

Verify: `git diff -- advisor-plans/README.md` retains all current rows and has no historical plan links. No pending item is silently marked DONE.

### 2. Preserve only durable Fleet and provider information

In `modules/fleet/README.md`, add a short acceptance-boundary note if absent: the Rust migration and Joyce reconnect/pause/resume acceptance completed; physical sleep/wake and locked-credential disruption were not forced for the final candidate. Do not copy PIDs, transient generations, source hashes, or full command transcripts. Evaluate stale follow-ups in `plans/README.md` against the current README/consumer code; transfer only those still demonstrably unresolved, not every historical allegation.

In `modules/cliproxyapi/README.md`, preserve a short provider constraints subsection:

- Zen is currently an explicit, prefix-isolated Chat Completions upstream; downstream client protocols do not expand supported upstream protocols.
- Responses integration was deferred/unverified; Anthropic Messages had an authentication-header mismatch; Gemini had a path-construction limitation at the researched upstream revision. Mark those as historical constraints requiring revalidation, not timeless current upstream facts.
- Retain the minimal primary-source links needed to revisit those decisions, and identify billable provider credentials as runtime SOPS material, never Nix literals.

If experiments remain worth tracking, summarize them in a single small subsection of `docs/agent-tooling-backlog.md`; do not preserve the exhaustive dated model catalog, HTTP probes, or code listings. No external probes or live credentials are required to retire the research. The target is a short maintenance note, not a new dossier.

Verify: owner docs remain consistent with `modules/cliproxyapi/config.nix`, `modules/cliproxyapi/README.md`'s Kim-only architecture, and Fleet's current external-runtime ownership. `git diff --check` exits 0.

### 3. Delete the explicit historical file list and repair navigation

Delete exactly the files listed in Scope, not directories using broad globs. Remove the obsolete provider-research retention entry from `docs/README.md`, replacing it with a link to `../modules/cliproxyapi/README.md` in a suitable maintained-doc section.

Do not recreate `plans/` as an archive. Keep accepted `docs/media-stack-research.md`, both concise backlog docs, all runbooks, and active advisor plans intact.

Verify the deletion set with `git diff --name-status` and run:

```sh
python3 - <<'PY'
import pathlib
assert not pathlib.Path('plans').exists() or not list(pathlib.Path('plans').iterdir())
for n in range(1, 10):
    assert not list(pathlib.Path('advisor-plans').glob(f'{n:03d}-*.md'))
for n in range(10, 14):
    assert len(list(pathlib.Path('advisor-plans').glob(f'{n:03d}-*.md'))) == 1
assert not pathlib.Path('docs/cliproxyapi-opencode-provider-research.md').exists()
assert pathlib.Path('docs/media-stack-research.md').is_file()
print('Historical files retired; current plans and accepted decision retained')
PY
```

Expected: exit 0. If new untracked user files exist in `plans/`, stop rather than deleting them to satisfy the check.

### 4. Check links and final documentation diff

Run this local link-target check. It ignores URL and anchor-only links and does not claim to validate web pages or Markdown anchors:

```sh
python3 - <<'PY'
import pathlib, re, subprocess
files = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard'], text=True).splitlines()
broken = []
for name in set(files):
    p = pathlib.Path(name)
    if p.suffix != '.md' or not p.is_file():
        continue
    for line_no, line in enumerate(p.read_text().splitlines(), 1):
        for target in re.findall(r'\]\(([^\s)]+)(?:\s+[^)]*)?\)', line):
            target = target.split('#')[0]
            if not target or '://' in target or target.startswith(('mailto:', '/')):
                continue
            if not (p.parent / target).exists():
                broken.append(f'{p}:{line_no}: {target}')
assert not broken, '\n'.join(broken)
print('Relative Markdown file links passed')
PY
git diff --check
git diff --stat
```

Expected: exit 0 for all checks and only allowed changes. Remaining historical filenames inside the active plans are provenance references, not links to maintained files; do not delete new plans merely to erase these search hits. No Nix build or shell test suite is required for this documentation-only plan.

## Done criteria and maintenance

- [x] Exactly the 16 historical files are removed; active plans remain.
- [x] Current owner docs retain unique constraints, acceptance limits, and unresolved decisions without copied transcripts.
- [x] Historical plans 001–009 no longer appear as active links in the index.
- [x] Local Markdown link check and `git diff --check` pass.
- [x] No runtime, test, runbook safety, provenance, or accepted-decision content is lost.
- [x] Plan/index are DONE with deletion and preservation summary.

## Completion notes

Completed on the isolated integration branch after reading every retirement
candidate and reconciling it against the maintained owners and the accepted
010–012 execution reviews.

- Removed only the 16 files listed in Scope; kept plans 010–013, all runbooks,
  the accepted media decision record, Leerr provenance, both active backlogs,
  and the public host-metadata shape.
- Preserved the completed Rust migration and Joyce reconnect/pause/resume
  acceptance boundary in `modules/fleet/README.md`. Physical sleep/wake and
  locked-credential disruption were not forced for the final Rust candidate.
- Preserved Zen as an explicit prefix-isolated Chat Completions upstream, with
  dated Responses, Anthropic Messages, and Gemini limitations marked for
  revalidation. Billable credentials remain runtime SOPS material.
- Inspected repository source and metadata and ran local documentation checks.
  No live provider probe, credential use, network test, activation, service
  operation, restore, archive inspection, or physical sleep/wake test was
  performed by this cleanup.

Stop if a retired plan is actually incomplete, unique safety information lacks a maintained owner, the protected README acquires unrelated user changes, or updating links requires files outside scope. Report rather than broadening deletion.

Suggested commit if requested: `Retire completed plans and superseded provider research`. Future plans should have a retirement condition: after reviewed completion, move only durable decisions/open work into owner docs and let Git retain the execution record.
