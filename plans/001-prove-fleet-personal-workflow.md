# Plan 001: Prove Kim compute with a MacBook interface

## Status

- Priority: P1
- Effort: M, including a human-assisted MacBook session
- Risk: MED, because sleep and network tests interrupt the test client's connections
- Category: direction
- Planned at: `fbd4b40`, 2026-09-12
- Status: DONE. All five required live cases passed on the port 5173 fixture, including a second-run sleep/wake against `fleet-dd5fe28e`. See `001-fleet-personal-workflow-results.md`.
- Depends on: no other plan; the existing tunnel regression must pass before live testing

## Goal and settled scope

The user selected a disposable web app, not an existing project. Prove that source files, development processes, and a persistent terminal remain on Kim while Joyce, the MacBook, supplies terminal input and a local browser. Verify browser live updates, terminal detach/reattach, MacBook sleep/wake, network recovery, and authentication recovery.

This is a plan, not permission to activate configuration, create remote sessions, interrupt networking, or stop existing processes. Ask for authorization before the live phase. Do not extract Fleet or add features as part of this test.

Prefer a dedicated native remote Herdr session for the pilot. Verify its installed syntax and compatibility first. If Herdr setup requires installing or replacing a remote server, stop for approval. Do not silently replace the pilot with tmux: offer a separate tmux baseline and record that Herdr remains unverified.

## Read first and check drift

From the nix-config checkout:

```sh
git diff --stat fbd4b40..HEAD -- scripts/fleet.sh scripts/fleet-tunnels.sh scripts/fleet-tunnel-runner.sh lib/fleet.nix modules/fleet tests/fleet-tunnel-regression.nix scripts/tests/fleet-tunnel-regression-test.sh users/maxpw/modules/agent-tools.nix
```

Read changed files and reconcile this plan before proceeding. Do not assume pulled source is the installed configuration.

Read `modules/fleet/README.md`, `modules/fleet/home-manager.nix`, `lib/fleet.nix`, and the generated `~/.config/fleet/FLEET.md` on each participating host. Use the remote-development and Herdr skills if available. Herdr control requires the skill's caller-context safeguards; never target a user's focused pane implicitly.

## Current state

- `scripts/fleet.sh` dispatches SSH/tmux, ad-hoc forwarding, managed tunnel commands, and doctor.
- `scripts/fleet-tunnels.sh` implements launchd status, pause/resume, listener ownership, and remote TCP diagnostics.
- `scripts/fleet-tunnel-runner.sh` owns one SSH child and a startup deadline. launchd owns retries.
- `modules/fleet/home-manager.nix` installs `fleet.launchdAgents` on Darwin.
- `modules/fleet/default-tunnels.nix` declares Joyce's mappings:

```nix
joyce = [
  { host = "kim"; localPort = 3000; remotePort = 3000; }
  { host = "kim"; localPort = 5173; remotePort = 5173; }
];
```

- `lib/fleet.nix` supplies these LaunchAgent settings:

```nix
RunAtLoad = true;
KeepAlive = true;
ThrottleInterval = 30;
```

- Local binding is IPv4 loopback. The acceptance fixture uses port 5173: open `http://localhost:5173` in the browser and use `127.0.0.1:5173` for deterministic IPv4 curl checks.
- Port 3000 is excluded from this pilot: Joyce has a local Rivierabox Vite listener on `[::1]:3000`, while Kim's `127.0.0.1:3000` belongs to `gotenberg.service`.
- Reconnection still depends on the MacBook's 1Password SSH agent. BatchMode does not bypass lock or approval requirements.
- Kim is declared suitable for long-running agents. Joyce is the interface host.
- Herdr 0.9.0 is installed on both hosts. Joyce's local client/server protocols are compatible, and its existing enabled Kim profile targets the remote `default` session.
- The Fleet README claims a generated Herdr machine catalog, but the referenced agent-tools module does not generate it. Discover actual profiles rather than relying on that claim.
- Bun, Node, Python, and curl were found on Kim during planning. Recheck availability before creating the fixture.

### Verification already performed

Passed:

```sh
nix build .#checks.x86_64-linux.fleet-ssh-regression --no-link
bash -n scripts/fleet.sh scripts/fleet-tunnels.sh scripts/fleet-tunnel-runner.sh scripts/tests/fleet-tunnel-regression-test.sh
shellcheck scripts/fleet.sh scripts/fleet-tunnels.sh scripts/fleet-tunnel-runner.sh scripts/tests/fleet-tunnel-regression-test.sh
git diff --check
```

Failed twice:

```sh
nix build .#checks.x86_64-linux.fleet-tunnel-regression --no-link
```

Observed output:

```text
expected one job snapshot for port 3000, got 0
```

