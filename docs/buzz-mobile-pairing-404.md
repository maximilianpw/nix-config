# Buzz Mobile Pairing: WebSocket 404

## Summary

Buzz mobile pairing failed with:

```text
WebSocket connection failed: HTTP error: 404 Not Found
```

The main relay was healthy. The failure occurred because a membership-enforcing
Buzz relay advertises NIP-43, so current clients use a separate pairing relay.
When the relay does not advertise `pairing_relay_url`, Buzz falls back to the
legacy WebSocket path `/pair`. This deployment sent `/pair` to the main relay,
which returned its HTML 404 response because no pairing sidecar was present.

Observed on 2026-07-24:

| Probe | Result | Meaning |
| --- | --- | --- |
| WebSocket upgrade on `/` | `101 Switching Protocols` | TLS, Tailscale Serve, and the main relay were healthy |
| NIP-11 document | Version `0.2.0`, NIP-43 present, no `pairing_relay_url` | Current clients derive the legacy `/pair` URL |
| WebSocket upgrade on `/pair` | `404 Not Found` | The derived pairing endpoint was missing |
| `/usr/local/bin/buzz-pair-relay` in the `0.2.0` image | Missing | The stable relay image could not provide the sidecar itself |

## Reproduction

Replace `relay.example.ts.net` with the relay host. The first command should
return `101`; before the fix, the second returned `404`.

```sh
curl --http1.1 --max-time 3 --include --no-buffer \
  -H 'Connection: Upgrade' \
  -H 'Upgrade: websocket' \
  -H 'Sec-WebSocket-Version: 13' \
  -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  'https://relay.example.ts.net/'

curl --http1.1 --max-time 3 --include --no-buffer \
  -H 'Connection: Upgrade' \
  -H 'Upgrade: websocket' \
  -H 'Sec-WebSocket-Version: 13' \
  -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  'https://relay.example.ts.net/pair'
```

