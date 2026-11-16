@~/.config/agent-policy/AGENTS.md

# Claude Code-specific instructions

Comments default to none. A comment earns its place only when a competent reader, without it, would misread the code or "fix" it into a bug: a workaround, an external quirk, a security invariant, a reason the code cannot show. Before finishing any edit, reread every comment you added and delete each one that a name, a type, an error message or the adjacent line already says. Docstrings on interfaces and helpers fail this test by default.
