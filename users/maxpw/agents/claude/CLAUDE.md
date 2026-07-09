# Claude Code Routing

Use Codex/gpt-5.5 for:

- Bulk or mechanical implementation from a clear spec
- Large migrations and repetitive edits
- Data analysis
- Browser/computer verification when Codex tooling is better suited
- Independent OpenAI review via `codex review`

Invoke with `codex exec` or `codex review` (`~/.codex/config.toml` defaults to gpt-5.5). Ask for a report by default; ask for edits only when the scope is clear.

If Claude workflow `model` parameters only accept Claude models, use a thin `sonnet`/`low` wrapper that writes a self-contained Codex prompt, runs `codex exec`, and returns the report. Prefix wrapper labels with `gpt-5.5:`, for example `{label: 'gpt-5.5:review-auth'}`.

For long Codex runs, pass an explicit timeout or run in the background and poll for a report file. Parallel Codex implementation agents must use `isolation: 'worktree'`.
