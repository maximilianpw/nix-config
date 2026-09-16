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

### Prompt-debt validation

A future check may report missing commands or files, warnings against editing
generated files, Fleet aliases absent from inventory, oversized policy files,
and rules duplicated between repository and global instructions. It should
start as a read-only report before becoming a lint gate.

### Unattended credential isolation

Fleet SSH blocks disable agent forwarding by default. Unattended work still
needs a separate threat model, low-privilege and short-lived credentials, and
human approval for destructive operations. Define the credential and operation
allowlist before scheduling any agent work.

## Open decisions

- Report destination: a local report directory, an Obsidian location, or both.
- Ownership: this repository or the external `pi-config` repository.
- First unattended host, if unattended work is enabled at all.
- Credential scope and the operations that must always remain human-approved.
