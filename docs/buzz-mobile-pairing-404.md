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
buzzctl status
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
