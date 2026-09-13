# Fleet improvement plans

Prepared against `fbd4b40` on 2026-09-12. The user chose to prove the personal Kim/MacBook workflow using a disposable web app before designing a standalone repository.

## Execution order and status

| Plan | Title | Priority | Effort | Depends on | Status |
| --- | --- | --- | --- | --- | --- |
| [001](001-prove-fleet-personal-workflow.md) | Prove Kim compute with a MacBook interface | P1 | M | Passing tunnel regression; explicit live-test authorization | DONE: live 5173 fixture passed, including sleep/wake |
| [002](002-extract-fleet-rust.md) | Extract Fleet into a standalone Rust package | P1 | L | 001 and its uncommitted regression repair | DONE: published, pinned, and activated on Kim; Joyce launchd acceptance remains pending |

Read the plan completely before execution. Selecting a plan did not authorize configuration activation, remote session creation, or network interruptions. See [Plan 002 results](002-fleet-rust-results.md) for the published commit, verification evidence, Kim activation, and remaining Joyce acceptance gates.

## Dependency notes

The user separately authorized the regression repair. Generated mocks referenced `/usr/bin/env`, absent in the Nix sandbox. The test now uses its absolute Bash interpreter path and avoids unavailable `compgen` cleanup checks. Both scoped Nix regressions pass. See [the evidence report](001-fleet-personal-workflow-results.md).

Joyce has been rebuilt and the user authorized the live window. The disposable fixture used managed port 5173. All five required cases passed: remote edit/browser, detach/reattach, Joyce-only network recovery, 1Password reconnect, and MacBook sleep/wake. Sleep/wake was re-run on a second fixture after the first had already been cleaned up. Task-owned sessions, fixtures, and scratch directories were removed.

## Findings considered and deferred

- The completed pilot justifies standalone Rust extraction in [002](002-extract-fleet-rust.md), with a required [verification matrix](002-fleet-rust-verification.md). Preserve the working Bash implementation until candidate parity is established.
- Workspace commands follow extraction. Herdr orchestration, automatic dev-server startup, and dynamic port management are not included in 002.
- Custom terminal multiplexer or SSH transport: not recommended; existing Herdr/tmux and OpenSSH cover these responsibilities.
- Automatic file synchronization or workload migration: outside the chosen model, where work remains on Kim.
- Framework HMR, real-project authentication, a simultaneous second interface client, and host reboot recovery: not established by this disposable first pilot.
- launchd-only supervision and IPv4 loopback binding: intentional current scope, not defects by themselves.

## Related findings not covered by this plan

- Managed forwards still receive PID-delete suggestions from `fleet forward list`.
- The README describes generated Herdr profiles that the referenced module does not generate.

These remain follow-ups; this acceptance plan does not authorize source changes to resolve them.
