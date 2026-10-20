# Portfolio tracker

[portfolio-tracker](https://github.com/maximilianpw/portfolio-tracker) keeps a read-only copy of the Trade Republic account on Kim. Its API listens only on `127.0.0.1:19014`; there is no public route or tunnel hostname. Bots and agents reach it through Executor, which runs with host networking and holds the API's bearer token, as for [homelab MCP](media-mcp.md). State lives in `/var/lib/portfolio-tracker`.

`homelab/portfolio-tracker.nix` wires the upstream NixOS module to sops:

| Secret (`secrets/portfolio-tracker.yaml`) | Use |
| --- | --- |
| `token` | API bearer token. Every endpoint except `/health` and `/openapi.json` requires `Authorization: Bearer <token>`. |
| `corrections` | `corrections.toml`: opening balances and adjustments for what Trade Republic's timeline omits (the PEA transfer). It lists holdings, so it stays encrypted. |

The Trade Republic login is mutable state, not a sops secret: pytr keeps the session, and the phone number and PIN it stored at login, in `/var/lib/portfolio-tracker/.pytr`.

## First deployment

Host activation needs explicit operator approval.

1. Activate the configuration on Kim.
2. Log in once: `sudo portfolio-tracker-login`, then confirm in the Trade Republic app.
3. Run the first sync: `sudo systemctl start portfolio-tracker-sync`. Check `journalctl -u portfolio-tracker-sync` for `sync finished … complete=true` and no reconciliation warnings.
4. On Kim, check the API: `curl -s http://127.0.0.1:19014/health` and `curl -s http://127.0.0.1:19014/openapi.json | jq .info`.

## Executor integration

Sign in to `https://executor.maximilian.pw` and add an integration:

| Field | Value |
| --- | --- |
| Type | OpenAPI |
| Spec URL | `http://127.0.0.1:19014/openapi.json` |
| Namespace | `portfolio` |
| Authentication | Bearer, using the SOPS secret `token` from `secrets/portfolio-tracker.yaml` (on Kim: `/run/secrets/portfolio-tracker-token`). Enter it only in Executor's secret field. |

Refresh tool discovery. Executor should list `get_positions`, `get_summary`, `get_movers`, `get_dividends` and `get_transactions`. All are reads, so no approval policy is needed. Call `get_summary` to check the token. Use an organization connection if the Grok bot signs in to Executor as a different user than you.

The Grok bot then uses Executor's MCP endpoint `https://executor.maximilian.pw/mcp` with its own Executor credentials. It never sees the tracker's token, and the tracker isn't reachable from outside Kim.

To rotate the token, run `sops secrets/portfolio-tracker.yaml`, replace `token` with a new random value of at least 16 characters (e.g. `openssl rand -base64 32`), deploy, and update the secret in Executor.

## Operations

- The sync runs daily at 23:15 Europe/Berlin. A failed `portfolio-tracker-sync.service` shows up in the homelab check.
- `session expired` in the sync log means the Trade Republic login lapsed. Run `sudo portfolio-tracker-login` again.
- Reconciliation warnings mean the history and Trade Republic disagree. Run `sudo -u portfolio-tracker env HOME=/var/lib/portfolio-tracker PT_DATA_DIR=/var/lib/portfolio-tracker portfolio-tracker corrections-template` to see proposed entries, review them, and add them to the `corrections` secret.

## Recovery

Restore `/var/lib/portfolio-tracker` as one recovery point with both services stopped. It holds:
- `portfolio.sqlite`: history, prices and run log;
- `pytr/all_events.json`: the raw timeline;
- `.pytr/`: the Trade Republic session and stored login.

Start the archived application version, then run a sync. Acceptance: the sync reconciles both accounts, and `get_summary` works through Executor. If the session didn't survive, log in again. The history is rebuilt from Trade Republic's timeline anyway, but price history only exists in the database.
