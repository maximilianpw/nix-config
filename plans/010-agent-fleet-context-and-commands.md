# Plan 010: Agent fleet contract + read-only report commands (codex-first)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 3b81497..HEAD -- modules/fleet/home-manager.nix modules/fleet/README.md users/maxpw/modules/agent-tools.nix users/maxpw/agents CLAUDE.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW (additive config + new prompt files; nothing removed)
- **Depends on**: none (but see working-tree hazard below)
- **Category**: agent tooling
- **Planned at**: commit `3b81497`, 2026-07-03
- **Source**: `docs/agent-fleet-and-loops-handoff.md` (recommendations 1–4,
  filtered — see "Deliberately out of scope" for what was cut and why)

## Why this matters

Agents working across the fleet currently learn host capabilities from a
hand-written prose section in `users/maxpw/agents/shared/AGENTS.md`, which can
drift from the real inventory in `modules/fleet/home-manager.nix`. Generating
an agent-facing fleet document from the same `fleetHosts` attrset that drives
the `fleet` CLI makes drift impossible by construction. Alongside that, two
read-only report commands (`nix-config-health`, `prompt-debt-audit`) give
recurring maintenance work a safe, bounded shape *before* any scheduling or
automation is added. The user runs Codex as the primary agent, so commands are
canonical as Codex prompts and mirrored into Claude.

## Working-tree hazard

At planning time the working tree had uncommitted modifications to
`users/maxpw/agents/shared/AGENTS.md`, `CLAUDE.md`, `homelab/*`, and an
untracked `homelab/tailscale-serve.nix`. **Commit or stash-review that work
before starting.** This plan edits `AGENTS.md` and `CLAUDE.md`; do not clobber
in-flight changes. A worktree-isolated executor created from HEAD will not see
them — run this plan in the main working tree, or commit the WIP first.

## Current state

- `modules/fleet/home-manager.nix` (288 lines):
  - `fleetHosts` attrset starts at line 10. Two hosts today:
    - `main-pc`: `role = "nixos-desktop"`, `t3codePort = 51000`, aliases
      `main`/`desktop`, tmux via `/run/current-system/sw/bin/tmux`.
    - `macbook-pro-m1`: `role = "darwin-brain"`, pinned `hostKey`, aliases
      `mac`/`mbp`, tmux via `/etc/profiles/per-user/max-vev/bin/tmux`.
  - Line 270: `file.".config/fleet/hosts.json".text = builtins.toJSON fleetHosts;`
    — hosts.json is **write-only**; nothing in the repo parses it at runtime
    (verified 2026-07-03: no `jq`/`hosts.json` reads in either fleet module).
    Adding fields to `fleetHosts` is therefore additive-safe.
  - The `fleet` CLI script has host names/aliases baked in at build time via
    Nix string interpolation (`hostPatterns`, `caseHostPatterns`).
- `users/maxpw/modules/agent-tools.nix`:
  - `source path` helper (line 13) makes out-of-store symlinks into
    `~/nix-config/users/maxpw/agents/<path>`.
  - Links `shared/AGENTS.md` → `~/.codex/AGENTS.md`, `~/.claude/CLAUDE.md`,
    `~/.config/opencode/AGENTS.md`; composes Pi's AGENTS.md.
  - Links `.claude/commands` **recursively** from `claude/commands` (lines
    54–57). There is **no** `.codex/prompts` link yet.
- `users/maxpw/agents/` contains `claude/commands/{audit.md,daily.md}`,
  `opencode/`, `pi/`, `shared/`. There is **no** `codex/` directory yet.
- `users/maxpw/agents/shared/AGENTS.md` has a "Remote Dev Fleet" section
  (lines 49–66) describing fleet commands and the hosts.json location in
  prose.
- `CLAUDE.md` (repo root) mentions `nix flake check --no-build` once but has
  no per-change-type verification matrix.
- Codex custom prompts: markdown files in `~/.codex/prompts/`; filename
  becomes the slash command; `$ARGUMENTS`/`$1`–`$9` are substituted. Claude
  commands: same idea in `~/.claude/commands/`; plain markdown bodies work in
  both, so shared sources need no frontmatter.

## Steps

### Step 1 — Extend `fleetHosts` with agent-facing capability fields

In `modules/fleet/home-manager.nix`, add to **each** host in `fleetHosts`:

```nix
os = "nixos";               # or "darwin"
gui = true;                 # GUI/screenshot surface available
longRunningAgents = true;   # main-pc: true; macbook-pro-m1: false
```

