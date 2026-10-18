# CLIProxyAPI

This folder owns the CLIProxyAPI gateway on Kim and the agent clients that use it.

- `config.nix` is the shared endpoint, authentication, model, and server configuration.
- `nixos.nix` runs the systemd server only on Kim and installs the public client token on every NixOS/WSL host.
- `darwin.nix` installs only the public client token; Joyce no longer runs a local proxy.
- `home-manager.nix` generates the Claude, Codex, Grok, Muse, and OpenCode client adapters, direct-access commands for clients other than OpenCode, and `cliproxyapi-util`. Its caller supplies the user's agent-config directory explicitly.

Kim's clients continue to use `127.0.0.1:8317` and read their local API token at runtime from `/run/secrets/cliproxyapi-local-api-key`. Other hosts use `https://cliproxy.maximilian.pw` and read the public API token from `/run/secrets/cliproxyapi-public-api-key`. Both credentials remain in SOPS-managed runtime files rather than generated Nix-store files. Home Manager also exports the endpoint and token-file variables consumed by Pi's CLIProxyAPI extension in the separate `pi-config` repository; that extension fails closed when explicit endpoint or credential configuration is absent rather than silently selecting localhost. The Darwin module removes the obsolete Joyce LaunchAgent left by configurations from before the proxy was centralized and publishes the non-secret endpoint and token-file path to the user launchd environment for GUI-owned agent sessions. The OpenCode base configuration lives at `users/maxpw/agents/opencode/cliproxyapi.json`; Home Manager injects the host-specific endpoint and an environment-variable token reference when it generates the deployed `opencode.json`.

The shared GPT default is `gpt-6-astra` for Codex and OpenCode, as well as
`codex-direct` and `pi-direct`. Older GPT variants remain selectable.

### OpenCode 2

The overlay selects `llm-agents.packages.<system>.opencode2` and adds an
`opencode` executable alias for existing wrappers and service PATHs. Upstream's
`opencode` package still selects v1. Updates are owned by the flake; in-app
update checks are disabled rather than installing a second unmanaged copy.

The base configuration uses native v2 `providers`, ordered `permissions`,
`mcp.servers`, and `plugins`. The transport remains
`aisdk:@ai-sdk/openai-compatible`; credentials are still read at runtime.
Shell permission rules keep the catch-all `ask` first, followed by the existing
specific allows/denies. LSP and automatic formatting remain opt-in per project.

OpenCode model inference is proxy-only: ordered `provider.use` policies deny
all providers, then allow `cliproxyapi`. This filters direct providers even when
credentials are saved locally; repository policy cannot relax the user-global
policy in v2.0.32. The former managed `opencode-direct` bypass is removed on
activation. Other clients' direct wrappers are unchanged. This is a model
provider restriction, not a network firewall: MCP, tools, and quota lookups are
separate from model inference.

Title generation explicitly selects
`cliproxyapi/zen/deepseek-v4.1-flash-free`. Other built-in helpers retain their
normal model inheritance, constrained by the same provider policy. OpenCode
may retry a failed title with the session's primary model; for a free DeepSeek
session that is the same free model, not a paid substitute. Saved sessions
using a now-blocked direct provider must select a `cliproxyapi/...` model.

Only `cc-safety-net` and `@slkiser/opencode-quota` remain in the configured
server plugin list. The installed notify, direnv, smart-title, and Antigravity
auth packages failed v2's plugin-definition contract. Notifications now use
native CLI attention settings; titles use OpenCode's built-in generation.
Antigravity authentication and plugin-based direnv injection are not provided
by this configuration. Use a verified v2 integration before relying on either;
shell-level direnv alone does not prove the shared server receives a project's
environment. Existing local plugins outside this list are not removed.

Terminal settings are **`cli.json` in v2.0.32**, not `tui.json(c)`. The source of
truth for our declared preferences is `users/maxpw/agents/opencode/cli.json`.
Home Manager activation merges those preferences into the writable
`~/.config/opencode/cli.json`, preserving theme/session settings and local
plugin entries (including Herdr). Notifications are enabled and sounds are
disabled. Existing local disable directives remain after the quota plugin's
default registration. Do not symlink this app-written file into the Nix store.
Close OpenCode before activation to avoid concurrent config writes. The merge
fails without changing malformed/JSONC files or replacing another manager's
symlink; convert such a file to a regular strict-JSON document first. Legacy
`tui.json(c)` files are not deleted or managed by this module.

