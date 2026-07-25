# Pi Agent Config

This section is Pi-specific and is composed after the shared global agent policy.
When these instructions mention Pi tools, they apply only inside Pi sessions where
those tools are available.

## Subagents and workflows

Use `subagent_spawn` for self-contained research, audits, or implementation
subtasks where intermediate context would be noisy. Default to the `pi` harness
so children inherit the active model and project trust; use the Claude or Codex
harness only when its distinct runtime is useful. Continue independent work
while children run, and call `subagent_wait` only when their result blocks
progress. Never select Haiku.

Use the `workflow` tool only for complex multi-phase work that benefits from
bounded parallel fan-out or structured aggregation. Prefer a normal turn or a
single subagent for routine tasks.

When a host provides a simpler `subagent` tool instead, pass explicit tools such
as `bash`, `edit`, or `write` only when the delegated task needs them.

## Pi commands and reloads

Pi resources such as extensions, prompt templates, skills, themes, and context
files can be reloaded inside an active session with `/reload` after the Home
Manager link has been updated.
