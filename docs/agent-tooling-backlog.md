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
default. Open decisions are the report destination, whether the implementation
belongs in the external `pi-config` repository, and the first unattended host,
if any.

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

Fleet SSH blocks disable agent forwarding by default. Unattended work still
needs a separate threat model, low-privilege and short-lived credentials, and
human approval for destructive operations. Define the credential and operation
allowlist before scheduling any agent work.

T3 and the proxy run under the personal user, which Kim also grants Docker
access. Define which repositories, files, credentials, network services, and
operations an unattended task needs, starting with read-only reporting. For
editing tasks, evaluate a separate account or container with deliberate proxy
access and no default access to personal credentials, privileged Docker control,
or live service data. Acceptance is that representative allowed tasks work and
excluded accesses fail; pick the isolation mechanism after that.

### CLIProxyAPI upstream protocol revalidation

The maintained [CLIProxyAPI module documentation](../modules/cliproxyapi/README.md)
records dated Zen protocol constraints. Before enabling anything beyond the
current prefix-isolated Chat Completions upstream, revalidate Responses
streaming/reasoning behavior, Anthropic Messages authentication without
secret-duplicating header workarounds, and whether current Gemini URL
construction can address Zen. Use runtime SOPS credentials and do not turn a
historical unauthenticated probe into a current compatibility claim.

## Open decisions

- Report destination: a local report directory, an Obsidian location, or both.
- Ownership: this repository or the external `pi-config` repository.
- First unattended host, if unattended work is enabled at all.
- Credential scope and the operations that must always remain human-approved.