The separately authorized regression fix established that generated test mocks used `/usr/bin/env`, which is absent in the Nix sandbox. The mocks now use the test's absolute Bash interpreter path, and a direct mock preflight exposes execution failures. Cleanup assertions also no longer depend on the unavailable `compgen` builtin. Both scoped checks pass on `fbd4b40` plus the working-tree test fix. Production Fleet code is unchanged. See `001-fleet-personal-workflow-results.md` for evidence. This does not establish live launchd behavior.

## Scope and ownership

Tracked files permitted for this acceptance task:

- `plans/001-prove-fleet-personal-workflow.md`: status and reconciled plan details only.
- `plans/001-fleet-personal-workflow-results.md`: create the evidence report.
- `plans/README.md`: update status.

After explicit approval, create one disposable scratch directory on Kim with `mktemp -d`, one dedicated persistent terminal session, and only the processes needed for the fixture. Record their exact paths and opaque session/pane IDs in the results file. Do not write credentials or complete environment dumps into it.

Out of scope:

- Further source fixes. The user separately authorized diagnosis and repair of the tunnel regression; that test-only repair is complete. This acceptance plan does not authorize unrelated fixes.
- Changes to host inventory, SSH trust, identity agents, Tailscale policy, or installed services.
- Configuration activation without separate approval.
- Existing repositories, agent sessions, development processes, or occupied ports.
- Public exposure, file synchronization, workload migration, or a new Fleet daemon.
- Committing, pushing, publishing, or deploying.

## Step 1: Clear the verification prerequisite

Rerun the two scoped Nix checks above. Expected: both exit 0. If the tunnel check still fails, record BLOCKED with its log and stop before live testing. Do not repair it opportunistically within this acceptance task.

After the prerequisite passes, record the passing revision and any changes since this plan. Verify that the intended production behavior still matches the excerpts above.

## Step 2: Authorize and inspect the installed setup

Resume this step from a local Joyce terminal in the logged-in macOS GUI session, not from the current Kim SSH shell. Joyce's Fleet contract, launchd jobs, local ports, browser, and credential provider must be checked there. Kim-side fixture work remains on Kim. No activation or live acceptance work was performed during the regression fix.

Ask the user to approve a disposable Kim fixture and a human-assisted Joyce test window. Name the planned disruptions: closing only the test client, sleeping the MacBook, a brief MacBook network interruption, and locking/unlocking its SSH credential provider. Do not interrupt Kim networking or stop any shared service.

On each host, record:

```sh
fleet list
fleet --help
herdr --version
herdr --help
```

On Joyce, inspect:

```sh
fleet tunnel status
launchctl print gui/$(id -u)/org.nix-community.home.fleet-tunnel-3000
launchctl print gui/$(id -u)/org.nix-community.home.fleet-tunnel-5173
```

Expected: installed Fleet exposes `tunnel` and `doctor`; mappings match the intended Kim targets. Record each mapping's initial paused/enabled state. Never resume a deliberately paused mapping without approval.

If the configuration is not installed, stop and request a separate activation decision. Do not perform a rebuild merely to continue this plan.

Read-only inspection after Joyce's rebuild confirmed that both LaunchAgents are installed and running. Port 5173 is owned by the intended SSH child on Joyce and is free on Kim. Port 3000 cannot be used safely: Joyce has an unrelated Rivierabox Vite listener on IPv6 loopback, and Kim port 3000 belongs to the shared `gotenberg.service`. The user approved amending the acceptance target to port 5173 rather than stopping either process or changing tunnel configuration.

Before starting the fixture, re-inspect port 5173 on Kim and Joyce. Expected: Kim's port is free and Joyce's IPv4 port is owned by the intended managed tunnel. If that changes or unrelated work appears, stop rather than kill it or silently choose another target.

## Step 3: Create a minimal observable fixture

After approval, use a fresh Kim scratch directory. Generate a random, non-secret fixture ID. Use Bun's built-in HTTP server with no dependency installation, binding only `127.0.0.1:5173`.

The executor should create a small JavaScript fixture containing:

- `/`: an HTML page displaying the fixture ID, hostname, process ID, process start timestamp, and an editable message.
- `/api/status`: JSON with the same fields, including a message read from `message.txt` on every request.
- Browser code that fetches `/api/status` once per second and displays either the current values or a visible disconnected state.
- A stable process start timestamp captured once at startup.
- A startup line containing only the fixture ID and URL.

Use a dedicated Herdr session and pane, discovered and created through the installed CLI's documented syntax. Start the fixture there with its working directory set explicitly. Record exact session/pane IDs and fixture PID.

Verify on Kim:

```sh
curl --fail --silent http://127.0.0.1:5173/api/status
```

Expected: valid JSON identifying this fixture and Kim. Save the fixture ID, PID, and start timestamp as the baseline. Do not add startup hooks or background daemons.

