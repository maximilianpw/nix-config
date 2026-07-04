# Nix Config Health Report

Run a read-only health check for `~/nix-config`. Do not edit repo files, commit,
rebuild, update inputs, install packages, or apply fixes. The only allowed write
is the report file described below.

Work from `~/nix-config` and collect:

1. Version-control state.
   - If `jj root` succeeds, report `jj status`.
   - Otherwise report `git status --short`.
   - Include untracked files and deleted files.
2. Plan index health.
   - Read `plans/README.md`.
   - Flag rows that look stale, blocked without a reason, or still TODO even
     though the matching plan file appears missing or completed.
3. Broken symlinks.
   - Check `~/.claude`, `~/.codex`, and `~/.config/fleet`.
   - Report broken links and their targets.
4. Last rebuild signal.
   - If `~/nixos-switch.log` exists, summarize its latest result.
   - If an `nh` log exists under common user log/cache/state directories,
     summarize the most recent relevant failure or success.
   - If no rebuild log is present, say so.

Write the full report to:

`~/.local/share/agent-reports/$(date +%Y-%m-%d)-nix-config-health.md`

The report should contain:

- Timestamp and hostname.
- Commands run.
- Findings grouped by severity: action needed, watch, clean.
- A short "suggested next steps" section that names fixes but does not perform
  them.

After writing the report, print a summary of 10 lines or fewer with the report
path and the highest-severity findings.
