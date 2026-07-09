# Global Agents Config

## Personal Preferences

- Avoid `any` in TypeScript unless it is necessary or explicitly requested.
- Do not start dev servers or run build commands unless asked. Prefer fast checks such as `bun run typecheck` and `bun run lint`.
- Use pnpm if the project already uses it; otherwise use bun. Never use npm or yarn.
- When choosing a frontend stack, prefer Tailwind, TypeScript, Bun, React, Convex, Clerk, and Vercel.

## Model Preferences

Use these rankings only when choosing models for workflows or subagents. Higher is better; cost reflects my actual cost, not list price.

| model | cost | intelligence | taste |
| --- | --- | --- | --- |
| gpt-5.5 | 9 | 8 | 5 |
| sonnet-5 | 5 | 5 | 7 |
| opus-4.8 | 4 | 7 | 8 |
| fable-5 | 2 | 9 | 9 |

- Cost is only a tie-breaker. For work that ships, prefer intelligence > taste > cost.
- If a cheaper model's output does not meet the bar, rerun or redo the work with a smarter model without asking.
- Bulk/mechanical work (clear-spec implementation, data analysis, migrations): gpt-5.5.
- Anything user-facing (UI, copy, API design) needs taste >= 7.
- Reviews of plans and implementations: fable-5 or opus-4.8, optionally gpt-5.5 as an extra independent perspective.
- Never use Haiku.

## Version Control: prefer jj over git

When a repo has a `.jj/` directory (run `jj root` to check), use `jj` instead of `git` for VCS operations. Most of my repos are jj-colocated with git — assume jj unless `jj root` fails.

## Planning First

For substantial or ambiguous work, read the relevant code and draft a lightweight plan before implementing. A plan can be only two or three bullets when the path is clear.

Use the grill-me skill or equivalent workflow only for complex, high-risk, product/design-heavy, or explicitly requested planning. Do not invoke it for routine code edits, small refactors, simple bug fixes, or tasks where the path is obvious.

Trivial changes can be implemented directly: one-liners, typo fixes, small config/content edits, or requests the user explicitly says to just do. Do not wait for explicit approval after presenting a plan unless the user asked for planning only, the change is risky, or the next step is genuinely ambiguous.

## Verification

Before saying work is complete, run the smallest relevant verification command available. Prefer fast local checks first. If verification cannot be run, say exactly what was skipped and why.

## Shells

Use POSIX-compatible shell syntax for normal agent tool calls and commands that need to run reliably in project scripts, CI, Makefiles, package scripts, or other standard shell contexts. Use Bash-specific syntax only when the target context is Bash.

Nushell is the primary interactive shell for the user. Prefer Nushell only when generating commands, scripts, or one-liners intended for the user to run interactively, especially when structured-data pipelines are clearer than POSIX text-munging. If using Nushell from a Bash-oriented tool call, invoke it explicitly with `nu -c '...'`.

**Nushell substitutions for user-facing commands:**

- `grep` → `where`, `find`, or `str contains`
- `awk` / `cut` → `get`, `select`, `columns`
- `sed` → `str replace`
- `wc -l` → `length`
- `sort | uniq -c` → `group-by | transpose`
- `xargs` → `each { |it| ... }`
- `jq` → native `from json` + `get` / `where`
- `head` / `tail` → `first N` / `last N`
- `find . -name` → `ls **/*pattern*` or `glob`

**When Bash/POSIX is still right:**

- Agent tool calls where Bash/POSIX is the expected execution environment.
- Target is a Bash/POSIX script, CI step, Makefile, README example, or package script.
- Tool shells out via `system()` or similar and won't pick up Nushell.
- Piping to a tool that expects raw text on stdin in a way Nushell would mangle.

## Remote Dev Fleet

Use `fleet list` to see trusted development machines declared by Nix, and read
`~/.config/fleet/FLEET.md` for host capabilities and placement decisions.
Prefer `fleet ssh <host>` for interactive tmux work, `fleet shell <host>` for a
plain SSH shell, and `fleet run <host> <command...>` for non-interactive checks.
Direct tmux SSH aliases also exist as `tm-<host-or-alias>`, for example
`ssh tm-main-pc`.

Use `fleet forward <host> <local-port> <remote-port> [remote-host]` for port
forwards.

Fleet inventory is generated from `modules/fleet/home-manager.nix`; do not edit
generated `~/.config/fleet/hosts.json`, `~/.config/fleet/FLEET.md`, or SSH
config directly. Read `modules/fleet/README.md` before adding a host or
changing the workflow.

Treat fleet machines as trusted internal hosts. SSH agent forwarding is enabled
for interactive work so Git and agent tools can use your local SSH credentials.
Scheduled or unattended agent runs must not rely on forwarded SSH credentials;
interactive sessions only.

## Shared Prompts

Reusable prompts live in `~/.agents/prompts`. Agent-specific prompt or command
surfaces may symlink those same files into their native locations; prefer editing
the shared source under `users/maxpw/agents/shared/prompts` instead of copying
prompt text per agent.
