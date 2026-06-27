# Pi Agent Config

This section is Pi-specific and is composed after the shared global agent policy.
When these instructions mention Pi tools, they apply only inside Pi sessions where
those tools are available.

## Subagents

Use the `subagent` tool for self-contained research, audits, or implementation
subtasks where only the final result is needed and intermediate context would be
noisy.

Subagents default to read-only tools. Pass explicit tools such as `bash`, `edit`,
or `write` only when the delegated task needs them.

## Pi commands and reloads

Pi resources such as extensions, prompt templates, skills, themes, and context
files can be reloaded inside an active session with `/reload` after the Home
Manager link has been updated.
