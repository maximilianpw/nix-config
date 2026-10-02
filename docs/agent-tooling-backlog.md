# Agent tooling backlog

This file tracks unresolved agent-workflow work. It is not an implementation
prompt.

## Implemented foundations

- **Fleet contract:** Implemented. The runtime and operational contract are in
  [the Fleet module](../modules/fleet/README.md), the shared policy is in
  `users/maxpw/agents/shared/AGENTS.md`, and Home Manager generates
  `~/.config/fleet/FLEET.md` from the host inventory.
- **Bounded execution loop:** Implemented by the repository `AGENTS.md` policy.
  It requires scoped work, proportional verification, and explicit approval
  before deployment or destructive operations. Do not add another prompt file
  that duplicates this policy.

## Scheduled read-only reports

### Implemented: morning report on Kim

`users/maxpw/modules/morning-report.nix` runs `scripts/morning-report.sh` as
the `morning-report` user service and timer (07:00 local, up to five minutes
of randomized delay, `Persistent=true`). It is enabled only on inventory hosts
with `longRunningAgents = true` and the `homelab` profile, which today means
Kim. The run is deterministic shell with no agent or LLM step. It writes
`~/reports/morning/YYYY-MM-DD.md` atomically and covers:

- failed system and user units, plus homelab important units from
  `lib/homelab.nix` that are not active;
- agent services: `t3code.service` (user), `cliproxyapi.service`,
  `cliproxyapi-quota.service`, `cliproxyapi-readiness-probe.timer`, and the
  latest `cliproxyapi_backend_ready` sample when the readiness textfile exists;
- quota availability from `cliproxyapi-util quota --json` (family, status,
  used percent; never tokens);
- open pull requests in `maximilianpw/nix-config` from `gh` when it is
  installed and authenticated;
- repository state of `~/nix-config`: uncommitted change count, checked-out
  branch, and the latest commit on `main`.

Every section prints an explicit `unknown` marker instead of omitting a source
that did not answer, and the script exits non-zero only when the report itself
cannot be written. Subprocesses run from an empty scratch directory and the
script never reads dotenv files; `scripts/tests/morning-report-test.sh` covers
the healthy, all-sources-failing, atomic-write, and dotenv cases, and
`tests/morning-report-regression.nix` asserts the Kim-only gating. Run
`systemctl --user start morning-report.service` on Kim for an on-demand report
and `journalctl --user -u morning-report` for its log.

### Remaining

- Further report types: prompt-debt findings, Fleet inventory and reachability
  drift, and available agent-tooling updates.
- An optional agent summarization step that reads the Markdown report and
  writes a short digest next to it; it must stay read-only and must follow the
  credential isolation decisions below.
- Delivery beyond the local directory, for example an Obsidian location.

## Deferred work

### Prompt-debt validation

A future check may report missing commands or files, warnings against editing
generated files, Fleet aliases absent from inventory, oversized policy files,
and rules duplicated between repository and global instructions. It should
start as a read-only report before becoming a lint gate.

Resolved example: the shared policy in `users/maxpw/agents/shared/AGENTS.md`
named `grilling` and `grill-with-docs` while only `grill-me` was installed. Home
Manager distributes that policy to several agents, so the stale reference
repeated across tools. It now names `grill-me` and `domain-modeling`. This is
the first case the validator should have caught.

### Unattended credential isolation

Decided in [ADR 0001](adr/0001-unattended-agent-access.md): unattended agents
on Kim run as the personal user `maxpw` with the same access as an interactive
session, must not read `.env` or `.env.*` files, and treat the `AGENTS.md`
authorization boundaries as absolute. No separate user or container is
introduced. The ADR lists the credential-bearing paths that remain readable so
the owner can confirm or tighten the scope later.

Considered and deferred: a separate account or container with scoped proxy
access and no default access to personal credentials, Docker control, or live
service data. Revisit if the owner tightens the ADR's confirmation list or if
an unattended workload needs access the personal user should not hold.

### CLIProxyAPI upstream protocol revalidation

The maintained [CLIProxyAPI module documentation](../modules/cliproxyapi/README.md)
records dated Zen protocol constraints. Before enabling anything beyond the
current prefix-isolated Chat Completions upstream, revalidate Responses
streaming/reasoning behavior, Anthropic Messages authentication without
secret-duplicating header workarounds, and whether current Gemini URL
construction can address Zen. Use runtime SOPS credentials and do not turn a
historical unauthenticated probe into a current compatibility claim.

## Open decisions

- Decided 2026-10-02: the first unattended host is Kim as the personal user
  `maxpw`, reports land in a local directory under the user's home, and the
  deterministic report lives in this repository. Credential scope and the
  always-human-approved operations are recorded in
  [ADR 0001](adr/0001-unattended-agent-access.md).
- Whether to add an Obsidian destination alongside the local directory.
