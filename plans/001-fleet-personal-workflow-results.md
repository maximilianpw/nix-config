# Fleet personal workflow evidence

## Verdict

Usable now. Joyce can keep a development process on Kim, edit it through a native Herdr session, and browse it at `http://localhost:5173` across client detach, a Joyce-only network drop, 1Password reconnect, and MacBook sleep/wake. Port 3000 remains occupied by unrelated local/remote work and is outside this pilot.

## Scope and source

The user authorized diagnosis and repair of the failing Fleet tunnel regression, with an explicit stop before activation or live testing. Work ran on Kim in an SSH session originating on Joyce.

Tested source: `fbd4b40` plus the working-tree changes in `scripts/tests/fleet-tunnel-regression-test.sh`. HEAD had no drift from the plan's source revision in the listed Fleet paths. Production Fleet code, tunnel mappings, and LaunchAgent options are unchanged. The `plans/` directory was already untracked when work began. No commit or push was made.

## Diagnosis and repair

The original command failed repeatedly:

```sh
nix build .#checks.x86_64-linux.fleet-tunnel-regression --no-link
```

```text
expected one job snapshot for port 3000, got 0
```

The same mocked suite passed outside the Nix sandbox. Adding a direct launchctl mock preflight before Fleet's status checks exposed the sandbox failure:

```text
/build/bin/launchctl: /usr/bin/env: bad interpreter: No such file or directory
expected success: launchctl print-disabled gui/1000
```

The generated launchctl, TCP probe, and ps mocks used `#!/usr/bin/env bash`. The sandbox lacks `/usr/bin/env`, so launchctl never wrote a snapshot to the mock command log. Fleet suppressed the probe's stderr, leaving the indirect snapshot assertion as the visible failure.

The test now generates all three mock shebangs from `$BASH`, the current interpreter's absolute path. The direct launchctl preflight remains to expose future mock execution failures. Existing snapshot assertions remain unchanged.

The first passing build also reported `compgen: command not found` in two cleanup assertions. Nix's build Bash lacks that builtin, which caused those assertions to skip checking for leftovers. Ordinary glob loops now check for leftover files and symlinks without `compgen`.

## Verification on Kim

Passed after the fix:

```sh
nix build .#checks.x86_64-linux.fleet-tunnel-regression .#checks.x86_64-linux.fleet-ssh-regression --no-link
bash -n scripts/tests/fleet-tunnel-regression-test.sh
shellcheck scripts/tests/fleet-tunnel-regression-test.sh
make check-scripts
git diff --check
```

Final tunnel regression derivation:

```text
/nix/store/r79al12qr5l2vj04cmf5g4lhnh8h134k-fleet-tunnel-regression.drv
```

`make check-scripts` skips standalone Fleet regressions because their generated packages come from Nix. The explicit Nix builds above ran those regressions. All SSH, launchctl, listener, and process probes in the tunnel suite use disposable test fixtures, not live services.

These results establish mocked behavior only. They do not prove installed configuration, real launchd recovery, or browser connectivity. No activation is needed for this test-only repair.

## Installed setup and live cases

After the user rebuilt Joyce, a read-only inspection from its logged-in GUI session confirmed:

- Joyce's installed Fleet now exposes `tunnel` and `doctor`, detects Joyce as the current host, and declares the expected Kim mappings for ports 3000 and 5173.
- Both Home Manager LaunchAgents are installed, enabled, and running. Neither has exited since the rebuild.
- Joyce port 5173 is owned by the intended managed SSH child. Kim port 5173 has no listener, so it is available for the disposable fixture.
- Port 3000 is not available for an unambiguous acceptance test. Joyce has an existing Rivierabox Vite process listening on `[::1]:3000`, while the managed tunnel owns `127.0.0.1:3000`. Kim's `127.0.0.1:3000` belongs to the shared `gotenberg.service`.
- `fleet doctor kim` reported port 3000 as `supervisor=running local=unrelated remote=listening` and port 5173 as `supervisor=running local=owned remote=down`. Exit 1 is expected before the fixture because port 5173 has no remote app and port 3000 has the known local collision.
- Joyce has Herdr 0.9.0 with compatible local client/server protocols. Its existing enabled Kim profile targets the remote `default` session, and an existing remote-client bridge was observed without attaching to or replacing either server.

The user approved amending the fixture from port 3000 to port 5173. No existing Rivierabox, Gotenberg, SSH, launchd, or Herdr process was stopped or changed.

