# Nix configuration inspiration review

Research date: 2026-10-08. Local baseline: HEAD `5e04bd3` **plus the current
staged/unstaged working tree**, including Mergiraf, the Nixvim/Hjem migration,
and manual-only full CI builds. Four read-only subagents covered all nine
sources below. The main agent checked the strongest findings against source,
local configuration and selected evaluated NixOS values. No proposed feature
was implemented and no host was changed.

## Conclusions

Borrow small capabilities, not another configuration framework. The most
useful next work is:

1. Documentation-aware CI selection, preserving a successful required status.
2. A bounded systemd-boot menu on Kim, with an explicit recovery decision about
   boot-argument editing.
3. A few missing Prometheus alerts, using the exporters already installed.
4. A Joyce-only trial of asynchronous direnv integration.
5. Better Nix option navigation, starting with a `nixd` trial rather than an
   editor rewrite.

Managed agent security policy, workstation backups and Linux builds from
Joyce are worthwhile **design decisions**, not automatic configuration imports.
None requires restoring expensive full-host builds on every push.

### Mitchell is an ancestor, not a new template

The user confirms this repository began by copying Mitchell's configuration.
Local commit `fa3229bcc5402ef1071b8e26a1d0e7fe8c282d3d` (2025-07-23,
“feat: mitchellh the goat module fixes”) introduced `lib/mksystem.nix`.
Earlier local history exists; this review does **not** establish a precise
upstream fork point. The constructor, `machines/` and `users/` separation,
Darwin/WSL branching, Make workflow and several shell/Git defaults are inherited
or already extended. They are not new recommendations.

## Sources and scope

Commit links pin the reviewed trees. License observations apply to those trees;
retain the required notices if later copying substantial implementation code.

| Source | Reviewed commit | Relevant scope | Verdict |
| --- | --- | --- | --- |
| [Mic92/dotfiles][mic92] | `88ff5f7b12f122025c517fee553e9b9d4ee1adbf` | Nix daemon, GC, journald, server/workstation defaults | Explicit log budget is optional; reject age-only GC-root deletion. MIT verified in `LICENSE.md`. |
| [Misterio77/Foundry][misterio] (redirect from `nix-config`) | `d16c864b2618e1e89f93ce07cafa3ae5ba14cba9` | Server/store sharing, HM composition, backup/auto-upgrade patterns | No urgent missing capability; optional trusted store sharing. MIT. |
| [ryan4yin/nix-config][ryan] | `9ba2cf52292c58e103e471defed6d3c1380c1df2` | Backup threat model, cross-platform setup, eval CI | Best source for documentation-aware CI and workstation-backup design. MIT. |
| [mitchellh/nixos-config][mitchell] | `40d483d74cf48d64379fc9a857237ee18c519ff4` | New direnv integration, Darwin Linux builder, inherited layout | Compare new capabilities, not the shared ancestry. MIT. |
| [fufexan/dotfiles][fufexan] | `4ec78a48dc3cf51b69866330a50ba5f0d4e6d754` | Nix REPL, registry, CLI utilities, desktop | A small REPL convenience and optional disk tools; registry proposal mostly redundant on NixOS. MIT. |
| [hlissner/dotfiles][hlissner] | `fa72377393680f953fcb9efaa30994ea91eba233` | Boot/security, managed Claude policy, developer modules | Borrow policy separation, not the `hey` framework or entire sysctl bundle. MIT. |
| [vimjoyer/nixconf][vimjoyer] | `421795866265554d9ca5f2c7b658aac80d9ab0f9` | Nix editor/navigation, wrappers and Hjem | Nix navigation is useful; wrappers/Hjem/editor ownership largely overlap. MIT. |
| [nix-community/srvos][srvos] | `cb9ecc7fbfdb9e71876b565c8b346db6ffa6d331` | Server boot policy, Nix settings, monitoring rules | Borrow individual options/rules, not the server profile wholesale. MIT. |
| [numtide/blueprint][blueprint] | `8be75245e274a789b87cc4df542abbcd8c5e7f93` | Package discovery, per-system scope, automatic checks | Optional explicit package registry; no framework migration. MIT. |

