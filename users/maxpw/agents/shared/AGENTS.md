# Global Agents Config

## Obsidian Vault

The Obsidian CLI (`obsidian`) is available on the system. Use it when interacting with notes.

The vault is located at `~/Documents/obsidian vault/`.

### Feature Planning

Create a feature note only for larger features or when explicitly asked. A feature is "larger" when it spans multiple files or sessions, needs scope tradeoffs, or creates decisions worth preserving beyond the current chat. Use the Feature template (`999-TEMPLATES/Feature.md`) and fill in the sections (Why, MVP, Not doing, Approach) before writing code. Do not create Obsidian notes for small code changes, routine edits, or exploratory discussion.

### Bug Reports

Create a problem note only for substantial bugs, ongoing investigations, or when explicitly asked. A bug is "substantial" when the root cause is unclear, reproduction is involved, impact is high, or the investigation is likely to span more than one session. Use the Problem template (`999-TEMPLATES/Problem.md`) and fill in the sections (What's happening, What I expected, What I've tried, What I think is going on). Update the Solution section after resolving it. Do not create Obsidian notes for quick fixes or simple diagnostics.

### Wiki Integration

The vault contains a persistent LLM-maintained wiki at `200-WIKI/`. See `200-WIKI/CLAUDE.md` for full schema.

**When working on project code:**

- Before diving into domain-specific work that clearly maps to an existing topic, read the relevant topic index at `200-WIKI/topics/<topic>/index.md` for context. Key mappings:
  - VEV / vev-server / vev-ocpi → `ev-charging/` (also linked from `333-VEV/`)
  - LibreStock / Effect migration → `effect-ts/`
  - Architecture decisions → `software-architecture/`
  - Dev tooling (jj, etc.) → `dev-tools/`
- When a conversation produces a useful synthesis, exploration, or resolved question that would benefit future work, offer to file it back as a wiki article. Do not update the wiki silently.

**When to update the wiki:**

- After resolving a non-trivial technical question related to an existing topic
- After an audit or investigation that surfaces new domain knowledge
- After ingesting a new source (spec, article, book) — compile it into wiki articles
- Do not update the wiki for ephemeral or project-specific details (use project notes in `100-PROJECTS/` or `333-VEV/` instead)

**Project ↔ Wiki boundary:**

- `333-VEV/`, `100-PROJECTS/` = actionable work (audits, features, bugs, specs)
- `200-WIKI/` = compiled domain knowledge (protocols, patterns, concepts)
- Project index files link to relevant wiki topics via "Wiki Context" sections
- Don't duplicate — project notes reference wiki articles for domain context, wiki articles reference VEV for real-world examples

## Version Control: prefer jj over git

When a repo has a `.jj/` directory (run `jj root` to check), use `jj` instead of `git` for VCS operations. Most of my repos are jj-colocated with git — assume jj unless `jj root` fails.

Background and deeper workflows: `200-WIKI/topics/dev-tools/` has my jj notes.

**Command mapping** (use the jj form):

- `git status` → `jj st`
- `git diff` → `jj diff` (working copy) / `jj diff -r <rev>` (specific revision)
- `git log` → `jj log` (default shows the relevant slice, not full history)
- `git add` → _no equivalent needed_ — jj auto-tracks all changes in the working copy
- `git commit -m "msg"` → `jj commit -m "msg"` (finalize) or `jj describe -m "msg"` (set message on current change without starting a new one)
- `git checkout -b foo` → `jj new -m "foo"` then `jj bookmark create foo -r @-` if a named branch is needed
- `git push` → `jj git push` (pushes bookmarks)
- `git pull` → `jj git fetch` then `jj rebase` as needed
- `git stash` → not needed; just `jj new` to start fresh, the WIP becomes its own change

**Gotchas for a git-trained agent:**

- No staging area. Don't try to `jj add` files. The working copy _is_ a commit (`@`).
- Don't `git commit --amend` — use `jj squash` or just edit `@` and re-`jj describe`.
- Branches in jj are called **bookmarks** and don't auto-follow new commits — push them explicitly with `jj git push`.
- `jj undo` reverses the last operation; safer than git resets.
- When a conflict appears, jj records it in the commit rather than blocking — resolve in the working copy, then continue.

**When git is still the right tool:**

- Repo has no `.jj/` directory.
- Operating on remote-only refs the user explicitly named in git terms.
- Reading `git log`/`git blame` for forensics where jj's view would obscure history (rare).

## Planning First

Do not jump straight into implementation for substantial or ambiguous work:

1. **Understand the problem** — read the relevant code, ask clarifying questions, and make sure you know what's actually going on before proposing changes.
2. **Draft a lightweight plan** — outline the approach, files involved, and key decisions when the task is non-trivial. A plan can be only two or three bullets when the path is clear.
3. **Stress-test only when warranted** — use the grill-me skill or equivalent workflow only for complex, high-risk, product/design-heavy, or explicitly requested planning. Do not invoke it for routine code edits, small refactors, simple bug fixes, or tasks where the path is obvious.
4. **Then implement** — after the plan is clear enough for the task size.

For larger features, create a Feature note in the Obsidian vault only when it will help preserve scope or decisions.

A "trivial" change is a one-liner, a typo fix, a small config/content edit, or something the user explicitly tells you to just do. Trivial changes can be implemented directly. Do not wait for explicit approval after presenting a plan unless the user asked for planning only, the change is risky, or the next step is genuinely ambiguous.

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
