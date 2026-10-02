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

## Deferred work

### Scheduled read-only reports

Decide whether to add isolated, report-only jobs for:

- repository health and failed verification notes;
- prompt-debt findings;
- Fleet inventory and reachability drift;
- available agent-tooling updates.

These jobs must write reports only. They must not edit this repository by
default. The first unattended host is Kim, running as `maxpw` under
[ADR 0001](adr/0001-unattended-agent-access.md); the morning report (PRS-361)
is the first such job. Report destination and ownership are being settled in
PRS-361.

A reasonable first trial is one morning report on Kim covering failed checks,
unavailable agent services, quota availability, and work awaiting a decision.
Deterministic scripts gather the facts; an agent is used only where explanation
or prioritization adds value. The report is timestamped, distinguishes failures
from unknown results, contains no secret values, and makes no repository or
service changes. Nix owns the service lifecycle and package wiring; prompts and
extensions stay in `pi-config`. Start only after the credential scope below is
defined.

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

- Report destination and ownership (this repository or the external
  `pi-config` repository): being decided in PRS-361.

Decided: the first unattended host is Kim as the personal user `maxpw`, and the
credential scope and always-human-approved operations are recorded in
[ADR 0001](adr/0001-unattended-agent-access.md).
