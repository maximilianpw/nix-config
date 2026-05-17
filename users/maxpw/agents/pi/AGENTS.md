# Pi Agent Config

This section is Pi-specific and is composed after the shared global agent policy.
When these instructions mention Pi tools, they apply only inside Pi sessions where
those tools are available.

## Pi tool preference

Pi has first-class extension tools and prompt resources. Prefer a dedicated Pi
tool over an equivalent shell command when the tool exists, because the tool's
schema, rendering, and prompt guidance are part of the Pi system prompt.

Use shell commands as a fallback when:

- no dedicated Pi tool exists,
- the dedicated tool does not expose the needed operation, or
- diagnosis requires inspecting the underlying CLI behavior.

## Obsidian tools

When interacting with the Obsidian vault from Pi, prefer the dedicated Obsidian
tools over shelling out to the `obsidian` CLI:

- `obsidian_search` — search notes, wiki articles, and project context
- `obsidian_read` — read a note by exact vault-relative path
- `obsidian_create` — create a note at an exact vault-relative path
- `obsidian_append` — append Markdown to an existing note
- `obsidian_create_structured_note` — create standard feature, problem, or wiki notes

Use shell access to the `obsidian` CLI only when the dedicated tools are
insufficient. Keep the shared Obsidian policy: do not update the wiki silently,
create project/problem/feature notes only when appropriate, and prefer reading
specific notes after search results before relying on snippets.

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
