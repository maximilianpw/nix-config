# CLIProxyAPI

This folder owns the CLIProxyAPI gateway on Kim and the agent clients that use it.

- `config.nix` is the shared endpoint, authentication, model, and server configuration.
- `nixos.nix` runs the systemd server only on Kim and installs the public client token on every NixOS/WSL host.
- `darwin.nix` installs only the public client token; Joyce no longer runs a local proxy.
- `home-manager.nix` generates the Claude, Codex, Grok, and OpenCode client adapters, their direct-access commands, and `cliproxyapi-util`. Its caller supplies the user's agent-config directory explicitly.

Kim's clients continue to use `127.0.0.1:8317` and read their local API token at runtime from `/run/secrets/cliproxyapi-local-api-key`. Other hosts use `https://cliproxy.maximilian.pw` and read the public API token from `/run/secrets/cliproxyapi-public-api-key`. Both credentials remain in SOPS-managed runtime files rather than generated Nix-store files. Home Manager also exports the endpoint and token-file variables consumed by Pi's CLIProxyAPI extension in the separate `pi-config` repository. The OpenCode base configuration lives at `users/maxpw/agents/opencode/cliproxyapi.json`; Home Manager injects the host-specific endpoint and an environment-variable token reference when it generates the deployed `opencode.json`.

## Public API on Kim

`homelab/cliproxyapi.nix` exposes `https://cliproxy.maximilian.pw/v1` through Kim's existing Cloudflare Tunnel. `lib/homelab-services.nix` declares the hostname and loopback gateway port, `19009`. The DNS record is a proxied CNAME to `5b712ae4-3ce4-4499-9cb7-a57cde1c571f.cfargotunnel.com`.

The nginx gateway requires the SOPS secret `cliproxyapi-public-api-key` as a Bearer token for `/v1/`. It replaces that token with the separate SOPS secret `cliproxyapi-local-api-key` when forwarding to CLIProxyAPI on `127.0.0.1:8317`. Kim remains local; Joyce and Cuno use the public endpoint. The public `/healthz` endpoint returns an empty `204` for Cloudflare Tunnel monitoring without loading the management UI.

The root issues a relative redirect to `/management.html`. The UI and `/v0/management/` API use CLIProxyAPI's separate management key. Every management request requires that key, and five consecutive failures ban the client IP for about 30 minutes. The management key grants access to provider credentials, configuration, logs, and OAuth flows, so keep it in the password manager and do not reuse the public API key. Management responses and the UI are marked `Cache-Control: no-store`.

After activating the Kim configuration, verify that `/healthz` returns 204, `/` redirects to the UI, `/management.html` returns 200, and `/v0/management/config` returns 401 without the management key. Verify that `/v1/models` still returns 401 without the public token and 200 with it. API clients should use `https://cliproxy.maximilian.pw/v1` as their base URL. To load the public API key into a shell without printing it:

```sh
export CLIPROXYAPI_API_KEY="$(sops decrypt --extract '["cliproxyapi-public-api-key"]' secrets/secrets.yaml)"
curl --fail --silent --show-error https://cliproxy.maximilian.pw/v1/models \
  --config <(printf 'header = "Authorization: Bearer %s"\n' "$CLIPROXYAPI_API_KEY")
```

Keep replacement public keys URL-safe, using letters, digits, underscores, and hyphens. The nginx authentication map uses an anchored, case-sensitive regex. Rotate the encrypted secret and activate the configuration to restart nginx with the new token. Never put the plaintext token in Git or a Nix expression.

## Provider state

Provider OAuth credentials remain mutable state in `~/.cli-proxy-api`. The OpenCode Zen key comes from `secrets/secrets.yaml`, and its Chat Completions models are exposed under the `zen/` prefix. The Linux package definition remains in `packages/cliproxyapi.nix`.

Pi's dynamic model discovery and quota client are implemented in the separate `~/pi-config` repository and linked into `~/.pi/agent` by `users/maxpw/modules/agent-tools.nix`. The installed `cliproxyapi-util quota --json` command runs that shared client and reports deterministic availability for Codex, Claude, and Grok.
