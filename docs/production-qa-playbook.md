# Production QA and release playbook

A reusable strategy for testing a web application with several AI agents (or
people): multi-persona QA against production, parallel fixes, one integration
owner, full gates, independent re-test, an explicitly authorized release, and a
production smoke test. It is written to be copied into any repository; replace
the `<placeholders>` and delete what does not apply.

It is distilled from a real run that found 30+ issues across five personas,
fixed them in five parallel branches, caught one regression in independent
review, and shipped two releases. The lessons from that run are folded into the
rules below and summarized in [Lessons that shaped these rules](#lessons-that-shaped-these-rules).

## Contents

1. [Principles](#principles)
2. [Roles and threads](#roles-and-threads)
3. [Phase overview](#phase-overview)
4. [Accounts, authentication, and data safety](#accounts-authentication-and-data-safety)
5. [Read-only and write guards](#read-only-and-write-guards)
6. [Persona QA](#persona-qa)
7. [Viewport and device coverage](#viewport-and-device-coverage)
8. [Evidence hygiene](#evidence-hygiene)
9. [Severity, classification, and deduplication](#severity-classification-and-deduplication)
10. [Parallel fix agents](#parallel-fix-agents)
11. [Integration ownership](#integration-ownership)
12. [Local and CI gates](#local-and-ci-gates)
13. [Independent post-fix QA](#independent-post-fix-qa)
14. [Release authorization](#release-authorization)
15. [Production smoke tests](#production-smoke-tests)
16. [Rollback and stop criteria](#rollback-and-stop-criteria)
17. [Orchestration and archiving](#orchestration-and-archiving)
18. [Report templates](#report-templates)
19. [Suggested repository files and scripts](#suggested-repository-files-and-scripts)
20. [Adopting this in a new repository](#adopting-this-in-a-new-repository)
21. [Lessons that shaped these rules](#lessons-that-shaped-these-rules)

## Principles

- **Production is observed, not changed.** QA against production is read-only
  unless a specific write is authorized in advance, on a specific account, for a
  specific purpose.
- **Every irreversible step has its own approval.** Inviting accounts, merging,
  releasing, and changing shared infrastructure are separate decisions. Approval
  for one never implies another.
- **One owner per shared resource.** One agent owns invitations, one owns the
  integration branch, one owns the release. Others ask that owner.
- **Confirmed, blocked, and reported are different things.** A finding is either
  reproduced by the reporter, blocked by the environment, or reported by someone
  else and not reproduced. Never promote the latter two to bugs silently.
- **Test the real path.** A unit test of a validator does not prove the router,
  the framework, or the deployed edge behaves. Every fix needs at least one test
  through the public interface (a real URL, request, or rendered page).
- **Evidence is shareable by default.** If a screenshot cannot be shared safely,
  crop or delete it before it leaves the agent.
- **Stop at humans-only barriers.** CAPTCHAs, bot challenges, 2FA prompts for
  real people, and payment confirmations are handed to a human. Agents never
  solve or bypass them.

## Roles and threads

| Role | Count | Owns | Must not |
|---|---|---|---|
| Orchestrator | 1 | Plan, briefing, relaying blockers, asking the user for approvals, final report, archiving | Edit code, approve its own requests, archive without confirmation |
| Setup owner | 1 (often a QA agent) | Creating or inviting test accounts, seeding fixtures | Let other agents duplicate setup |
| Persona QA agents | 3–5 | One persona, one account each, a findings report | Write to production, fix code |
| Fix agents | 1 per fix area | One branch from a named base commit, tests, a fix report | Push to the default branch, touch files another area owns without coordinating |
| Integration owner | 1 | The integration branch, merges, full gate, PR | Merge to the default branch or release without approval |
| Independent reviewer | 1 | Re-testing the integrated change from a clean checkout | See the fix agents' conclusions before testing |
| Release owner | 1 (often the integration owner) | Tag/deploy, smoke test, rollback decision | Release without explicit authorization |

Each child thread receives: the goal, the target URL or commit, its account (by
reference, never a password in the prompt if a secret store exists), the
guard rules from this document, where to save evidence, and the exact reply
route back to the orchestrator.

## Phase overview

```text
0. Prepare      accounts, guards, evidence folder, target resolution
1. Persona QA   parallel, read-only, production or staging
2. Triage       dedupe, classify, rank, group into fix areas
3. Fix          parallel fix agents, one area each, local commits
4. Integrate    one owner merges, full gate after each merge, PR
5. Re-test      independent reviewer on the integrated build
6. Approve      user approves merge, then (separately) release
7. Release      tag/deploy by the release owner
8. Smoke        signed-out then authenticated, before/after comparison
9. Close        final report, follow-ups filed, threads archived on confirmation
```

Each phase has an exit condition. Do not start a phase until the previous one's
exit condition holds:

| Phase | Exit condition |
|---|---|
| Prepare | Every agent can sign in, or the blocker is handed to a human |
| Persona QA | Every persona report is in, with coverage and evidence lists |
| Triage | Deduplicated issue list with severity, status, and fix-area owner |
| Fix | Every area reports tests that fail without the fix and pass with it |
| Integrate | Full gate green on the integration branch; CI green on the PR |
| Re-test | No FAIL from the independent reviewer, or failures fixed and re-tested |
| Approve | Explicit user approval recorded for merge, and separately for release |
| Release | Deploy job succeeded; deployed version matches the tagged commit |
| Smoke | Smoke checklist passes, or a stop/rollback decision is made |
| Close | Report sent; unresolved items listed; archiving confirmed by the user |

## Accounts, authentication, and data safety

### Test accounts

- Use **dedicated test accounts only**, one per agent, named so they are
  obviously synthetic (`qa-bot-1` … `qa-bot-N`, `qa-bot-N@<test-domain>`).
- Record the accounts in a repository-local inventory (see
  [`qa/accounts.md`](#suggested-repository-files-and-scripts)) with role, tenant,
  and what data they can see. Store credentials in the secret manager, not in
  Git, prompts, reports, or screenshots.
- Cover the role matrix you care about. At minimum: signed-out, ordinary
  member, a second tenant (for cross-tenant isolation), and an elevated role if
  admin surfaces exist. If a role is missing, list it as a coverage gap in the
  report rather than borrowing a real person's account.
- Test accounts must not be able to trigger real-world effects: no real payment
  methods, no outbound email to real customers, no access to real customers'
  private data beyond what the test requires.
- If test accounts are attached to real tenant data (for example, members of a
  real customer's workspace), treat every screen as private data for evidence
  purposes.

### Provisioning

- Decide in advance who creates the accounts. If production is invitation-only
  or protected by a bot challenge, **a human pre-creates the accounts** before
  QA starts. Agents do not attempt sign-up through a CAPTCHA.
- Exactly one agent (the setup owner) performs any invitation or seeding. All
  other agents are told explicitly not to.
- Prefer a staging or preview environment with seeded fictional data for any
  test that needs writes (invitation flows, form submission, payments in test
  mode).

### Email-code and magic-link authentication

- Give each test account its own inbox or alias so codes cannot be confused
  between agents running at the same time.
- Read codes through an authorized mailbox integration (for example an MCP
  mail tool). Use only the newest code addressed to that agent's account, and
  match it to the request time.
- Never paste codes, magic links, or session cookies into reports, commits, or
  other threads. They are credentials while valid.
- Mailbox sessions expire. Check the mail integration works during Prepare, and
  report "auth blocked: mailbox integration needs re-login" as a blocker rather
  than switching to another agent's account.
- If password sign-in fails for one account, try its documented fallback
  (email code) once; if that also fails, mark that account's coverage as
  blocked. Do not reset passwords on production without approval.

### Data safety rules

1. No writes to production data without a pre-approved, written exception
   naming the account, the action, and the cleanup.
2. No access attempts on other users' or tenants' data beyond URL-guessing
   with your own session to confirm a 403/404. No auth bypass, credential
   stuffing, fuzzing at volume, or denial-of-service testing.
3. No automated load: keep request rates human-like; no parallel crawlers
   against production.
4. No changes to shared infrastructure (DNS, CDN, WAF, zone settings, identity
   provider configuration) from QA or fix threads. File them as follow-ups for
   the owner.
5. Delete local copies of exported data (PDFs, CSVs) when the run ends unless
   they are fictional.

## Read-only and write guards

Layer the guards; prompts alone are not enough.

1. **Prompt rule.** Each QA prompt lists the forbidden actions: create, edit,
   delete, submit, pay, invite, react, comment, send email, change settings.
   Allowed: navigate, open forms, type into fields, trigger client-side
   validation, cancel, download existing documents.
2. **Browser guard.** Inject a script that blocks same-origin non-GET requests
   before the app loads. Third-party analytics beacons may still appear; list
   them separately in the report.
3. **Network log check.** At the end of the session, export the request log and
   confirm zero same-origin `POST`/`PUT`/`PATCH`/`DELETE` requests. Report the
   count.
4. **Signed-out probes.** Use `GET`/`HEAD` with no cookies (`curl -sI`).

Example browser guard (adapt to your browser driver; inject as an init script
so it runs before application code):

```js
// qa/guards/read-only.js — blocks same-origin writes in the page.
(() => {
  const SAFE = new Set(["GET", "HEAD", "OPTIONS"]);
  const sameOrigin = (url) => new URL(url, location.href).origin === location.origin;
  const blocked = (method, url) => {
    console.warn(`[qa-guard] blocked ${method} ${url}`);
    return new Error(`qa-guard: ${method} blocked`);
  };

  const origFetch = window.fetch;
  window.fetch = function (input, init = {}) {
    const url = typeof input === "string" ? input : input.url;
    const method = (init.method || (input instanceof Request ? input.method : "GET")).toUpperCase();
    if (!SAFE.has(method) && sameOrigin(url)) return Promise.reject(blocked(method, url));
    return origFetch.apply(this, arguments);
  };

  const origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function (method, url) {
    if (!SAFE.has(String(method).toUpperCase()) && sameOrigin(url)) throw blocked(method, url);
    return origOpen.apply(this, arguments);
  };

  document.addEventListener("submit", (event) => {
    const form = event.target;
    const method = (form.method || "GET").toUpperCase();
    if (!SAFE.has(method) && sameOrigin(form.action || location.href)) {
      event.preventDefault();
      event.stopImmediatePropagation();
      console.warn(`[qa-guard] blocked form ${method} ${form.action}`);
    }
  }, true);

  const origBeacon = navigator.sendBeacon?.bind(navigator);
  if (origBeacon) {
    navigator.sendBeacon = (url, data) =>
      sameOrigin(url) ? (console.warn(`[qa-guard] blocked beacon ${url}`), false) : origBeacon(url, data);
  }
})();
```

The guard does not cover every write path (WebSockets, server actions using
GET, service workers). It is a safety net, not permission to click "Save".

**What read-only costs.** Some fixes (invitation callbacks, post-submit focus,
confirmation emails) cannot be verified in production read-only. Verify them in
staging or locally with fictional data, and mark them "verified locally only"
in the smoke report.

## Persona QA

Run each persona in its own thread with its own account so sessions, cookies,
and mailbox codes do not collide. Every persona covers the same core journeys
first, then its own focus.

**Core journeys (all personas):** sign in, land on the main dashboard, visit
every primary navigation section, open one detail page per object type,
download one existing document, open (not submit) the main forms, sign out,
press Back after sign-out.

| Persona | Focus | Typical checks | Typical finds |
|---|---|---|---|
| Speed-runner | The fastest path to each goal; impatience | Time to first useful screen, double-clicks, Back/forward, deep links, dead ends after errors, perceived latency (note rough timings, not benchmarks) | Error states with no recovery link, slow loaders, missing status values |
| Meticulous auditor | Correctness and consistency | Validation messages, empty/boundary inputs, units and formatting, titles, 404/405 pages, HTTP methods on endpoints, copy consistency | Bare error pages, wrong status codes, validation hidden behind sticky headers |
| Skeptical adversary (non-destructive) | Trust boundaries without attacking | Tampered query parameters, invalid IDs, other tenants' IDs with own session, script-like input (inert, not submitted), signed-out API access, security headers, cookies flags, leaks in page source | Raw error/schema text exposed, misleading error states, missing headers |
| Confused newcomer | First-use comprehension | Labels, navigation names, empty states, onboarding copy, search affordances, jargon | Features hidden under unexpected names, empty pages with no guidance, search that only works on Enter |
| Accessibility and polish | WCAG 2.2 AA and finish | Keyboard-only paths, focus order and return, Escape/outside-click on popovers, live regions, contrast, names for controls, headings/landmarks, zoom 200 %, reduced motion | Focus dropped to `body`, low-contrast errors, menus that ignore Escape |

Adversary boundaries, stated in its prompt: no auth bypass attempts, no
brute force, no injection payloads submitted to the server, no scanning tools,
no rate beyond a person clicking. Observing and reporting is the job.

**Persona QA checklist (per agent):**

- [ ] Resolved the target URL from repository config, not guessed; recorded it
- [ ] Browser guard injected; signed in with own account only
- [ ] Core journeys done at desktop width
- [ ] Persona focus done
- [ ] Narrow-width pass done (see next section)
- [ ] Network log: same-origin non-GET count recorded
- [ ] Every finding has steps, expected, actual, evidence, severity, status
- [ ] Coverage gaps and blockers listed separately from findings
- [ ] Evidence reviewed for secrets and private data
- [ ] Report sent to the orchestrator

## Viewport and device coverage

| Width × height | Purpose |
|---|---|
| 1280 × 720 | Default desktop |
| 1440 × 900 or wider | Wide layouts, max-width containers |
| 768 × 1024 | Tablet / breakpoint edge (optional) |
| 390 × 844 | Typical phone |
| 320 × 568 | Smallest supported phone; overflow and truncation |

- Capture at 2× device pixel ratio so screenshots are legible.
- At each narrow width check: horizontal overflow (`document.documentElement.scrollWidth > innerWidth`),
  sticky headers covering focused fields or errors, bottom navigation reachability,
  tap target size, truncated labels, modals that cannot scroll.
- State the limitation in every report: emulated Chromium widths are not real
  touch devices or Safari/WebKit. List anything that needs a real device.

## Evidence hygiene

- Save evidence under one predictable folder per run, for example
  `.amp/in/artifacts/qa/<run-id>/<persona>/` or `qa/runs/<run-id>/` (ignored by
  Git). Name files `NN-short-description.png`.
- **Inspect every image before sharing it.** Look for passwords in fields,
  codes, tokens in URLs, session IDs, emails of real people, financial values,
  addresses.
- Crop to the element that shows the issue. Prefer a crop of a status badge
  over a full page of invoices.
- Trim recordings to the interaction; delete broad recordings that show private
  data instead of sharing them.
- Use fictional values in any text typed for validation tests.
- Report lists include only files that are "safe to share"; everything else is
  deleted at the end of the run.
- Never commit QA evidence from production to the repository.
- For network evidence, record method, path, status, and relevant headers;
  strip cookies, `Authorization`, and query tokens.

## Severity, classification, and deduplication

Use one scale for the whole run, defined in the orchestrator's first prompt.

| Severity | Meaning | Examples | Release impact |
|---|---|---|---|
| S1 Critical | Data loss, security or privacy breach, payment error, total outage of a core journey | Another tenant's data visible; charges wrong | Stop. Fix or roll back before anything else |
| S2 High | Core journey blocked or wrong for many users, no workaround | Sign-in dead end; invoices show wrong status | Must fix before release |
| S3 Medium | Degraded journey with a workaround; accessibility failure on a main path; misleading errors | Validation hidden behind a header; contrast fails AA | Fix in this cycle if feasible |
| S4 Low | Polish, copy, minor inconsistency | Missing page titles; unit toggle does not convert | Batch or backlog |

Every finding also gets a **status**:

- `confirmed` — reproduced by the reporter, with evidence.
- `blocked` — the environment prevented testing (CAPTCHA, missing account,
  expired mailbox session). Not a product defect.
- `reported` — someone else saw it (for example, the user); not reproduced.
- `by-design?` — behavior looks intentional; needs the owner's decision.

**Deduplication.** The orchestrator merges findings when they share a root
cause or a fix location, not merely a page. Keep every reporter's ID in the
merged issue (`Q-07 ← speed-runner#3, newcomer#5`) so coverage is traceable.
Then group issues into **fix areas** that map to code ownership (for example
"auth recovery", "error pages and HTTP methods", "billing status", "form
accessibility", "navigation and empty states"). Two areas should not need the
same files; if they do, merge the areas or name an order.

If an issue tracker is connected, create one issue per deduplicated finding
with the template below. If not, keep the deduplicated list in the run report
and say that no tracker issues were created.

## Parallel fix agents

- Every fix agent starts from the **same named base commit** (`origin/<default>`
  at `<sha>`), recorded in its prompt.
- One agent per fix area. Its prompt lists the issue IDs, the files it is
  expected to touch, the other areas and their likely files, and the reply
  route.
- Each agent:
  - writes a regression test through the public interface that fails before
    the fix and passes after, and reports both runs;
  - runs the full local gate (below), not only its own tests;
  - commits locally on its own branch and does **not** push or open a PR
    unless told to;
  - reports the commit SHA, files changed, gates run with counts, root cause
    (or "unconfirmed" with what evidence is missing), and merge risks (shared
    files, lockfile or dependency changes, schema changes).
- When two agents need the same dependency or file, the orchestrator names who
  adds it; the other rebases on it or leaves it out.
- Root causes involving external systems (third-party APIs, data providers)
  must be confirmed with captured raw values, not inferred from UI symptoms.

## Integration ownership

One integration owner, in one thread, with one branch (`integrate/<run-id>`):

1. Fetch each fix commit (push to a shared remote branch, or transfer
   unpushed work between workspaces) and confirm the SHA matches the report.
2. Merge areas one at a time in a stated order. After **each** merge, run the
   full local gate; a failure is attributed to the last merge.
3. Resolve conflicts itself, then tell the affected fix agent what changed.
4. Push the integration branch and open a PR only when asked to (or when the
   repo's policy says so). The PR description lists every issue ID, every
   source commit, gate counts, and **unresolved notes** (unconfirmed root
   causes, behavior changes, things not rendered).
5. Never merge to the default branch or release until explicitly approved.

## Local and CI gates

The gate is the full set of checks CI runs, plus anything CI cannot run. Put it
behind one command so every agent runs the same thing.

**Typical gate contents (adapt per stack):**

- [ ] Install from lockfile (frozen; fail if the lockfile would change)
- [ ] Format check
- [ ] Lint
- [ ] Type check
- [ ] Unit tests
- [ ] Integration tests through real routes/requests
- [ ] Architecture/boundary checks (for example, server-only code must not reach
      the client bundle)
- [ ] Route or schema generation is up to date
- [ ] Production build
- [ ] Production-only checks (bundle analysis, CSS extraction, deploy dry-run or
      plan showing what will change)
- [ ] Rendered UI check of changed screens (screenshots inspected), using
      synthetic auth keys and fictional seeded data when real keys are absent

Rules:

- Pin tool versions (via Nix, `mise`, `.tool-versions`, or Volta) so local and
  CI runs match. Record versions in reports.
- Report counts (`unit 164 passed, integration 116 passed`), not "tests pass".
- A skipped third-party review bot (rate limit, plan limit) is not a pass; note
  it.
- CI must be green on the integration PR before the re-test verdict is final.

## Independent post-fix QA

- A **fresh** reviewer thread tests the integrated branch from a clean checkout.
  Its prompt gives the issue list and the expected behavior, not the fix
  agents' conclusions.
- It runs the app locally (or on a preview deploy) with fictional seeded data
  and synthetic credentials, so it can exercise writes safely. It must not test
  stale production as if it were the fix.
- For each issue: PASS / FAIL / NOT VERIFIABLE, with evidence and, for FAIL, the
  minimal reproduction (exact URL, input, state).
- It also probes around each fix: neighboring parameters, framework behavior
  (for example, router state merging that keeps invalid values alive), and the
  same bug class on other pages.
- A FAIL returns to the integration owner (or the original fix agent), gets a
  real-path regression test, and is re-tested by the same reviewer. The merge
  waits for a clean re-test.

## Release authorization

- Know the release mechanism and write it in the repo's release doc: what
  deploys (merge to main? a pushed tag? a manual workflow?), and what the plan
  step shows (code only, database migrations, storage changes).
- **Merge approval and release approval are separate.** Ask for each with a
  concrete, reviewable request:

  > Approve releasing `v<x.y.z>` from `<sha>` to production? It deploys the
  > application only; no database migrations or storage changes. Changes: Q-01
  > … Q-14. Re-test: all PASS. Rollback: redeploy `v<x.y.z-1>`.

- A user instruction such as "fix all of these then release" authorizes the
  release of that fix set only. It does not authorize later releases or
  infrastructure changes.
- The release owner refuses to release without approval even if every check is
  green.
- Shared infrastructure changes (CDN/zone settings, DNS, identity provider) are
  never part of an app release; file them for their owner.

## Production smoke tests

Run immediately after the deploy reports success. Capture a **before** baseline
for the same checks just before releasing, so the report can show changes.

### Signed-out (no cookies, `GET`/`HEAD` only)

- [ ] Deployed version or commit matches the release (version endpoint, header,
      or asset hash)
- [ ] Home and sign-in pages return 200 with expected titles
- [ ] HTTP redirects to HTTPS; HSTS and other security headers present
- [ ] Protected pages redirect to sign-in; protected APIs return 401/403
- [ ] Unknown page returns a styled 404 with heading, landmark, and a way home;
      unknown API path returns a JSON 404
- [ ] Wrong HTTP method returns 405 with `Allow`
- [ ] Each fixed URL-level behavior (redirects, canonicalization, invalid
      parameters) behaves as specified
- [ ] No server error text, stack traces, or internal identifiers in responses

### Authenticated (test accounts, read-only guard on)

- [ ] Each test account can sign in by its primary method
- [ ] Core journeys load without errors at desktop and 390 px
- [ ] Each fixed issue: PASS / PARTIAL / NOT VERIFIABLE LIVE (with the reason,
      for example "needs a second tenant" or "needs a write")
- [ ] Browser console: no new errors; network: no failed requests, zero
      same-origin writes
- [ ] Spot timings for key pages compared with the baseline (note, do not
      benchmark)

Record anything that could only be verified locally or by tests so nobody
assumes it was checked in production.

## Rollback and stop criteria

Write the rollback mechanism down **before** releasing: the previous good
version, the command or workflow that redeploys it, and whether data changes
(migrations) are reversible. If a migration is not reversible, the release
needs an explicit forward-fix plan instead.

**Stop the run immediately and hand to a human when:**

- an agent meets a CAPTCHA, bot challenge, or a real person's 2FA prompt;
- an action would write to production outside an approved exception;
- an agent sees data it should not be able to see (treat as S1, stop testing
  that area, report privately);
- credentials, codes, or private data appear in an artifact that was already
  shared;
- a mailbox or secret integration needs a human to re-authenticate.

**Roll back (or ask to roll back) when, after a release:**

- any S1 appears, or a core journey that worked in the baseline now fails;
- error rates or 5xx responses rise above the baseline;
- the deployed version does not match the approved commit;
- a smoke check fails and no forward fix can ship in `<agreed window, e.g. 30 min>`.

Rolling back is itself a production action: the release owner proposes it with
the evidence, and executes it on approval unless the repo's release doc grants
standing permission for rollbacks.

**Block (do not proceed to the next phase) when:**

- the independent re-test has any FAIL;
- CI is not green on the exact commit to be merged or released;
- an unresolved note in the PR changes user-visible behavior and has no
  decision.

## Orchestration and archiving

- The orchestrator keeps a **run ledger** (in its thread or a file): every
  child thread with its role, account, branch, status, and last report.
- Each child prompt contains the reply route (the orchestrator's thread ID) and
  asks for findings, evidence paths, gates, and blockers in the reply. Children
  reply when done or blocked; the orchestrator does not poll and wait at the
  same time.
- Relay credentials by secret-store reference. Relay blockers to the user in
  one message per decision, with the options.
- Avoid acknowledgment loops: replies that need no action get none.
- **Archiving:**
  1. List candidate threads (dry run) and mark which are still active
     (integration, release, anything awaiting a reply).
  2. Ask the user to confirm the exact list.
  3. Archive only after an explicit confirmation. A child's report arriving is
     not confirmation.
  4. Never archive the integration or release thread while a follow-up is
     possible; archived threads cannot receive messages.
  5. Archive after the final report is sent, not before.

## Report templates

### Persona QA report

```markdown
# QA report — <persona> — <run-id>

Target: <URL> (resolved from <config file>) · Build: <version/commit>
Account: <qa-bot-N> (<role>, <tenant>) · Date: <YYYY-MM-DD>
Browser: <engine/version> · Viewports: 1280×720, 390×844, 320×568 @2×
Guard: read-only script on · Same-origin non-GET requests: <0>

## Summary
<two or three sentences: worst finding, overall impression>

## Findings
| ID | Sev | Status | Title | Page/URL | Evidence |
|---|---|---|---|---|---|
| <persona>#1 | S2 | confirmed | <title> | <path> | 01-<name>.png |

### <persona>#1 — <title>
- Steps: 1. … 2. …
- Expected: …
- Actual: …
- Viewport/account: …
- Notes: <root-cause guess clearly marked as a guess>

## Passed checks
- <what was tried and behaved correctly>

## Coverage gaps and blockers
- <role/tenant/flow not covered and why>

## Evidence (safe to share)
- <path> — <what it shows>
```

### Deduplicated issue

```markdown
## Q-<NN> <title>
Severity: S<n> · Status: confirmed | reported | blocked | by-design?
Sources: <persona>#<n>, <persona>#<n>
Fix area: <area> · Owner: <fix thread>
Where: <URL/route/component>
Reproduction: <minimal steps>
Expected / actual: …
Evidence: <file>
Acceptance: <observable condition that proves it is fixed>
```

### Fix-agent report

```markdown
# Fix report — <area>
Base: origin/<default> @ <sha> · Branch: fix/<area> · Commit: <sha> (not pushed)
Issues: Q-01, Q-04
Root cause: <confirmed with evidence | unconfirmed: missing …>
Change: <what the code now does, in the code's terms>
Regression tests: <names> — fail before (<n> failing), pass after
Gate: format ✓ lint ✓ types ✓ unit <n> ✓ integration <n> ✓ build ✓ <extra> ✓
Tool versions: <runtime x.y>, <package manager x.y>
Merge risks: <shared files, lockfile, dependency, schema>
Not verified: <rendered UI, production-only behavior>
```

### Integration report / PR description

```markdown
# Integration — <run-id>
Branch: integrate/<run-id> @ <sha> · Base: <sha>
Merged (in order): fix/<a> <sha>, fix/<b> <sha>, …
Gate after each merge: ✓ (final counts: unit <n>, integration <n>, …)
CI: <workflow> ✓ on <sha>
Issues addressed: Q-01 … Q-NN
Unresolved notes:
- <behavior change or unconfirmed root cause needing a decision>
Not done: merge to default branch, release (awaiting approval)
```

### Independent re-test report

```markdown
# Re-test — integrate/<run-id> @ <sha>
Environment: local | preview <URL> · Data: fictional seed · Auth: synthetic
| Issue | Result | Evidence | Notes |
|---|---|---|---|
| Q-01 | PASS | 01-….png | |
| Q-05 | FAIL | 05-….png | <minimal repro> |
Probes around fixes: <what else was tried>
Verdict: merge | do not merge (reason)
```

### Release and smoke report

```markdown
# Release <version> — <date>
Approved by: <user> in <thread/message> · Commit: <sha> · Run: <CI run link>
Plan: <app only | migrations | storage>
Deployed version check: <how> ✓

## Signed-out smoke (before → after)
| Check | Before | After |
|---|---|---|

## Authenticated smoke
| Issue/check | Account | Result | Evidence |
|---|---|---|---|

Not verifiable live: <items and why; covered by which tests>
Rollback: not needed | performed (<what, when, approved by>)
Follow-ups: <infra items for owners, deferred issues>
```

## Suggested repository files and scripts

Add only what the project needs; names are suggestions.

| Path | Contents |
|---|---|
| `docs/qa/README.md` | This playbook, trimmed to the project, or a link to it |
| `docs/qa/accounts.md` | Test-account inventory: name, role, tenant, sign-in method, secret-store reference, known issues. No secrets |
| `docs/qa/environments.md` | Production, staging, preview, local: URLs, how each is resolved from config, which allow writes, seeded data |
| `docs/qa/journeys.md` | Core journeys and the persona focus list for this product |
| `docs/release.md` | What deploys, how to release, approval rule, rollback command, migration policy |
| `qa/guards/read-only.js` | The browser write guard |
| `qa/smoke/signed-out.sh` | `curl` checks for status codes, redirects, headers, version |
| `qa/smoke/authenticated.md` | Checklist (or a browser script) for authenticated smoke |
| `qa/seed/` | Fictional fixture data and a seeding script for local/preview |
| `scripts/gate` or a `make gate` / `bun run gate` target | The full local gate in one command |
| `.gitignore` | `qa/runs/` and any local evidence folders |
| `AGENTS.md` | Short pointers: gate command, release rule, "production is read-only for QA", where QA docs live |

Example signed-out smoke script:

```sh
#!/usr/bin/env bash
# qa/smoke/signed-out.sh — read-only checks; no cookies, GET/HEAD only.
set -euo pipefail
: "${BASE_URL:?BASE_URL must be set, e.g. https://app.example.com}"

fail=0
check() { # name, expected status, curl args...
  local name=$1 want=$2; shift 2
  local got
  got=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$@") || true  # 000 on network failure
  if [[ $got == "$want" ]]; then echo "PASS $name ($got)"; else echo "FAIL $name (want $want, got $got)"; fail=1; fi
}
header() { # name, header regex, url
  local headers
  headers=$(curl -sI --max-time 15 "$3") || true
  if grep -qiE "$2" <<<"$headers"; then echo "PASS $1"; else echo "FAIL $1"; fail=1; fi
}

check "home"                  200 "$BASE_URL/"
check "unknown page is 404"   404 "$BASE_URL/qa-does-not-exist"
check "protected API is 401"  401 "$BASE_URL/api/<protected-endpoint>"
check "wrong method is 405"   405 -I "$BASE_URL/api/<post-only-endpoint>"
check "http redirects"        308 "${BASE_URL/https:/http:}/"   # or 301, per your edge
header "HSTS"            '^strict-transport-security:' "$BASE_URL/"
header "CSP"             '^content-security-policy:'   "$BASE_URL/"
header "no framing"      '^(x-frame-options:|content-security-policy:.*frame-ancestors)' "$BASE_URL/"

exit $fail
```

`-I` sends `HEAD`; for a 405 check, make sure the endpoint rejects `HEAD` the
same way it rejects `GET`, or use `-X GET` with a body-less request.

## Adopting this in a new repository

1. **Copy** this file to `docs/qa/README.md` (or link to it) and delete
   sections that do not apply.
2. **Write the environment map** (`docs/qa/environments.md`): where production
   is configured, whether a staging/preview environment exists, which allows
   writes, and how to seed fictional data locally.
3. **Define the gate** as one command that mirrors CI, and pin tool versions.
   Run it once on a clean checkout and record counts and duration.
4. **Write the release doc**: what deploys, the approval rule, the rollback
   command, and the migration policy. If there is no rollback, say so.
5. **Create test accounts** (a human does this if sign-up is gated), one per
   persona plus a second tenant and an elevated role if relevant. Add them to
   `docs/qa/accounts.md` and the secret store. Verify each can sign in and
   that email codes arrive in its own inbox.
6. **Add the guard and smoke script** (`qa/guards/read-only.js`,
   `qa/smoke/signed-out.sh`) and run the smoke script against production
   once to get a baseline. Fix false failures in the script, not the
   expectations.
7. **Write the journeys** (`docs/qa/journeys.md`): the five to ten things a
   user must be able to do, and product-specific persona focus.
8. **Add AGENTS.md pointers** so every agent finds the gate, the read-only
   rule, the release rule, and the QA docs without being told.
9. **Dry run** one persona against staging (or production read-only) and
   adjust the templates to the project.
10. **Decide the severity scale and tracker** before the first full run, and
    put both in the orchestrator's first prompt.

**Readiness checklist:**

- [ ] Target URLs resolvable from config
- [ ] Writes-allowed environment with fictional data exists (or its absence is
      recorded as a coverage gap)
- [ ] Test accounts created, inventoried, sign-in verified
- [ ] Mail integration for codes works per account
- [ ] Gate command green on a clean checkout
- [ ] Release and rollback documented
- [ ] Guard script and smoke baseline in place
- [ ] Evidence folder ignored by Git

## Lessons that shaped these rules

- Invitation-only sign-up plus a bot challenge stopped every agent at
  onboarding. Pre-create accounts with a human; agents never solve CAPTCHAs.
- Five agents almost sent duplicate invitations. One setup owner fixes that.
- A validator's unit test passed while the router merged parent and child
  search parameters and kept an invalid value alive. Independent re-test with
  real URLs caught it; real-path tests are now mandatory.
- Placeholder auth keys blocked rendered-UI checks in sandboxes. Synthetic keys,
  a locally signed session token, and fictional seeded data made local
  rendering possible.
- A third-party status bug looked like a UI issue until raw API values were
  captured. Confirm external root causes with data.
- All test accounts belonged to one real tenant with one role, so cross-tenant
  and role checks stayed incomplete. Plan the role matrix up front.
- One account's password silently failed and the mailbox integration later
  needed re-login, leaving that persona unverified. Check auth during Prepare.
- Read-only production QA cannot verify write-path fixes. Say "verified locally
  only" instead of implying production coverage.
- Merge, release, and shared-infrastructure changes were each approved
  separately; an infrastructure setting stayed with its owner.
- A bulk archive ran without the user's confirmation and archived the active
  integration thread, which then could not receive follow-ups. Archive only on
  explicit confirmation, active threads last.
- No rollback procedure existed, so stop criteria were improvised. Write the
  rollback before the release.
