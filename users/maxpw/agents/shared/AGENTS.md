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
- Use `grill-me` for explicitly requested planning or unresolved product/design decisions that need user input, not as a mandatory step for implementation.

## Delegation

When choosing a model rather than using the workflow's default, consult `model-routing`. Honor explicit model requests; for Amp threads using Astra, prefer Amp's built-in high mode unless another mode is requested.
