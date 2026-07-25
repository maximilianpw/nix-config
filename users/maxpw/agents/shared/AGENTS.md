# Global Agents Config

## Personal Preferences

- Avoid `any` in TypeScript unless necessary or explicitly requested.
- Do not start dev servers or run build unless asked; prefer the smallest relevant checks like typecheck or lint.
- Follow the project's existing package manager and lockfile; otherwise use pnpm.
- When choosing a frontend stack, prefer Tailwind, TypeScript, Bun, React, Clerk, Cloudflare, and Tanstack.
- When choosing a backend stack, prefer Effect and Drizzle

## Model Preferences

Use these rankings only when choosing models for workflows or subagents. Higher is better; cost reflects my actual cost, not list price.

| model | cost | intelligence | taste |
| --- | --- | --- | --- |
| gpt-5.6 sol | 9 | 8 | 5 |
| sonnet-5 | 5 | 5 | 7 |
| opus-5 | 4 | 7 | 8 |

- Cost is only a tie-breaker. For work that ships, prefer intelligence > taste > cost.
- If a cheaper model's output does not meet the bar, rerun or redo the work with a smarter model without asking.
- Bulk/mechanical work (clear-spec implementation, data analysis, migrations): gpt-5.6 sol.
- Anything user-facing (UI, copy, API design) needs taste >= 7.
- Reviews of plans and implementations: fable-5 or opus-5, optionally gpt-5.6 as an extra independent perspective.
- Never use Haiku.

## Planning First

For substantial or ambiguous work, read the relevant code and draft a lightweight plan before implementing. A plan can be only two or three bullets when the path is clear.

Use the grill-me skill or equivalent workflow only for complex, high-risk, product/design-heavy, or explicitly requested planning. Do not invoke it for routine code edits, small refactors, simple bug fixes, or tasks where the path is obvious.

Trivial changes can be implemented directly: one-liners, typo fixes, small config/content edits, or requests the user explicitly says to just do. Do not wait for explicit approval after presenting a plan unless the user asked for planning only, the change is risky, or the next step is genuinely ambiguous.

## Verification

Before saying work is complete, run the smallest relevant verification command available. Prefer fast local checks first. If verification cannot be run, say exactly what was skipped and why.