Quota preferences live at
`~/.config/opencode/opencode-quota/quota-toast.json`, generated from the adjacent
`quota-toast.json` source. Their previous behavior is preserved (no popup
toasts, remaining quota, session token counts). No credential/account state is
managed by these files. A manually created `quota-toast.jsonc` may take priority;
resolve any such duplicate before expecting the managed JSON preferences.

`opencode-config-regression` checks the packaged v2 binary, model limits,
canonical config parsing, permission rules, the title-model override, rendered
Zen upstream aliases, and real provider-catalog filtering (including a project
attempt to re-enable direct providers). It also checks quota preferences and
non-destructive/idempotent CLI preference merging in an isolated home. It does
not verify third-party plugin execution, GUI notifications, or authenticated
inference.

Version-specific references:
[CLI settings](https://github.com/anomalyco/opencode/blob/843a6c514e606b436a7fe713422ace0a93ad3d61/services/www/src/docs/content/cli/config.mdx),
[CLI migration](https://github.com/anomalyco/opencode/blob/843a6c514e606b436a7fe713422ace0a93ad3d61/packages/cli/src/config/migrate.ts),
and [config schema](https://opencode.ai/config.json). The older `/docs` examples
can describe v1 names; do not use them to revert this v2 configuration.

### Muse Code

`muse` uses the proxy for interactive/resume, `exec`, and `serve` sessions;
`muse-direct` preserves native Meta access. The wrapper reads the public client
token at runtime, pins Bearer authentication for the custom endpoint, and
selects `muse-wonder-1.0` unless overridden with `MUSE_MODEL` or `--model`.
`muse-direct` defaults to the same model without proxy routing.

Muse first probes `/muse-code/models`. An exact authenticated nginx location
forwards that request to the live `/v1/models` registry instead of the management
redirect. It is a startup compatibility route, not a synthesized native Muse
model-picker catalog. Kim's Muse wrapper therefore uses the loopback **gateway**
port (with the public client token), unlike the other local clients that use the
raw backend. Remote Muse clients use the public gateway. Activate the Kim
gateway change before the client wrappers. See
[`Muse setup`](../../users/maxpw/agents/muse/README.md) for verification limitations.

## Public API on Kim

`homelab/cliproxyapi.nix` exposes `https://cliproxy.maximilian.pw/v1` through Kim's existing Cloudflare Tunnel. `lib/homelab-services.nix` declares the hostname and loopback gateway port, `19009`. The DNS record is a proxied CNAME to `5b712ae4-3ce4-4499-9cb7-a57cde1c571f.cfargotunnel.com`.

The nginx gateway requires the SOPS secret `cliproxyapi-public-api-key` as a Bearer token for `/v1/`. It replaces that token with the separate SOPS secret `cliproxyapi-local-api-key` when forwarding to CLIProxyAPI on `127.0.0.1:8317`. Kim remains local; Joyce and Cuno use the public endpoint. The public `/healthz` endpoint returns an empty `204` for Cloudflare Tunnel monitoring without loading the management UI; nginx answers it directly, so it proves only that the public ingress is up.

Backend readiness is a separate signal. `cliproxyapi-readiness-probe.timer` runs `scripts/homelab/cliproxyapi-readiness-probe.sh` every minute; the script requests `http://127.0.0.1:8317/v1/models` with the local API key loaded as a systemd credential (never a Nix store path or a process argument) and writes `cliproxyapi_backend_ready` to the node exporter textfile directory. The destination is fixed by the Nix wrapper and the unit is confined to loopback; the probe accepts no caller-supplied target, which is why the blackbox exporter's open `/probe` endpoint is not used for an authenticated check. The unit runs as root under its sandbox (empty capability bounding set, loopback-only address filter, read-only system with the textfile directory as the sole writable path); that is an accepted decision matching the sibling textfile collectors, which write to the same root-owned directory. `CLIProxyAPIBackendUnready` fires after five minutes of `cliproxyapi_backend_ready == 0`, and `CLIProxyAPIReadinessProbeStale` fires roughly six minutes after the textfile last refreshed (three missed runs cross its 180-second threshold, then the alert holds for three more minutes). Rotating `cliproxyapi-local-api-key` guarantees the next timer run uses the new credential; sops-nix's `try-restart` does not start the idle oneshot, so run `systemctl start cliproxyapi-readiness-probe.service` for an immediate re-probe. A transport failure such as a timeout or truncated response is reported as not ready even when a 200 status arrived. A ready result shows the CLIProxyAPI process is up, has loaded its SOPS-rendered API keys, and serves its model registry; it does not prove that any provider credential is valid or that inference requests succeed, because `/v1/models` never contacts a provider.

The root issues a relative redirect to `/management.html`. Nginx serves the custom UI from Fleet's pinned `cliproxy-ui` package (`share/cliproxy-ui/management.html`). The UI source, build provenance (`cliproxy-ui-<Fleet short rev>` on the System page), and upstream MIT license live in the Fleet repository under `apps/cliproxy-ui/`. To update it, publish a Fleet revision, bump the `fleet` input, and rebuild Kim; the previous generation keeps the previous UI for rollback. The backend and credentials remain on the existing CLIProxyAPI service. The UI and both `/v0/management/` and `/v8/management/` APIs use CLIProxyAPI's separate management key. Every management request requires that key, and five consecutive failures ban the client IP for about 30 minutes. The management key grants access to provider credentials, configuration, logs, and OAuth flows, so keep it in the password manager and do not reuse the public API key. Management responses and the UI are marked `Cache-Control: no-store`.

After activating the Kim configuration, verify that `/healthz` returns 204, `/` redirects to the UI, `/management.html` returns 200, and both `/v0/management/config` and `/v8/management/credentials` return 401 without the management key. Verify that `/v1/models` still returns 401 without the public token and 200 with it. API clients should use `https://cliproxy.maximilian.pw/v1` as their base URL. To load the public API key into a shell without printing it:

```sh
export CLIPROXYAPI_API_KEY="$(sops decrypt --extract '["cliproxyapi-public-api-key"]' secrets/secrets.yaml)"
curl --fail --silent --show-error https://cliproxy.maximilian.pw/v1/models \
  --config <(printf 'header = "Authorization: Bearer %s"\n' "$CLIPROXYAPI_API_KEY")
```

Keep replacement public keys URL-safe, using letters, digits, underscores, and hyphens. The nginx authentication map uses an anchored, case-sensitive regex. Rotate the encrypted secret and activate the configuration to restart nginx with the new token. Never put the plaintext token in Git or a Nix expression.

## Provider state

Provider OAuth credentials remain mutable state in `~/.cli-proxy-api` on Kim. The OpenCode Zen key comes from `secrets/secrets.yaml`, and its Chat Completions models are exposed under the `zen/` prefix. The Linux package definition remains in `packages/cliproxyapi.nix`.

The `cliproxyapi-quota` systemd service comes from Fleet's `nixosModules.cliproxy-quota` and runs the pinned `cliproxy-quota` package as the same user as CLIProxyAPI, with a read-only home. It binds only `127.0.0.1:8318`, reads Kim's current provider credentials from `~/.cli-proxy-api`, and returns only the parsed quota summary; the contract is documented in Fleet's `services/cliproxy-quota/README.md`. Nginx exposes `/quota/v1/{codex,claude,xai}` to clients using the existing public API key; it strips that key before forwarding and never gives clients the management key. `cliproxyapi-util quota` comes from the same package and reads `quotaUrl` from `~/.config/cliproxyapi/client.json`: the loopback endpoint on Kim, the public one elsewhere. The Pi extension still reads the local provider state directly on Kim and uses the public endpoint on other hosts; it moves to `quotaUrl` in a later pi-config change. The dashboard remains at `https://cliproxy.maximilian.pw/management.html#/login`; Pi does not use its privileged login.

### Free DeepSeek through the proxy

The Chat Completions upstream now uses
`https://opencode.ai/inference/openai/v1`. The exact upstream model
`deepseek-v4.1-flash-free` is exposed as `zen/deepseek-v4.1-flash-free` by
CLIProxyAPI and as `cliproxyapi/zen/deepseek-v4.1-flash-free` in OpenCode. The
catalog records 200,000 context tokens, 32,000 output tokens, text/image input,
and interleaved `reasoning_content`. The upstream alias retains the `-free`
suffix; no paid-model substitution is configured. The promotion is temporary,
so an expired key or retired free model should be investigated rather than
silently changing its alias to a paid model.

Credential and rollout steps (operator-owned):

1. Create a valid OpenCode Console API key. Edit `secrets/secrets.yaml` with
   `sops` and replace **`opencode-zen-api-key`**. Do not change the public/local
   CLIProxyAPI client tokens or put the Console key into a client JSON file.
2. Activate Kim's configuration first so the refreshed runtime secret and
   upstream/model list are available. This is a separate deployment action,
   not part of local config verification.
3. Activate the OpenCode client configuration on Joyce/other hosts, reopen
   OpenCode, and select `cliproxyapi/zen/deepseek-v4.1-flash-free` in `/models`.
4. Smoke-test a prompt, then streaming/tool use. Model discovery alone does not
   prove the upstream key is valid. Confirm the request remains on the exact
   free-model ID if investigating an error.

No new SOPS secret name, Go subscription, or CLIProxyAPI OAuth auth file is
needed. The expired direct OpenCode credential can remain locally stored but
is no longer a model route allowed by this config.

Sources: [OpenCode endpoints and free models](https://opencode.ai/docs/zen/)
and the `opencode/deepseek-v4.1-flash-free` entry in
[models.dev](https://models.dev/api.json).

### Quota service failure contract

`cliproxyapi-quota.service` runs Fleet's pinned `cliproxy-quota` package, so it no longer depends on a mutable checkout; Fleet owns the implementation and it must not be copied into nix-config. The unit restarts on transient failures but is start-limited to five attempts per 300 seconds, so a broken package or immediately failing start reaches the `failed` state after startup instead of restart-looping. The unit is listed in `lib/homelab-services.nix`, so `HomelabImportantUnitFailed` and `HomelabRepeatedServiceRestarts` alert on it. A server that stays running while serving incompatible responses is not detected by this mechanism; the HTTP contract is covered by Fleet's tests. Recover by fixing the cause (or rolling back the generation) and running `systemctl reset-failed cliproxyapi-quota.service` followed by `systemctl start cliproxyapi-quota.service`.

### Zen upstream protocol constraints

The configured Zen upstream is deliberately explicit, prefix-isolated, and
Chat-Completions-only: `modules/cliproxyapi/config.nix` renders one
`openai-compatibility` provider under `zen/`. CLIProxyAPI may translate several
downstream client protocols, but that does not expand the protocol used for the
upstream request.

The following are historical findings from research against CLIProxyAPI commit
[`4b5f1ea`](https://github.com/router-for-me/CLIProxyAPI/commit/4b5f1eab25fca4b3815369a826e958e7c070a69e)
on 2026-08-27, not verified claims about current upstream behavior:

- Responses integration was deferred and never validated end to end with a live
  Zen key.
- Anthropic Messages used an authentication-header rule that selected
  `Authorization: Bearer` for a non-Anthropic base URL, while Zen expected
  `x-api-key` at the researched revision.
- Gemini URL construction inserted a fixed `v1beta` segment, which could not
  address Zen's researched `/zen/v1/models/...` path.

Revalidate these constraints before enabling another protocol family. The
minimal primary sources are the upstream
[`config.example.yaml`](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/config.example.yaml),
[Claude request authentication](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/runtime/executor/claude_executor_request.go#L701-L712),
[Gemini URL construction](https://github.com/router-for-me/CLIProxyAPI/blob/4b5f1eab25fca4b3815369a826e958e7c070a69e/internal/runtime/executor/gemini_executor.go#L176),
and [OpenCode Zen protocol documentation](https://opencode.ai/docs/zen).

Billable provider credentials are runtime SOPS material. They must be rendered
from encrypted secrets at runtime and must never be stored as Nix literals or
written to the Nix store.

Pi's dynamic model discovery and quota client are implemented in the separate `~/pi-config` repository and linked into `~/.pi/agent` by `users/maxpw/modules/agent-tools.nix`. The installed `cliproxyapi-util quota --json` command comes from Fleet's `cliproxy-quota` package, reads the quota HTTP endpoint at `quotaUrl`, and reports deterministic availability for Codex, Claude, and Grok.