| Required case | Result | Evidence |
| --- | --- | --- |
| Remote edit and Joyce browser flow | PASS | Joyce Herdr client edited `message.txt`; Joyce curl and the human browser both showed Kim, fixture `fleet-3fa0142e`, PID `603403`, start `2026-09-12T21:11:37.562Z`, message `joyce-herdr-edit-fleet-3fa0142e`. Doctor: `tunnel 5173: supervisor=running local=owned remote=listening`. |
| Terminal detach and reattach | PASS | Nested Joyce client detached at `21:20:59Z` via Herdr `prefix+d`. Browser stayed connected; Joyce curl kept the same PID. Reattach at `21:25:55Z` restored session `fleet-pilot-230924` and cwd `/tmp/fleet-personal-workflow.VkG4S8`. |
| MacBook sleep/wake | PASS | First fixture was already cleaned up, so this case was re-run. Fixture `fleet-dd5fe28e`, PID `647965`, start `2026-09-12T21:41:18.245Z` was ready at `21:41:26Z`. After sleep/wake, human browser and Joyce curl at `21:43:49Z` showed the same identity. The Joyce Herdr client remained attached to session `fleet-sleep-234058`; tunnels were not recreated. Earlier Mac lock/unlock is not this case. |
| Joyce network recovery | PASS | User dropped and restored only Joyce's network. After recovery (`21:30:12Z`) Joyce curl still returned the original fixture identity; tunnel 5173 remained `running`/`owned`. |
| Credential lock/reconnect recovery | PASS | 1Password lock did not drop the already-authenticated 5173 tunnel, as the plan warned. Detach plus a new test-client reconnect started at `21:31:42Z`. The user unlocked during reconnect; by `21:32:57Z` the client was attached again with the same Kim PID. A distinct blocked auth prompt was not captured. |

## Live fixture identity

- Fixture ID: `fleet-3fa0142e`
- Host: `kim`
- PID: `603403` (unchanged through every completed case)
- Started: `2026-09-12T21:11:37.562Z`
- Bind: Kim `127.0.0.1:5173`, Joyce browser `http://localhost:5173`
- Scratch: `/tmp/fleet-personal-workflow.VkG4S8`
- Kim Herdr session: `fleet-pilot-230924`
- Panes: `w2:p1` (bun server), `w2:p2` (edit shell)
- Joyce test client pane: `w3C:p5` (nested `herdr --remote kim --session fleet-pilot-230924`)
- Initial tunnel state: both LaunchAgents running, neither paused; 5173 owned, 3000 locally unrelated because of Rivierabox on `[::1]:3000`

Nested Herdr attach required a temporary `HERDR_CONFIG_PATH` with `allow_nested = true`. Joyce's real `~/.config/herdr/config.toml` was not modified.

## Cleanup

- Fixture process `603403` stopped through pane `w2:p1`; Kim port 5173 has no listener.
- Session `fleet-pilot-230924` stopped and deleted. Kim's default Herdr session was left running.
- Scratch directory removed after confirming it contained only `server.js` and `message.txt`.
- Temporary Joyce machine profile `fleet-pilot-230924` removed. The preexisting Kim `default` profile remains.
- Joyce split pane `w3C:p5` closed.
- `fleet tunnel status` after cleanup still shows 3000 `running`/`unrelated` and 5173 `running`/`owned`. Mapping pause state was not changed.

## Sleep/wake fixture

- Fixture ID: `fleet-dd5fe28e`
- Host: `kim`
- PID: `647965`
- Started: `2026-09-12T21:41:18.245Z`
- Scratch: `/tmp/fleet-sleep-wake.BELzIJ`
- Kim Herdr session: `fleet-sleep-234058`, pane `w2:p1`
- Joyce client pane: `w3C:p6`
- Ready: `2026-09-12T21:41:26Z`; verified after wake: `2026-09-12T21:43:49Z`

Cleanup of this second fixture: process stopped, session stopped and deleted, scratch removed, temporary machine profile removed, Joyce pane `w3C:p6` closed. Default Kim Herdr session and both managed tunnels were left unchanged.

## Remaining gaps

Framework HMR/WebSockets, real-project authentication callbacks, a simultaneous second interface client, host reboot recovery, and portability remain unverified. Host-wide `fleet doctor kim` still exits 1 because of the known port 3000 collision; that is outside this fixture.
