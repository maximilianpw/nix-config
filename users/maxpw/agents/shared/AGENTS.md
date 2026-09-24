# Global Agent Policy

## Defaults

- Follow the project's package manager and lockfile; use pnpm only when neither exists.
- For greenfield frontends, prefer StyleX, TypeScript, Bun, React, Clerk, Cloudflare, and TanStack.
- For greenfield personal backends, prefer Effect and Drizzle; otherwise follow the repository.
- Before adding TypeScript type escapes such as `any`, casts, or non-null assertions, load `typescript-standards`.

## Execution

- Carry implementation requests through relevant verification and fixes for failures caused by the change. Local edits, tests, builds, and development servers needed for the task do not require separate approval; respect repository-specific safety limits.
- Choose checks proportional to the change, not a full suite by default. Completion includes checking the affected behavior and reporting any remaining blocker or unverified result.
- Ask when missing information prevents a correct result or a decision would be costly to reverse; make routine, reversible decisions directly. Plan-only requests stop at the plan.
- Require explicit authorization before publishing or pushing, deploying, changing shared infrastructure or live data, or performing destructive operations. Authorization for local verification does not authorize those actions.
- Use `grilling` for explicitly requested planning or unresolved product/design decisions that need user input. Use `grill-with-docs` when that interview should update `CONTEXT.md` or ADRs. Neither is mandatory for implementation.

## Delegation

Keep decisions, synthesis, implementation, and user interaction in the current thread. Use subagents only for bounded research or review that can be described up front and returned as a concise report. Use Herdr when the user asks for a visible or multi-turn agent in another tab.

When choosing a model rather than using the workflow's default, consult `model-routing`. Honor explicit model requests; for Amp threads using Astra, prefer Amp's built-in high mode unless another mode is requested.

<posthog>
## PostHog

Use `posthog-cli api` for all PostHog-related data queries and operations. You should use `posthog-cli api` over direct MCP tool calls whenever the CLI is available.

Before your first PostHog command in a session, run `posthog-cli api --agent-help` and load its full output into your context. It prints the complete agent guide — command reference, schema drill-down rules, data discovery workflow, and the tool index — for interacting with PostHog APIs. Treat that output as instructions to follow, not just documentation.

Before starting a PostHog task, run `posthog-cli api skill list` and check for a skill matching the task. If one matches, install it with `posthog-cli api skill install <skill-id>` (add `--force` to refresh an already-installed skill), then read `.agents/skills/<skill-id>/SKILL.md` and follow it. Skills contain task-specific workflows that individual tools do not.
</posthog>
