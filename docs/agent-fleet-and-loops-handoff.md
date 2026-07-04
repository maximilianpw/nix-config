# Agent Fleet And Loops Handoff

This document summarizes the recent Theo/t3.gg and Nerd Snipe research pass
from July 3, 2026. It is intended as a handoff for an LLM that should turn the
research into concrete improvements in this NixOS/nix-darwin/Home Manager repo.

Do not treat this as a transcript archive. The source material was analyzed from
YouTube metadata and English auto-generated captions, with help from two
subagents. Use the linked videos for primary context and keep any quoting short.

## Sources Reviewed

Primary Theo/t3.gg videos:

- [Why I’m moving to Linux (for real)](https://www.youtube.com/watch?v=9tGrhrVKCrE), published 2026-07-03.
- [FABLE IS BACK! (And Sonnet 5 is here too)](https://www.youtube.com/watch?v=KSV-7ywHxeU), published 2026-07-01.
- [Why is OpenAI so much more efficient?](https://www.youtube.com/watch?v=ypO0q_8zhWw), published 2026-06-30.
- [The next paradigm shift (according to Karpathy)](https://www.youtube.com/watch?v=tOC2N0B9lio), published 2026-06-25.
- [I don’t have time to build these things, will you?](https://www.youtube.com/watch?v=wEAb0x3wTRc), published 2026-06-22.
- [I guess we’re writing loops now?](https://www.youtube.com/watch?v=iJVJwmCKW9o), published 2026-06-18.
- [Mythos is here, it’s time to start tokenmaxxing](https://www.youtube.com/watch?v=3sTu8sSLVfg), published 2026-06-12.
- [More Prompts = Worse Code?](https://www.youtube.com/watch?v=WnBx1Vi7M6w), published 2026-06-03.
- [How I code with AI changed a lot](https://www.youtube.com/watch?v=xJaMTo2YgO8), published 2026-05-27.
- [Claude Code vs Codex vs Cursor](https://www.youtube.com/watch?v=JMYspR42HFM), published 2026-05-26.

Primary Nerd Snipe episodes:

- [Nerd Snipe with Theo and Ben](https://podcasts.apple.com/ca/podcast/nerd-snipe-with-theo-and-ben/id1892197141), podcast listing.
- [GPT-5.6 is here! And none of us can use it.](https://www.youtube.com/watch?v=5r2qi7AcEVo), published 2026-06-30.
- [The US Government Banned Claude Fable 5...](https://www.youtube.com/watch?v=qfSgN9i5Fd4), published 2026-06-24.
- [Our impressions of Claude Fable/Mythos](https://www.youtube.com/watch?v=V-SRz9_WqpM), published 2026-06-15.
- [Now even Google’s buying GPUs from SpaceX?](https://www.youtube.com/watch?v=zsv_F_KeG6M), published 2026-06-10.
- [We mostly like Claude Opus 4.8](https://www.youtube.com/watch?v=EYq1_mB-xJ4), published 2026-06-03.
- [How the OpenClaw creator uses $1.3 million of tokens](https://www.youtube.com/watch?v=A3GpF_y1N0E), published 2026-05-20.

Shorts that were useful mainly as confirmations:

- [Find This Hidden Codex Setting For Agents](https://www.youtube.com/shorts/PxQ9jUjdLpY), published 2026-07-01.
- [The Cursor team is building Origin...so what is it?](https://www.youtube.com/shorts/lWw2_dz6tq0), published 2026-06-30.
- [Stop Copy Pasting Code](https://www.youtube.com/shorts/TQwhrXeRBkY), published 2026-06-22.
- [Github isn’t a Multiplayer Solution](https://www.youtube.com/shorts/vhNBcShnQek), published 2026-06-30.

## High-Level Learnings

The useful lesson is not a specific Nix/Home Manager trick. I did not find
recent explicit discussion of Nix, Home Manager, or nix-darwin in these
transcripts. The reusable pattern is an operating model for agent-heavy
development:

- Offload long-running agent work from the daily laptop to Linux machines.
- Make one trusted "brain" machine able to reach the rest of the fleet through
  SSH, Tailscale, and persistent terminal sessions.
- Keep agent instructions versioned, small, concrete, and available on every
  host.
- Use T3 Code or similar remote surfaces so agents can run on other machines
  while the human keeps screenshots, image prompts, and GUI visibility.
- Prefer bounded loops over open-ended autonomy: plan, run one slice, verify,
  review, and stop with artifacts.
- Treat prompt files and skills as production configuration. They decay, and
  they can accidentally become a second unreviewed codebase.
- Separate powerful human credentials from unattended or scheduled agent
  credentials.

## Concrete Evidence

Theo’s Linux video is the strongest fit for this repo. Around the early section
he describes Mac agent work hammering the machine, then moves toward Linux
boxes. Around the setup section, the pattern is a laptop with SSH keys and
passwordless access to the other computers. Later sections show persistent tmux,
network KVMs, Tailscale, T3 Code remote environments, and agents using the
networked machines to fix each other.

Nerd Snipe’s June 24 episode discusses the Codex parallel-agent setting and the
cost of many subagents on macOS. It also makes the same Linux-offload point:
many long-running agent loops should not run on the primary laptop.

Nerd Snipe’s June 15 episode is useful for loop design. The workflow pattern is
roughly: implementation agent, reviewer agent, feedback loop, repeat until the
review comments are addressed. The caution is token burn and fragile state when
rate limits or app state break.

Theo’s Claude Tag video is the scheduling warning. Async scheduled tasks are
powerful, but scheduled work colliding with ad hoc work creates confusing
context and state. Local scheduled prompts should therefore run in isolated
threads, write separate logs, and avoid surprising edits.

The prompt-debt videos and sections argue for smaller, fact-heavy prompt files.
Agents should learn commands, host inventory, verification gates, and local
policies from versioned files, but those files should be actively reviewed.

## Current Repo Context

This repo already has unusually good foundations for these ideas:

- `modules/fleet/home-manager.nix` and `modules/fleet/nixos.nix` define the
  remote development fleet, SSH behavior, tmux workflow, Tailscale assumptions,
  and `fleet t3`.
- `modules/fleet/README.md` documents the intended fleet workflow.
- `users/maxpw/modules/t3code-server.nix` runs a headless T3 Code server on
  Linux desktop hosts.
- `users/maxpw/modules/agent-tools.nix` installs and links Claude, Codex,
  OpenCode, Pi, shared `AGENTS.md`, Claude commands, and skills.
- `users/maxpw/agents/shared/AGENTS.md` is already a cross-agent operating
  policy.
- `users/maxpw/agents/claude/commands/audit.md` and `daily.md` prove the repo is
  comfortable managing reusable agent commands.
- `~/pi-config` already has Pi prompt templates and a loop extension. That is
  outside this repo, but Home Manager links it into the installed Pi config.

The next work should deepen these existing surfaces instead of adding a new
agent framework.

## Recommended Additions

### 1. Agent Fleet Contract

Add an agent-facing fleet document generated from the same host inventory that
drives the `fleet` CLI.

Target behavior:

- Agents can answer "where should this run?" without rediscovering machines.
- Each host has explicit capabilities: OS, role, SSH alias, Tailscale name,
  tmux support, T3 Code port, GUI availability, KVM availability, and whether
  long-running agent work is allowed.
- The generated document is linked into `~/.codex`, `~/.claude`, OpenCode, and
  Pi context, or referenced from the shared `AGENTS.md`.

Likely files:

- `modules/fleet/home-manager.nix`
- `modules/fleet/README.md`
- `users/maxpw/modules/agent-tools.nix`
- `users/maxpw/agents/shared/AGENTS.md`

Do not edit generated `~/.config/fleet/hosts.json` directly.

### 2. Bounded Agent Loop Command

Add a repo-specific loop prompt or command that encodes the safe loop shape for
this Nix config.

Suggested loop:

1. Restate the objective and affected files.
2. Split into small tasks, using subagents only for independent research or
   disjoint file scopes.
3. Make one bounded change.
4. Run the smallest relevant verification.
5. Run a review pass focused on regressions and missed verification.
6. Stop with a short summary and follow-ups.

For this repo, verification defaults should be:

- `alejandra --check .` when formatting-sensitive Nix files changed.
- `nix flake check --no-build` for Nix module/config changes.
- `git diff --check` for docs-only changes.
- A host-specific rebuild only when explicitly requested or when applying the
  configuration is the purpose of the task.

Likely files:

- `users/maxpw/agents/claude/commands/`
- `users/maxpw/agents/shared/AGENTS.md`
- Possibly `~/pi-config/prompts/`, but only if the user chooses to manage that
  source repo in parallel.

### 3. Scheduled Prompt Templates

Create prompt templates for scheduled or recurring work, but make them
write-report-only by default.

Useful scheduled prompts:

- Daily or post-change `nix-config health`: check dirty state, stale plan
  statuses, obvious failed verification notes, and recent rebuild failures if
  logs are available.
- Weekly `prompt-debt audit`: inspect `AGENTS.md`, Claude commands, OpenCode
  config, and Pi prompts for stale commands, stale hostnames, duplication, or
  rules that should be deleted.
- Weekly `fleet drift audit`: compare configured fleet hosts with reachable
  Tailscale/SSH hosts, without changing SSH config or host keys.
- Weekly `agent tooling update report`: inspect llm-agent package versions,
  custom package versions, and relevant release notes, then report candidate
  updates without applying them.

Important constraint:

- Scheduled prompts should create markdown reports under a predictable directory
  such as `~/Documents/obsidian vault/...` or `~/.local/share/agent-reports/`.
  They should not edit this repo unless the user explicitly asks.

Likely files:

- `users/maxpw/agents/claude/commands/`
- `users/maxpw/modules/agent-tools.nix`
- Optional future Home Manager launchd/systemd user timer module.

### 4. Prompt-Debt Check

Add a lightweight check for managed agent instructions.

The check should flag:

- References to files or commands that no longer exist.
- References to generated files that should not be edited.
- Hostnames or fleet aliases that are missing from the fleet config.
- Excessively long agent policy files.
- Duplicate rules that appear in both repo and global agent files.

This can start as a script and later become a CI/pre-commit hook.

Likely files:

- `scripts/check-agent-prompts.sh`
- `users/maxpw/modules/agent-tools.nix`
- `plans/004-lint-format-gate.md` only if extending lint gates later.

### 5. Agent Secret Isolation

Do not start here unless the user wants security hardening, but it is the
highest-risk long-term gap.

The current fleet guidance trusts internal hosts and allows SSH agent forwarding
so Git and agent tools can use the 1Password SSH agent from the brain machine.
That is convenient for interactive work. It is too much authority for unattended
scheduled loops.

Future direction:

- Add an `agent-runner` role or profile for machines allowed to run unattended
  loops.
- Use low-privilege SSH/GitHub credentials for scheduled agents.
- Prefer short-lived `.env` injection from 1Password or sops over broad shell
  secrets.
- Keep destructive operations denied or human-approved.

Likely files:

- `modules/fleet/nixos.nix`
- `modules/fleet/home-manager.nix`
- `modules/core/sops.nix`
- `users/maxpw/modules/agent-tools.nix`

## Suggested Execution Plan

The safest first implementation slice is documentation and prompt surfaces only:

1. Add an "Agent Fleet" section to `modules/fleet/README.md` describing the
   brain-host model, long-running host selection, and T3 Code/Tailscale usage.
2. Extend `users/maxpw/agents/shared/AGENTS.md` with a short "Agent Fleet
   Usage" section that points agents to `fleet list`, `fleet ssh`, `fleet run`,
   and `fleet t3`.
3. Add one Claude command, for example `users/maxpw/agents/claude/commands/nix-config-health.md`,
   that performs a read-only health/report pass.
4. Add one prompt-debt audit command, also read-only.
5. Verify with `git diff --check`. If Nix files were touched, add
   `nix flake check --no-build`.

After that, implement generated fleet context and scheduled timers as separate
changes. Do not combine scheduling, credentials, and prompt refactors in one
patch.

## Non-Goals

- Do not copy Theo’s setup wholesale.
- Do not add a new agent platform if the existing Codex/Claude/OpenCode/Pi
  setup can be deepened.
- Do not enable unattended repo edits as the first scheduled-prompt iteration.
- Do not broaden SSH or 1Password access for agents without an explicit threat
  model.
- Do not make prompt files longer just because agent workflows are getting more
  important. Prefer small, checked, linked documents.

## Open Questions For The Implementing LLM

- Should the generated fleet context live under `~/.config/fleet/` or under the
  managed agent files in `~/.codex`, `~/.claude`, and OpenCode?
- Should scheduled reports target Obsidian daily notes, a dedicated local report
  directory, or both?
- Should Pi prompt/template changes be made in `~/pi-config` as a separate repo
  change, or should this repo only link to that external source?
- What is the first host, if any, that should be marked safe for unattended
  long-running agent work?
- What credentials should scheduled agents receive, and what operations should
  remain human-only?