This dependency-free live-update fixture tests browser continuity and remote edits. It does not prove Vite/Next.js HMR or WebSocket behavior. Those remain an explicit follow-up, not an implied pass.

## Step 4: Prove terminal input and browser traffic reach Kim

From Joyce, attach to the dedicated remote Herdr session without creating or replacing other sessions. Confirm its working directory is the Kim scratch directory. Edit `message.txt` from that remote terminal to contain a new non-secret marker.

Verify on Joyce:

```sh
curl --fail --silent http://127.0.0.1:5173/api/status
```

Expected: the baseline fixture ID, PID, and start timestamp, plus the new marker.

Open `http://localhost:5173` in Joyce's browser. Expected: the page shows Kim and the new marker without starting any local dev server. A screenshot or human-recorded observation is required; curl alone does not prove browser behavior.

Run `fleet doctor kim` on Joyce and record mapping-level output. Port 5173 should show `supervisor=running local=owned remote=listening`. Port 3000 is outside this fixture: the known Joyce IPv6 Vite listener makes Fleet classify it as locally unrelated, while the managed IPv4 tunnel reaches Kim's Gotenberg service. A host-wide doctor exit 1 is therefore expected unless that unrelated local process has ended naturally. Do not stop Rivierabox, Gotenberg, or either managed tunnel merely to make doctor green.

## Step 5: Prove persistence and recovery

For each scenario below, record start time, recovery time, manual intervention, browser state, terminal reattachment, and the result of the same Joyce curl command. After recovery, require the baseline fixture ID, PID, and start timestamp to be unchanged.

1. **Terminal detach:** close or detach only the disposable MacBook client attachment. The browser must continue working while the terminal is detached. Reattach to the same remote session and verify its working directory and process.
2. **MacBook sleep/wake:** the human sleeps the MacBook, then wakes it. Do not claim network continuity during sleep. Require eventual terminal and browser recovery without restarting the Kim fixture or manually recreating tunnels.
3. **Network interruption:** the human briefly disconnects only Joyce's network, then reconnects. Cached terminal state must not be reported as live. Require eventual recovery with the same Kim process.
4. **Credential lock:** the human locks the SSH credential provider, then causes an approved test-client reconnect. Existing authenticated tunnels may remain healthy, so lock alone does not prove reauthentication. Do not kill unrelated SSH processes to force this. Record a clearly blocked/unknown state if reconnect needs approval. After the human unlocks and approves authentication, require recovery without recreating remote work.

Use a five-minute observation budget per recovery case. This is an acceptance target, not a claim about an existing guarantee. If recovery exceeds it, record FAIL and diagnostics rather than restarting services to hide the failure. Record the measured time even on success.

No automated tool may approve a credential prompt for the user.

## Step 6: Clean up only task-owned resources

Stop the fixture through its exact recorded pane or verified process identity. Close only the test session if it was created exclusively for this task. Never run a global Herdr server stop or broad process-name kill.

Remove only the scratch directory created by this task, after confirming its recorded path and contents. Restore any explicitly approved mapping-state changes to their recorded baseline. Do not pause the user's normally enabled tunnels merely because the fixture is done.

Verify: fixture process no longer exists, scratch directory is absent, and `fleet tunnel status` matches the initial intended enabled/paused state. A remaining tunnel listener with no remote app is normal.

## Results and done criteria

Create `plans/001-fleet-personal-workflow-results.md` with:

- Tested source revision and installed versions on both machines.
- Authorization scope, fixture identity, and initial tunnel states.
- PASS, FAIL, or BLOCKED for each of the five behavior cases: initial remote edit/browser flow, terminal detach, sleep/wake, network recovery, credential recovery.
- Measured recovery times and every required manual intervention.
- Cleanup results.
- Explicit unverified items: framework HMR/WebSockets, real-project auth callbacks, simultaneous second interface client, host reboot recovery, and portability to other users.
- A verdict: usable now, usable with named manual steps, or blocked by named failures.

Acceptance is complete only if all required cases pass and cleanup succeeds. A partial run must remain BLOCKED or IN PROGRESS; do not convert untested behavior into PASS.

Verify tracked changes with:

```sh
git diff --check
git status --short
```

Expected: no whitespace errors; only the three permitted plan/report paths changed by this task. Update `plans/README.md` and this plan's status. Do not commit or push without instruction.

## STOP conditions

Stop and report if a prerequisite check fails, installed behavior differs from the plan, a port belongs to unrelated work, Herdr proposes replacing a server, a host-key prompt appears, activation is required, or recovery needs changing shared infrastructure. Ask rather than bypassing credential policy.

## Follow-up decision

Use the results to decide what Fleet should own next. If terminal persistence and managed tunnels pass but choosing directories, sessions, and ports remains manual, a named workspace command is justified. If sleep or credential recovery fails, fix that before extracting or expanding Fleet. Keep the test results separate from claims about general reliability.
