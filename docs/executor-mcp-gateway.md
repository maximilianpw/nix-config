# Executor MCP gateway

Executor is the only gateway for remote MCP servers and remote API
integrations used by local coding agents.

- Console: `https://executor.liger-shilling.ts.net`
- MCP endpoint: `https://executor.liger-shilling.ts.net/mcp`
- Host: Kim

## Boundary

Add remote integrations, accounts, credentials, and execution policies in
Executor. Agent clients connect to Executor rather than to each upstream
service.

Keep capabilities local when their security or runtime boundary is inherently
device-local. Examples include 1Password, computer-use/browser control, Node
REPLs, local repository tools, and hardened URL fetching performed by the
client.

Credentials belong in Executor's encrypted browser handoff. Repository files,
chat messages, and command arguments contain no credential values.

## Add or migrate an integration

1. Add the MCP, OpenAPI, or GraphQL source in the Executor console.
2. Create a user-owned account through Executor's browser handoff.
3. Set the integration-root policy to **Require approval** unless a narrower
   policy has been explicitly chosen.
4. Verify a harmless read through Executor and confirm the connection health.
5. Remove the upstream server or account connector from every agent client.
6. Authenticate each client to Executor and audit its resulting server list.

For services without dynamic OAuth client registration, create a dedicated
OAuth application only when its infrastructure and organizational boundary are
approved. Prefer official OpenAPI or MCP sources over maintaining translation
servers.

## Client configuration

The declarative sources are:

- Pi: `~/pi-config/mcp.json`
- Claude Code: `users/maxpw/modules/agent-tools.nix` and
  `users/maxpw/agents/claude/settings.json`
- Codex: `users/maxpw/modules/agent-tools.nix`
- OpenCode: `users/maxpw/agents/opencode/opencode.json`

Claude Code sets `disableClaudeAiConnectors` so account-level connectors cannot
bypass Executor. Codex may retain device-local stdio servers; Executor remains
its only remote server.

## Authenticate a client

Run the relevant one-time OAuth flow on each machine:

```text
Pi:        /mcp-auth executor
Claude:    claude mcp login executor
Codex:     codex mcp login executor
OpenCode:  opencode mcp auth executor
```

Use `--no-browser` with Claude over SSH and copy the resulting callback URL
back into that interactive session.

## Audit

```bash
claude mcp list
codex mcp list
opencode mcp list
jq '.mcpServers' ~/pi-config/mcp.json
```

The audit is complete when Executor is the only remote server shown. Local
stdio servers are allowed only for device-local capabilities.