Effort below: S = hours; M = roughly a day or more including verification;
L = multi-day or operational rollout. Estimates are not implementation promises.

## Recommended candidates

### 1. Skip expensive checks for genuine documentation-only changes

**Source:** Ryan's [evaluation workflow][ryan-ci] uses path exclusions.
**Local gap:** `.github/workflows/ci.yml` still runs all five lightweight Nix
jobs for documentation-only changes. Full builds are now opt-in, but Nix setup,
evaluation and dependency downloads still consume runner time.

Adapt the idea, **not** their exclusion list:

- Limit exclusions to proven non-executable documentation, initially `docs/**`
  and selected root documentation files.
- Do not blanket-ignore Markdown: `users/maxpw/modules/agent-tools.nix:98-104`
  reads/deploys agent policy Markdown as configuration.
- Do not ignore `scripts/**`, Nushell configuration, workflow files, flake
  inputs, tests or editor content. Ryan excludes scripts/Nushell; that is wrong
  for this repository.
- If checks are required by branch protection, keep an always-reporting gate
  rather than leaving a required workflow pending through trigger-level filters.
- Mixed documentation/code changes must run normal checks. Manual full builds
  must remain explicitly requestable regardless of changed paths.

**Integration:** existing CI workflow and a tested change selector, if needed.
**Effort S–M; risk low–medium; confidence high.** This saves recurring Actions
minutes; no exact saving is claimed without subsequent run measurements.

### 2. Bound Kim's boot menu; decide boot-editor policy separately

**Sources:** srvos [server profile][srvos-server] sets a boot-entry limit of five;
hlissner [security module][hlissner-security] disables systemd-boot's editor.
**Local evidence:** `machines/kim.nix:28-32` enables systemd-boot. Evaluation of
the current configuration returned `configurationLimit = null` and
`editor = true`.

A limit such as 5–10 entries reduces the chance of exhausting the EFI partition
between weekly cleanup runs. Pick the number after inspecting the real ESP and
reviewing how many bootable rollback generations are needed. The existing
`nh clean --keep 5 --keep-since 30d` is a **retention floor plus age window**, not
a guarantee that only five generations exist. Boot-menu retention and store
retention are different controls.

Disabling interactive boot-argument editing is a separate hardening choice. It
removes a recovery convenience and does not substitute for Secure Boot or disk
encryption. Record an alternative recovery path before changing it.

**Integration:** Kim only, plus an assertion in an existing regression check.
**Effort S; risk medium because recovery behavior changes; confidence high.**
No new CI job or runtime daemon. No ESP usage or live boot test was performed.

### 3. Add missing monitoring rules without adding a monitoring stack

**Source:** srvos [default Prometheus alerts][srvos-alerts] covers inode
exhaustion, OOM kills, rule-evaluation failures and Prometheus-to-Alertmanager
connectivity.
**Local evidence:** `homelab/monitoring.nix:182-216` already has extensive
filesystem-byte, SMART, backup, unit and endpoint alerts, but not these cases.
The existing scrape list includes Prometheus and Alertmanager at lines 310–316;
node-exporter uses its default collectors plus textfile at lines 364–365.

Adapt to the existing node-exporter metric names, rather than copy srvos's
Telegraf expressions:

- Inode free fraction, restricted to operational filesystems with meaningful
  inode counts.
- Kernel OOM-kill counter increases.
- Prometheus rule-evaluation failures and no discovered Alertmanager.

Verify metric availability and use disposable `promtool` rule fixtures to test
firing, recovery and missing-data behavior. Do not deliberately exhaust a live
disk or trigger a live OOM. This adds coverage; it does not establish that Kim
currently suffers any of these problems. External alert delivery is already
an unresolved item in `docs/homelab-backlog.md` and is not fixed by more rules.

**Integration:** `homelab/monitoring.nix` and existing monitoring regression tests.
**Effort S–M; risk low; confidence high on the configuration gap.** A few rule
expressions and lightweight tests; no Telegraf, Loki, extra host or full-build CI.

### 4. Trial `direnv-instant` on Joyce

