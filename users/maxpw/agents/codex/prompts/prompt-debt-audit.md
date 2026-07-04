# Prompt Debt Audit

Audit the local agent instructions and installed agent surfaces for drift. This
is a read-only audit: do not edit repo files, generated config, prompts, skills,
commands, commits, or rebuilds. The only allowed write is the report file
described below.

Work from `~/nix-config` and inspect:

1. Source prompts and policies.
   - `users/maxpw/agents/**`
   - `CLAUDE.md`
   - `AGENTS.md` files if present
   - `modules/fleet/README.md`
2. Installed agent surfaces.
   - `~/.claude`
   - `~/.codex`
   - `~/.config/opencode`
   - `~/.pi/agent`
   - `~/.agents/skills`
3. Fleet inventory.
   - Read `~/.config/fleet/hosts.json` if present.
   - Read `~/.config/fleet/FLEET.md` if present.

Flag:

- Missing source files, installed files, command files, prompt files, skill
  paths, or symlink targets.
- Hostnames, aliases, or placement guidance that do not match
  `~/.config/fleet/hosts.json`.
- Duplicated or conflicting rules across Codex, Claude, opencode, Pi, and
  shared instructions.
- Instructions telling agents to edit generated files such as
  `~/.config/fleet/hosts.json`, `~/.config/fleet/FLEET.md`, or SSH config.
- Sections longer than about 80 lines, especially if they mix unrelated policy.
- Stale references to tools, commands, plans, files, or machines that no longer
  exist.

Write the full report to:

`~/.local/share/agent-reports/$(date +%Y-%m-%d)-prompt-debt-audit.md`

The report should contain:

- Timestamp and hostname.
- Commands and files inspected.
- Findings grouped by severity: action needed, watch, clean.
- Concrete, scoped recommendations for reducing prompt debt.

After writing the report, print a summary of 10 lines or fewer with the report
path and the highest-severity findings.
