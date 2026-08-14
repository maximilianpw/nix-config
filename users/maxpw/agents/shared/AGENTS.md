# Global Agent Policy

## Defaults

- Follow the project's package manager and lockfile; use pnpm only when neither exists.
- For greenfield frontends, prefer Tailwind, TypeScript, Bun, React, Clerk, Cloudflare, and TanStack.
- For greenfield personal backends, prefer Effect and Drizzle; otherwise follow the repository.
- Before adding TypeScript type escapes such as `any`, casts, or non-null assertions, load `typescript-standards`.
- Prefer the smallest relevant check. Start development servers or full builds only when the user asks.

## Execution

- For substantial or ambiguous work, inspect the relevant code and state a lightweight plan before implementation.
- Use `grill-me` only for complex, high-risk, product/design-heavy, or explicitly requested planning.
- Implement routine and trivial changes directly. Wait for approval only for plan-only requests, risky changes, or genuine ambiguity.
- Prefer the simplest complete design; simplify the primary mechanism before adding special cases.
- Before claiming completion, run the smallest relevant verification and report anything skipped with the reason.

## Integrations

Use Executor as the only gateway for remote MCP servers and remote API integrations. Keep device-local capabilities local when moving them would change their security or runtime boundary. For adding, migrating, authenticating, or auditing an integration, follow `~/nix-config/docs/executor-mcp-gateway.md`.

## Delegation

Before choosing a model for any workflow or subagent, load the `model-routing` skill.