The client behavior is implemented in
[`desktop/src-tauri/src/commands/pairing.rs`](https://github.com/block/buzz/blob/acfbb1bb6af54cb29cb152496ff43b8285dcb8cf/desktop/src-tauri/src/commands/pairing.rs):
NIP-43 without an advertised pairing URL selects `/pair`.

## Fix used here

The compatibility fix deliberately avoids upgrading the stateful relay:

1. Keep the database-backed Buzz relay on its existing pinned `0.2.0` image.
2. Run `buzz-pair-relay` from Buzz `v0.4.23` as a separate, stateless Compose
   service bound to `127.0.0.1:19005`.
3. Add a Tailscale Serve path backend that sends `/pair` for `svc:buzz` to
   `http://127.0.0.1:19005`.
4. Keep the pairing image pinned by OCI digest. The digest is multi-architecture
   and corresponds to Buzz commit `acfbb1bb6af54cb29cb152496ff43b8285dcb8cf`,
   whose image includes `/usr/local/bin/buzz-pair-relay`.

The image declares `/usr/local/bin/buzz-relay` as its OCI `ENTRYPOINT`.
Docker Compose's `command` field replaces only the image `CMD`, so using
`command: /usr/local/bin/buzz-pair-relay` accidentally launches the main relay
with the pairing binary as an argument. The pairing service must override
`entrypoint` instead. The characteristic failure is a crash loop containing
`Starting buzz-relay` followed by a database connection error.

### Activation failure after adding the sidecar

The first deployment exposed a separate startup problem:

```text
warning: the following units failed: buzz.service
```

The pairing sidecar was healthy, but the main relay was unhealthy and its log
stopped after:

```text
running git object-store conformance probe (A3 gate)
transport drop (pre-classification: socket/send failure)
```

The Compose start restarted MinIO and the relay together. The relay's
32-request object-store conformance race encountered a transient transport
drop, and the upstream `0.2.0` probe has no outer timeout around the request
batch. It therefore never opened its health port. A normal systemd retry did
not help because `docker compose up` reused the already-running unhealthy
container.

The deployment now retries once by force-recreating only `relay` and
`pairing-relay` with `--no-deps`. Postgres, Redis, and MinIO remain running and
settled. This preserves `BUZZ_GIT_CONFORMANCE_PROBE=true` instead of bypassing
the object-store correctness gate. A relay-only restart recovered to healthy
in 11 seconds during diagnosis.

The same `--no-deps` rule applies to `buzzctl restart`; without it, Compose
also force-recreates the stateful dependencies of the named relay service.

Relevant configuration:

- `homelab/buzz/stack.nix`: pairing container, loopback binding, image pin, and
  backup image inventory.
- `lib/homelab.nix`: declares `/pair` as a path backend for Buzz.
- `homelab/tailscale-serve.nix`: applies all declared path backends with
  `tailscale serve --set-path`.
- `tests/buzz-config-regression.nix` and
  `tests/tailscale-serve-regression.nix`: prevent the sidecar or route from
  disappearing.

Tailscale Serve supports routing different URL paths to different local
backends with
[`--set-path`](https://tailscale.com/docs/reference/tailscale-cli/serve).

## Verification after deployment

Apply the NixOS configuration, then check:

```sh
sudo buzzctl status
tailscale serve status --json
```

`buzzctl status` should show both `relay` and `pairing-relay` healthy. Repeat
the `/pair` WebSocket probe above; it must return:

```text
HTTP/1.1 101 Switching Protocols
```

Finally, generate a fresh QR code in Buzz Desktop and complete a mobile pairing.

## Longer-term cleanup

Newer Buzz relays support `BUZZ_PAIRING_RELAY_URL` and advertise
`pairing_relay_url` in NIP-11. Once the stateful relay can be upgraded safely,
the cleaner topology is a dedicated pairing hostname, as described by the
[upstream Helm deployment](https://github.com/block/buzz/blob/main/deploy/charts/buzz/README.md#device-pairing-relay).
At that point, remove the legacy `/pair` compatibility route only after the
NIP-11 document advertises the dedicated `wss://` URL and both desktop and
mobile clients have been verified against it.

## Upstream issue draft

**Title:** Self-hosted NIP-43 relay sends mobile pairing to missing `/pair`
endpoint

**Body:**

> A self-hosted, membership-enforcing Buzz relay advertises NIP-43. Current
> desktop pairing logic interprets NIP-43 without `pairing_relay_url` as a
> signal to connect to `<relay-url>/pair`. The stable `0.2.0` relay image does
> not contain `buzz-pair-relay`, and the Compose deployment does not create or
> route that endpoint. The main relay therefore returns HTTP 404 and mobile
> pairing cannot start, even though the main WebSocket endpoint is healthy.
>
> Expected: the self-host deployment either includes and routes a pairing
> sidecar, advertises a configured dedicated pairing URL, or documents that
> mobile pairing requires this additional service.
>
> Diagnostic signature: `/` upgrades with HTTP 101; NIP-11 contains NIP-43 but
> no `pairing_relay_url`; `/pair` returns HTTP 404.
>
> A working downstream compatibility fix runs the stateless
> `buzz-pair-relay` from a newer pinned image and routes `/pair` to it while
> leaving the stateful `0.2.0` relay unchanged.

### Upstream issue draft: conformance probe startup hang

**Title:** Relay startup can hang indefinitely in the Git object-store
conformance probe after a transport drop

**Body:**

> Buzz relay `0.2.0` was started by Docker Compose against MinIO
> `RELEASE.2025-09-07T16-13-09Z`. Startup reached `Media storage connected`,
> began the Git object-store A3 conformance probe, logged one
> `transport drop (pre-classification: socket/send failure)` in
> `if_match_race`, and then produced no further output. The process remained
> running but never opened its configured health port, so `docker compose up
> --wait` eventually failed.
>
> Re-running `docker compose up` did not recover because Compose reused the
> running unhealthy relay container. Restarting only the relay after MinIO
> was settled completed the same enabled probe and reached healthy in 11
> seconds.
>
> Expected: each probe request or the complete probe has a bounded timeout.
> A timeout should fail startup with the probe phase and backend error instead
> of leaving the relay alive but permanently unready.
>
> Downstream workaround: keep `BUZZ_GIT_CONFORMANCE_PROBE=true`, then retry
> once with `docker compose up --detach --wait --no-deps --force-recreate
> relay`. `--no-deps` matters: without it, `--force-recreate relay` also
> recreates the relay's Postgres, Redis, and MinIO dependencies.
