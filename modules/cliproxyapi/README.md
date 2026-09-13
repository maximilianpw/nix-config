# CLIProxyAPI

This folder owns the local CLIProxyAPI gateway and the agent clients that use it.

- `config.nix` is the shared endpoint, authentication, model, and server configuration.
- `nixos.nix` installs the Linux package and runs the systemd service on NixOS and WSL.
- `darwin.nix` installs the Homebrew formula and runs the nix-darwin LaunchAgent.
- `home-manager.nix` generates the Claude, Codex, Grok, and OpenCode client adapters, their direct-access commands, and `cliproxyapi-util`. Its caller supplies the user's agent-config directory explicitly.

Both server adapters render `/run/secrets/rendered/cliproxyapi.conf` through the shared `config.nix` function. They differ only in platform paths, package ownership, process management, and logging. The OpenCode base configuration lives at `users/maxpw/agents/opencode/cliproxyapi.json`; Home Manager injects the shared endpoint and credentials when it generates the deployed `opencode.json`.

## Public API on Kim

`homelab/cliproxyapi.nix` exposes `https://cliproxy.maximilian.pw/v1` through Kim's existing Cloudflare Tunnel. `lib/homelab-services.nix` declares the hostname and loopback gateway port, `19009`. The DNS record is a proxied CNAME to `5b712ae4-3ce4-4499-9cb7-a57cde1c571f.cfargotunnel.com`.

The nginx gateway requires the SOPS secret `cliproxyapi-public-api-key` as a Bearer token. It replaces that token with the local API key when forwarding to CLIProxyAPI on `127.0.0.1:8317`. The committed local key cannot authenticate public requests. Local clients remain unchanged.

Only `/v1/` routes are forwarded. Management, OAuth callback, and UI routes return 404. This gateway restriction is necessary because the tunnel connects over loopback, so `remote-management.allow-remote: false` alone does not keep management private behind a tunnel. Streaming responses are unbuffered. Cloudflare's own request limits still apply.

After activating the Kim configuration, verify that `/v1/models` returns 401 without a token, 200 with the public token, and `/v0/management/config` returns 404 even with the token. API clients should use `https://cliproxy.maximilian.pw/v1` as their base URL. To load the key into a shell without printing it:

```sh
export CLIPROXYAPI_API_KEY="$(sops decrypt --extract '["cliproxyapi-public-api-key"]' secrets/secrets.yaml)"
curl --fail --silent --show-error https://cliproxy.maximilian.pw/v1/models \
  --config <(printf 'header = "Authorization: Bearer %s"\n' "$CLIPROXYAPI_API_KEY")
```

Keep replacement public keys URL-safe, using letters, digits, underscores, and hyphens. The nginx authentication map uses an anchored, case-sensitive regex. Rotate the encrypted secret and activate the configuration to restart nginx with the new token. Never put the plaintext token in Git or a Nix expression.

## Provider state

Provider OAuth credentials remain mutable state in `~/.cli-proxy-api`. The OpenCode Zen key comes from `secrets/secrets.yaml`, and its Chat Completions models are exposed under the `zen/` prefix. The Linux package definition remains in `packages/cliproxyapi.nix`.

Pi's dynamic model discovery and quota client are implemented in the separate `~/pi-config` repository and linked into `~/.pi/agent` by `users/maxpw/modules/agent-tools.nix`. The installed `cliproxyapi-util quota --json` command runs that shared client and reports deterministic availability for Codex, Claude, and Grok.