**Source:** Mitchell [imports/enables it][mitchell-home]. The actual dependency
was checked at Mic92/direnv-instant commit
`0e801532fa718f08f963fc688e78939b2297033d`:
[README][instant-readme] and [Home Manager module][instant-home].
**Local gap:** `users/maxpw/home-manager.nix:120-123` enables ordinary direnv
and nix-direnv; there is no asynchronous integration input.

It returns the prompt while evaluating in the background and can open a
Herdr/tmux progress pane for slow evaluations. Retain nix-direnv's environment
cache/GC roots. The inspected HM module explicitly disables the ordinary hooks
for enabled shells, so keeping `programs.direnv.enable = true` is not itself a
double-hook bug.

The trade-off is real: a visible prompt is no longer proof that a newly selected
environment is ready. Nushell polls on prompts rather than trapping SIGUSR1;
new variables can arrive only at the next prompt. Test first entry, cached
re-entry, directory switching during a slow evaluation, cancellation, errors,
and scripts/agent commands that assume immediate environment readiness.

**Integration:** flake input and the existing HM shell configuration, initially
Joyce-only. **Effort S–M; risk medium; confidence high on feature fit, unverified
on this setup.** Adds a dependency and local background work; no new scheduled
CI job. Do not treat it as a build-speed improvement or enable it fleet-wide
before the shell trial.

### 5. Improve Nix option navigation, not the whole editor