Rationale for values: main-pc is the Linux workhorse (offload target);
the mac is the interactive "brain" — per the handoff doc, long-running agent
loops should not run on the primary laptop. Do not change any existing field.
`hosts.json` will gain these fields automatically via `builtins.toJSON` —
that is intended.

**Verify**: `nix flake check --no-build` passes;
`alejandra --check modules/fleet/home-manager.nix` passes.

### Step 2 — Generate the agent fleet contract from the same attrset

In the same file, add a generated markdown file next to hosts.json:

```nix
file.".config/fleet/FLEET.md".text = fleetContractText;
```

Build `fleetContractText` in the `let` block from `fleetHosts` via
`mapAttrsToList`. Required content, all derived from host attrs (no
hand-written host facts):

1. One-line header: what this file is, that it is generated from
   `modules/fleet/home-manager.nix`, and **do not edit**.
2. A per-host section or table: name, aliases, `os`, `role`, remote `user`,
   `gui`, `longRunningAgents`, `t3codePort` (omit row when the attr is
   missing — use `host.t3codePort or null` guards).
3. A short static footer: where to run what (`fleet run <host> <cmd>` for
   checks, `fleet ssh <host>` for tmux sessions, `fleet t3 <host>` for
   T3 Code), and the rule "long-running/unattended agent work only on hosts
   with `longRunningAgents = true`".

Keep the generator simple — string concatenation with `concatStringsSep` and
`optionalString`, matching the style already used in this file.

**Verify**: `nix flake check --no-build`; then render the text without
switching:
`nix eval --raw .#darwinConfigurations.macbook-pro-m1.config.home-manager.users.max-vev.home.file.".config/fleet/FLEET.md".text`
(adjust attr path if evaluating on Linux:
`.#nixosConfigurations.main-pc.config.home-manager.users.maxpw...`).
Expected: readable markdown listing both hosts with correct fields.

### Step 3 — Create the two commands as Codex prompts (canonical)

Create `users/maxpw/agents/codex/prompts/` with two plain-markdown files
(no frontmatter — they must work verbatim as both Codex prompts and Claude
commands).

**`nix-config-health.md`** — read-only health pass over `~/nix-config`:

- Check: dirty/untracked working-tree state (`jj status` falling back to
  `git status`), stale plan rows in `plans/README.md` (TODO/IN PROGRESS/
  "pending verify" older than the planning date), broken symlinks under
  `~/.claude`/`~/.codex`/`~/.config/fleet`, and the last rebuild result if
  `~/nixos-switch.log` or the nh log exists.
- Output: write a markdown report to
  `~/.local/share/agent-reports/$(date +%Y-%m-%d)-nix-config-health.md`
  (create the directory first), then print a ≤10-line summary.
- Hard constraint stated in the prompt: **read-only with respect to the
  repo** — no edits, no commits, no rebuilds, no fixes; findings only.

**`prompt-debt-audit.md`** — read-only audit of managed agent instructions:

- Scope: `users/maxpw/agents/**` in this repo, plus the installed surfaces
  they generate (`~/.codex/AGENTS.md`, `~/.claude/CLAUDE.md`,
  `~/.claude/commands/`, `~/.codex/prompts/`, `~/.config/opencode/`,
  `~/.pi/agent/AGENTS.md`).
- Flag: references to files/commands/paths that no longer exist; hostnames
  or aliases not present in `~/.config/fleet/hosts.json`; rules duplicated
  between repo-level and global agent files; instructions to edit generated
  files; sections that have grown past ~80 lines.
- Same output contract: report to
  `~/.local/share/agent-reports/$(date +%Y-%m-%d)-prompt-debt-audit.md`,
  ≤10-line printed summary, strictly read-only.

**Verify**: files exist and are plain markdown; `git diff --check` clean.

### Step 4 — Wire the prompts into Codex and Claude via Home Manager

In `users/maxpw/modules/agent-tools.nix`, using the existing `source` helper:

```nix
".codex/prompts" = {
  source = source "codex/prompts";
  recursive = true;
};
".claude/commands/nix-config-health.md".source = source "codex/prompts/nix-config-health.md";
".claude/commands/prompt-debt-audit.md".source = source "codex/prompts/prompt-debt-audit.md";
```

Individual `.claude/commands/<file>` entries coexist with the existing
recursive `claude/commands` link because `recursive = true` symlinks
per-file, not the directory. Do **not** duplicate the files into
`claude/commands/` — codex/prompts is the single source.

