# Muse Code

Nix installs `muse` from the pinned `llm-agents` input alongside the other agent
CLIs. Home Manager links `settings.json` to `~/.config/muse/settings.json` using
our existing out-of-store agent configuration pattern.

## First run

After activating the system configuration, run `muse` in a project. The wrapper
routes interactive, resume, headless (`exec`), and SDK (`serve`) sessions through
CLIProxyAPI: the loopback nginx gateway on Kim, the public endpoint on other
hosts. It reads the SOPS-managed public client token at runtime into
`META_API_KEY`; no Meta login is
needed for these proxied sessions. Missing or empty tokens fail closed.

The gateway forwards `/muse-code/models` to the live `/v1/models` registry with
the same authentication as inference. This avoids redirecting discovery to the
management HTML. The standard registry is not a complete native Muse picker
catalog, so the wrapper defaults `MUSE_MODEL` to `muse-wonder-1.0`. Pass `--model` to
select another proxy-supported Muse model. Inference uses `/v1/responses`;
`endpoint_transport.auth="bearer"` explicitly allows the proxy credential to be
sent to this non-Meta endpoint.

Deploy the gateway change on Kim before using the proxy wrapper remotely. Local
route simulation verified discovery proceeds to inference, but the live Meta
credential currently fails API-key minting with HTTP 403 (`no_payg`). Resolve
the Meta account/API billing setup before expecting successful inference.

Use `muse-direct` for normal Meta access (browser sign-in or your own runtime
`META_API_KEY`). Administrative commands and auxiliary services such as voice
are not routed by the wrapper; this is an inference adapter, not an all-traffic
proxy. Never put credentials in this repository or the Nix store.

## Integration

- Existing personal rules and skills discovery is enabled. Muse supports
  compatible Claude/Codex personal context and `~/.agents/skills`; project
  instructions load after workspace trust. Use `/rules` and `/skills` to inspect
  what your installed build actually discovers (upstream rollout gates can
  affect compatibility discovery).
- The existing Tailscale Executor endpoint is configured as an optional MCP
  server. Use `/mcp` to check connectivity. No additional public MCP servers or
  credentials are duplicated here.
- Telemetry is disabled. Approval and sandbox defaults are left intact; no
  workspace is automatically trusted.
- Proxy and direct sessions default to `muse-wonder-1.0`; use `MUSE_MODEL` or
  `--model` for another Muse model and `/effort` to change reasoning.

## Configuration compatibility

The pinned 1.4.6-R6000.1 binary requires `schema_version: 1` in user settings.
Its bundled migration guidance specifies `mcpServers` and server
`type: "streamable-http"`. The web documentation's `mcp_servers` / `transport`
examples describe a different shape; do not mix the two MCP keys.

`muse config validate --plane defaults` validates an enterprise defaults
**envelope**, not the flat user settings document. Smoke-test user settings in a
temporary HOME/XDG_CONFIG_HOME with `muse exec --provider echo --no-session-log`
in a disposable workspace. That checks startup without a paid model call; it
does not prove Meta authentication or live MCP tool execution.

References:
- https://dev.meta.ai/docs/muse-code/configuration
- https://dev.meta.ai/docs/muse-code/extending
- https://dev.meta.ai/docs/muse-code/auth