**Sources:** vimjoyer's [Nix LSP configuration][vimjoyer-lsp] and
[tool environment][vimjoyer-env]; [nixd's own configuration guide][nixd-docs].
**Local gap:** `users/maxpw/neovim/tooling.nix:21` installs `nil`, and
`users/maxpw/neovim/config/lsp/nil_ls.lua` configures it without the explicit
NixOS/Darwin/Home Manager option sets that nixd can evaluate.

Trial nixd in the existing Nixvim candidate, configured against the checked-out
flake and selected host options. HM is integrated into the system here: do not
copy an example that assumes standalone `homeConfigurations`. Keep conform and
Alejandra as the formatting owner. Avoid two language servers duplicating
formatting/diagnostics unless that is a deliberate tested setup.

`manix` and `nix-inspect` are optional smaller experiments. Fufexan's
[REPL helper][fufexan-repl] is another convenience, but first try stock
`nix repl` with `:lf .`; a custom wrapper must support Darwin and the local host
inventory rather than upstream's `/etc/hostname`/NixOS assumptions. `dust`/`duf`
are optional package conveniences, not architecture work.

**Integration:** editor tooling/LSP files; optionally terminal packages.
**Effort M for nixd, S for standalone tools; risk medium; confidence medium.**
Nix option evaluation has real local memory/CPU cost; nixd documents roughly
200–300 MB just for nixpkgs names. Benchmark interactive completion. Keep
candidate checks targeted, not a new recurring full-editor/full-host CI build.

## Design decisions worth pursuing only with a clear need

### Managed Claude security policy — hlissner

[Their module][claude-module] separates personal preferences from
[system-managed restrictions][claude-defaults]. The local Claude configuration
has user-level permissions and no sandbox block; the existing file is already
staged/edited by the user and was not modified during this review.

A small managed policy could enforce approved secret-path/sandbox restrictions
and publication/activation consent while leaving model/UI settings personal.
This needs a dedicated design because this workflow deliberately uses permissive
agent modes, Fleet, SSH and credential helpers. Read/Edit permission rules alone
are **not** an OS-level barrier to shell or other-tool access. Sandbox policy,
CLI bypass behavior and each agent's scope must be verified with harmless
fixtures, not real secrets. It would protect Claude sessions only, not Pi,
Codex or every tool on the machine.

[Official managed-settings documentation][claude-managed] confirms file/drop-in
support and the system locations: `/etc/claude-code/` on Linux/WSL and
`/Library/Application Support/ClaudeCode/` on macOS. A user HM file on macOS is
**not** automatically managed policy. Local admin rights and other executables
remain outside that guarantee. Do not indiscriminately deny encrypted SOPS files
that operators need to edit.

**Effort M; policy/compatibility risk medium–high.** No new CI job required;
platform installation and real policy acceptance tests are necessary.

### Joyce backup coverage and independent decryption authority — Ryan

Ryan's [backup threat model][ryan-backup] keeps workstation repository passwords
off the backup server. That is useful even if retaining Borg rather than adding
restic. Local `modules/services/backup.nix` is Kim-focused; Joyce's
`users/maxpw/modules/syncthing.nix` leaves folder/device pairing to mutable
Syncthing state. Neither proves Joyce has no backup: Time Machine, other tools
and the actual folder selection were **not inspected**.

First inventory unique workstation data and existing recovery coverage. If a
client backup is missing, choose destinations, retention, off-site copies and
an offline recovery key; do not replace Kim's application-consistent Borg
pipeline or import Ryan's broad secret exclusions without reviewing recovery.
A repository stored only on Kim is not off-site. Off-site backup and offline
identity recovery are already recorded local backlog items.

**Effort M–L; risk medium; runtime disk/network load; no recurring CI requirement.**
This is a recovery-design task, not a package addition.

### Linux verification from Joyce — Mitchell, with Misterio as an adjacent idea

Mitchell's [Darwin module][mitchell-system] enables an on-demand
`nix-rosetta-builder`. It addresses a demonstrated local constraint: the Linux
Mergiraf regression evaluated but could not build on this Darwin-only builder.
Compare a local on-demand VM against a tightly scoped remote builder on Kim.
The latter consumes Kim's resources and needs explicit trust/account policy;
Fleet access alone is not a configured Nix remote builder.

Do not copy Mitchell's `lima-1.2.2` insecurity exception or openapv cache workaround
without current justification. Verify compatibility with Determinate's daemon
ownership and `machines/joyce.nix`; do not switch `nix.enable` to true.

Misterio's [SSH store serving][misterio-store] is related but **not equivalent**:
a read-only substituter can reuse already-built Linux outputs, but cannot
execute a missing Linux derivation. It does not make `make check-linux` a runtime
test. Their sample grants writes and trusted-user status; do not inherit those
privileges for a read-only-cache use case.

**Effort M; risk medium–high; host RAM/disk or Kim build load.** Potentially fewer
manual GitHub builds, not more automatic Actions work. Start only if repeated
Linux verification justifies the infrastructure.

## Smaller or conditional borrows

- **Mic92 journald budget:** [workstation module][mic92-workstation] sets 1G.
  No explicit local journal cap was found. Inspect actual usage and retention
  requirements before choosing 1–2G. This is an intentional budget, not fixing
  unlimited logging: [systemd's default][journald-doc] is 10% capped at 4G, with
  keep-free constraints and rotation caveats. Journal limits do not cap all
  application/Docker logs. S effort, no new CI jobs.
- **srvos cache timeouts/store free-space thresholds:** [source][srvos-nix]
  sets a short connection timeout, fallback, and automatic-GC watermarks.
  Those overrides are absent locally. Adopt independently if observed cache
  outages or low store space justify them. `fallback = true` can turn a cache
  failure into a very expensive source build; do not promise shorter builds or
  enable it in CI just for speed. A 512 MiB free-space trigger fires near disk
  exhaustion, not before an 80% disk alert. Automatic GC reclaims only eligible
  unrooted store paths, not application data. Joyce settings belong in
  `nix.custom.conf`. S–M effort; runtime/operational trade-offs require care.
- **Blueprint's package registration:** [package discovery/scoping][blueprint-lib]
  suggests centralizing the explicit custom-package list used by the overlay
  and platform outputs (`flake.nix:174-184,254-281`). Prefer a small explicit
  registry if duplication becomes painful. Blind directory imports add hidden
  behavior, and Linux-only packages must be gated before problematic evaluation.
  Not every exported package comes from `packages/`. S–M, low priority, no
  automatic package-build checks.
- **Ryan's all-host policy tests:** an expected-policy table could complement
  `tests/fleet-trust-regression.nix`, but the latter already iterates hosts and
  CI already evaluates Kim/Cuno/Joyce. Add specific missing invariants, not
  another generic test framework or host-sized golden snapshots.
- **Misterio per-host HM feature composition:** revisit if the fleet grows or
  a desktop returns. The current shared user tree and platform flags already
  solve most of the problem. No current reason for a directory-layout rewrite.

## Rejected findings and corrections from vetting

1. **Age-based GC-root sweeping is not a safe quick win.** Mic92's
   [cleanup service][mic92-gc] deletes symlinks by modification age, including
   non-broken ones. A 30-day-old root can still protect an actively used project.
   Matching `nh`'s retention duration does not establish liveness. Do not import
   the sweeper without a diagnosed leak and a report-only ownership review.
2. **NixOS registry pinning is already effective.** Fufexan declares it
   explicitly, but evaluating Kim showed a `nixpkgs` registry pointing into the
   locked store source and `nixpkgs=flake:nixpkgs` in `nixPath`. A missing local
   assignment is not a missing feature. `accept-flake-config = false` is also a
   Nix default, not evidence of an existing automatic trust grant. Darwin can
   be reviewed independently if ad-hoc package consistency is a problem.
3. **Do not adopt srvos wholesale.** Its profile includes passwordless wheel
   sudo, mutable-user policy, reduced desktop facilities, headless emergency
   behavior and other broad changes. Local tailnet SSH restrictions and
   root-only trusted Nix users must remain. Explicit Kim scheduler weights are
   measured policy, not a gap to replace with generic tuning.
4. **Disabling emergency mode is not guaranteed recovery.** srvos makes that
   trade-off, but it does not guarantee working networking after a mount/fsck
   failure. Preserve storage dependencies and test failure behavior in a
   disposable VM before any decision. Wake-on-LAN does not repair filesystem
   or boot failures. No default recommendation now.
5. **Do not copy a desktop sysctl bundle.** Kim's evaluated configuration enables
   IPv4 forwarding; Tailscale/Docker interactions need inspection. “We're not a
   router” assumptions, rp_filter, BBR/CAKE and a 75%-RAM tmpfs are not universal
   hardening defaults. No memory-pressure evidence currently justifies new
   zram, memory caps or priority changes.
6. **No framework/ownership reset.** Keep the typed inventory, Fleet, SOPS,
   Nixvim, Hjem and the explicit mutable-app exceptions. Reject hey/Janet,
   wrappers replacing Home Manager, wholesale Blueprint/flake-parts/haumea,
   another secret manager, and checkout-linked Neovim as proposed replacements.
   Hjem is already enabled; upstream clobber defaults would weaken the local
   handoff contract.
7. **No all-host automatic build/deploy machinery.** Blueprint registers package,
   devshell and host-closure checks; Misterio's Hydra/pull upgrades and Mic92's
   closure-prefetch machinery assume different infrastructure. Do not add them
   to routine CI or automatic activation here.
8. **Existing homelab recovery is substantial.** Quiesce/dumps, version metadata,
   archive inspection, restore procedures and monitoring already exist. Borrow
   a precise missing property rather than replacing them with another generic
   backup module. No external provider or live recovery acceptance gap is solved
   merely by declaring more configuration.

## Verification and limits

- Main-agent source reads verified the recommendations and corrected the above
  subagent overclaims. Upstream source was never executed.
- Read-only Nix evaluation confirmed Kim's boot menu/editor, emergency-mode,
  registry, selected daemon settings and configured sysctls. This verifies the
  evaluated configuration, not every live service state.
- Shell/editor usability, Joyce Time Machine coverage, current ESP/journal use,
  builder performance and Claude managed-policy behavior remain unverified.
- No secrets were decrypted, `.env` files read, host changes activated, workflows
  dispatched, or source configuration changed. Only this research note and its
  documentation-index entry were added by this task.
- This is a bounded comparative review, not a complete security or dependency
  audit of nine upstream repositories. Licenses and supply-chain details must
  be rechecked for any concrete copied implementation.

## Sources

[mic92]: https://github.com/Mic92/dotfiles/tree/88ff5f7b12f122025c517fee553e9b9d4ee1adbf
[misterio]: https://github.com/Misterio77/Foundry/tree/d16c864b2618e1e89f93ce07cafa3ae5ba14cba9
[ryan]: https://github.com/ryan4yin/nix-config/tree/9ba2cf52292c58e103e471defed6d3c1380c1df2
[mitchell]: https://github.com/mitchellh/nixos-config/tree/40d483d74cf48d64379fc9a857237ee18c519ff4
[fufexan]: https://github.com/fufexan/dotfiles/tree/4ec78a48dc3cf51b69866330a50ba5f0d4e6d754
[hlissner]: https://github.com/hlissner/dotfiles/tree/fa72377393680f953fcb9efaa30994ea91eba233
[vimjoyer]: https://github.com/vimjoyer/nixconf/tree/421795866265554d9ca5f2c7b658aac80d9ab0f9
[srvos]: https://github.com/nix-community/srvos/tree/cb9ecc7fbfdb9e71876b565c8b346db6ffa6d331
[blueprint]: https://github.com/numtide/blueprint/tree/8be75245e274a789b87cc4df542abbcd8c5e7f93
[ryan-ci]: https://github.com/ryan4yin/nix-config/blob/9ba2cf52292c58e103e471defed6d3c1380c1df2/.github/workflows/flake_evaltests.yml
[srvos-server]: https://github.com/nix-community/srvos/blob/cb9ecc7fbfdb9e71876b565c8b346db6ffa6d331/nixos/server/default.nix
[hlissner-security]: https://github.com/hlissner/dotfiles/blob/fa72377393680f953fcb9efaa30994ea91eba233/modules/security.nix
[srvos-alerts]: https://github.com/nix-community/srvos/blob/cb9ecc7fbfdb9e71876b565c8b346db6ffa6d331/nixos/roles/prometheus/default-alerts.nix
[mitchell-home]: https://github.com/mitchellh/nixos-config/blob/40d483d74cf48d64379fc9a857237ee18c519ff4/users/mitchellh/home-manager.nix
[instant-readme]: https://github.com/Mic92/direnv-instant/blob/0e801532fa718f08f963fc688e78939b2297033d/README.md
[instant-home]: https://github.com/Mic92/direnv-instant/blob/0e801532fa718f08f963fc688e78939b2297033d/home.nix
[vimjoyer-lsp]: https://github.com/vimjoyer/nixconf/blob/421795866265554d9ca5f2c7b658aac80d9ab0f9/wrappedPrograms/neovim/lsp.nix#L84-L108
[vimjoyer-env]: https://github.com/vimjoyer/nixconf/blob/421795866265554d9ca5f2c7b658aac80d9ab0f9/wrappedPrograms/environment.nix
[nixd-docs]: https://github.com/nix-community/nixd/blob/main/nixd/docs/configuration.md
[fufexan-repl]: https://github.com/fufexan/dotfiles/blob/4ec78a48dc3cf51b69866330a50ba5f0d4e6d754/lib/repl.nix
[claude-module]: https://github.com/hlissner/dotfiles/blob/fa72377393680f953fcb9efaa30994ea91eba233/modules/ai/claude.nix
[claude-defaults]: https://github.com/hlissner/dotfiles/blob/fa72377393680f953fcb9efaa30994ea91eba233/config/claude/managed-settings.d/10-defaults.json
[claude-managed]: https://code.claude.com/docs/en/managed-settings
[ryan-backup]: https://github.com/ryan4yin/nix-config/blob/9ba2cf52292c58e103e471defed6d3c1380c1df2/BACKUP.md
[mitchell-system]: https://github.com/mitchellh/nixos-config/blob/40d483d74cf48d64379fc9a857237ee18c519ff4/lib/mksystem.nix
[misterio-store]: https://github.com/Misterio77/Foundry/blob/d16c864b2618e1e89f93ce07cafa3ae5ba14cba9/hosts/nixos/common/optional/ssh-serve-store.nix
[mic92-workstation]: https://github.com/Mic92/dotfiles/blob/88ff5f7b12f122025c517fee553e9b9d4ee1adbf/nixosModules/workstation.nix
[journald-doc]: https://github.com/systemd/systemd/blob/main/man/journald.conf.xml
[srvos-nix]: https://github.com/nix-community/srvos/blob/cb9ecc7fbfdb9e71876b565c8b346db6ffa6d331/shared/common/nix.nix
[blueprint-lib]: https://github.com/numtide/blueprint/blob/8be75245e274a789b87cc4df542abbcd8c5e7f93/lib/default.nix
[mic92-gc]: https://github.com/Mic92/dotfiles/blob/88ff5f7b12f122025c517fee553e9b9d4ee1adbf/nixosModules/nix-daemon.nix