**Verify**: `nix flake check --no-build`;
`alejandra --check users/maxpw/modules/agent-tools.nix`.

### Step 5 — Add the verification matrix to repo `CLAUDE.md`

Add a short "Verification defaults" subsection under Conventions (≤8 lines):

- Formatting-sensitive Nix changes → `alejandra --check .`
- Nix module/config changes → `nix flake check --no-build`
- Docs-only changes → `git diff --check`
- Host rebuild (`make rebuild`) only when explicitly requested or when
  applying the config *is* the task.

**Verify**: `git diff --check`.

### Step 6 — Point `AGENTS.md` at the generated contract; add the credential rule

In `users/maxpw/agents/shared/AGENTS.md` "Remote Dev Fleet" section:

1. Add one sentence directing agents to read `~/.config/fleet/FLEET.md` for
   host capabilities and placement ("where should this run?").
2. Add one sentence: "Scheduled or unattended agent runs must not use the
   forwarded 1Password SSH agent; interactive sessions only." (This is the
   whole of handoff recommendation 5 that lands now.)
3. Trim any prose that merely restates what FLEET.md now generates — do not
   grow the section's net length.

Mind the working-tree hazard: this file already has uncommitted changes.

**Verify**: `git diff --check`; section did not grow net length.

### Step 7 — Document in `modules/fleet/README.md`

Add a short "Agent fleet contract" subsection: FLEET.md is generated from
`fleetHosts`, what the capability fields mean, and that new hosts must set
`os`/`gui`/`longRunningAgents` explicitly.

**Verify**: `git diff --check`.

### Step 8 — Final verification and handback

1. `alejandra --check .` — clean.
2. `nix flake check --no-build` — passes.
3. `git diff --check` — no whitespace errors.
4. Operator step (not the executor): `make rebuild` on one host, then confirm
   `~/.config/fleet/FLEET.md` exists, `~/.codex/prompts/` contains both
   prompts, `/nix-config-health` appears in Codex's prompt list and
   `/nix-config-health` in Claude's command list, and a manual run of each
   produces a report under `~/.local/share/agent-reports/` **without
   modifying the repo** (`jj status` clean afterward).

## STOP conditions

- Drift check shows in-scope files changed and the "Current state" excerpts
  no longer match — stop, re-anchor the plan.
- The uncommitted `AGENTS.md`/`CLAUDE.md` changes conflict with steps 5–6 —
  stop and ask the operator to commit or describe the in-flight work.
- Anything in `modules/fleet/` turns out to parse `hosts.json` at runtime
  after all — stop before adding fields.
- `nix eval` of the generated FLEET.md fails or renders host facts that
  contradict `fleet list` — stop; the generator is wrong, do not hand-patch
  the output.
- Any step would require editing `~/.config/fleet/hosts.json`, `~/.codex/`,
  or `~/.claude/` directly — never do this; those are generated/managed.

## Done criteria

- `fleetHosts` entries carry `os`, `gui`, `longRunningAgents`.
- `~/.config/fleet/FLEET.md` is generated from `fleetHosts` (verified via
  `nix eval`), and `AGENTS.md` references it.
- `users/maxpw/agents/codex/prompts/{nix-config-health,prompt-debt-audit}.md`
  exist, are wired into both `~/.codex/prompts/` and `~/.claude/commands/`
  from a single source, and are read-only-by-contract.
- Repo `CLAUDE.md` has the verification matrix.
- `AGENTS.md` has the unattended-credential rule and did not grow.
- All of: `alejandra --check .`, `nix flake check --no-build`,
  `git diff --check` pass.

## Deliberately out of scope (from the handoff doc, with rationale)

- **Bounded agent loop command** — the loop shape duplicates the existing
  Planning First + Verification policy in `AGENTS.md`; only the verification
  matrix is new, and it lands in `CLAUDE.md` (step 5). Revisit only if a
  concrete loop failure shows the policy is insufficient.
- **Scheduled timers (launchd/systemd)** — run the two commands manually
  first; wire timers as a separate plan once the reports prove useful.
- **`scripts/check-agent-prompts.sh`** — premature; the agent-file surface is
  small. Extract mechanical checks into a script only if `prompt-debt-audit`
  repeatedly finds the same classes of issue.
- **Agent secret isolation / `agent-runner` role** — deferred until the first
  unattended scheduled loop exists. The one-sentence credential rule in
  step 6 is the placeholder. Candidate host when it happens: main-pc.
- **Pi prompt changes in `~/pi-config`** — separate repo; out of scope here.
