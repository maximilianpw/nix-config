# Global Agent Policy

## Defaults

- Follow the project's package manager and lockfile; use pnpm only when neither exists.
- For greenfield frontends, prefer StyleX, TypeScript, Bun, React, Clerk, Cloudflare, and TanStack.
- For greenfield personal backends, prefer Effect and Drizzle; otherwise follow the repository.
- Load `coding-standards` for non-trivial implementation, refactoring, or code review, and before adding type escapes or moving code. Read only its references matching the changed behavior and stack.

## Engineering judgment

- Before adding logic, identify the data model, valid states, and transitions. Prefer making invalid states unrepresentable over adding scattered guards.
- Look for redundant state, obsolete behavior, and unnecessary layers before adding code. Keep cleanup within the requested change.
- When two fixes relying on the same assumption fail, state and test that assumption before trying another.
- Keep related decisions together and mutable state narrowly scoped. Abstractions must hide meaningful complexity, not just relocate code.
- Make repeated edits and measurements reproducible with a small script or check when that is simpler and safer than doing them manually.

## Execution

- Carry implementation requests through relevant verification and fixes for failures caused by the change. Local edits, tests, builds, and development servers needed for the task do not require separate approval; respect repository-specific safety limits.
- Run proportionate existing checks while working and every gate the repository requires before completion. Exercise changed UI, API, or CLI behavior through its real surface as well as tests. Add verification tooling only when needed; report failures with output and unverified behavior with its blocker or reason.
- Ask when missing information prevents a correct result or a decision would be costly to reverse; make routine, reversible decisions directly. Plan-only requests stop at the plan.
- Require explicit authorization before publishing or pushing, deploying, changing shared infrastructure or live data, or performing destructive operations. Authorization for local verification does not authorize those actions.
- Use `grill-me` for explicitly requested planning interviews or unresolved product/design decisions that need user input. Load `domain-modeling` when that interview should update `CONTEXT.md` or record an ADR. Neither is mandatory for implementation.

## Unattended execution

When running unattended (no human in the loop), do not read `.env` or `.env.*` files. Operations that require explicit authorization above are available only when the task definition granted them in advance; with nobody to ask, anything not pre-authorized is out of scope for that run rather than deferred.

## Delegation

Keep decisions, synthesis, implementation, and user interaction in the current thread. Use subagents only for bounded research or review that can be described up front and returned as a concise report. Separate working agents or conversations require a user request.

Route requested orchestration by session host, independently of the agent harness (Pi, Claude, Codex, or Amp):

- Honor an explicitly requested backend, subject to its availability and safety checks.
- Otherwise, in a verified T3 session, use T3 orchestration. Launch requested separate conversations through T3 with explicit workspace binding; keep child tasks distinct from top-level threads.
- Otherwise, when `HERDR_ENV=1`, use Herdr for requested agent, pane, tab, and workspace orchestration. The user need not name Herdr; load the `herdr` skill before acting.
- Otherwise, use available native agent tools within their supported scope.

Verify T3 through its orchestration tools; environment markers are hints, not proof, and credential values must stay private. A verified T3 session takes precedence over inherited Herdr markers. Environment detection selects the backend, not permission to spawn agents, change workspaces, or perform otherwise restricted actions.

When choosing a model rather than using the workflow's default, consult `model-routing`. Honor explicit model requests; for Amp threads using Astra, prefer Amp's built-in high mode unless another mode is requested.

<posthog>
## PostHog

Use `posthog-cli api` for all PostHog-related data queries and operations. You should use `posthog-cli api` over direct MCP tool calls whenever the CLI is available.

Before your first PostHog command in a session, run `posthog-cli api --agent-help` and load its full output into your context. It prints the complete agent guide — command reference, schema drill-down rules, data discovery workflow, and the tool index — for interacting with PostHog APIs. Treat that output as instructions to follow, not just documentation.

Before starting a PostHog task, run `posthog-cli api skill list` and check for a skill matching the task. If one matches, install it with `posthog-cli api skill install <skill-id>` (add `--force` to refresh an already-installed skill), then read `.agents/skills/<skill-id>/SKILL.md` and follow it. Skills contain task-specific workflows that individual tools do not.
</posthog>
