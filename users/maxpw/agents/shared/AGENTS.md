# Global Agents Config

## Version Control: prefer jj over git

When a repo has a `.jj/` directory (run `jj root` to check), use `jj` instead of `git` for VCS operations. Most of my repos are jj-colocated with git — assume jj unless `jj root` fails.

## Planning First

Do not jump straight into implementation for substantial or ambiguous work:

1. **Understand the problem** — read the relevant code, ask clarifying questions, and make sure you know what's actually going on before proposing changes.
2. **Draft a lightweight plan** — outline the approach, files involved, and key decisions when the task is non-trivial. A plan can be only two or three bullets when the path is clear.
3. **Stress-test only when warranted** — use the grill-me skill or equivalent workflow only for complex, high-risk, product/design-heavy, or explicitly requested planning. Do not invoke it for routine code edits, small refactors, simple bug fixes, or tasks where the path is obvious.
4. **Then implement** — after the plan is clear enough for the task size.

A "trivial" change is a one-liner, a typo fix, a small config/content edit, or something the user explicitly tells you to just do. Trivial changes can be implemented directly. Do not wait for explicit approval after presenting a plan unless the user asked for planning only, the change is risky, or the next step is genuinely ambiguous.

## Verification

Before saying work is complete, run the smallest relevant verification command
available. Prefer fast local checks first. If verification cannot be run, say
exactly what was skipped and why.

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
forwards and `fleet t3 <host> [local-port]` for remote T3 Code access.

Fleet inventory is generated from `modules/fleet/home-manager.nix`; do not edit
generated `~/.config/fleet/hosts.json`, `~/.config/fleet/FLEET.md`, or SSH
config directly. Read `modules/fleet/README.md` before adding a host or
changing the workflow.

Treat fleet machines as trusted internal hosts. SSH agent forwarding is enabled
for interactive work so Git and agent tools can use the 1Password SSH agent.
Scheduled or unattended agent runs must not use the forwarded 1Password SSH
agent; interactive sessions only.
