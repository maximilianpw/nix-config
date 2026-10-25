# Tailscale policy: review-only lockdown candidate

[`policies/tailscale.hujson`](../policies/tailscale.hujson) is a complete candidate,
not the applied policy. It is deliberately strict JSON (also valid HuJSON).
Nothing in the flake, activation, or CI uploads it. Opening or merging its PR
does not apply it. **Do not apply before the Kim inventory below is reviewed.**

## Baseline and identity

Read-only API snapshot: 2026-10-25, approximately 11:12 UTC (12:12 Europe/Paris).
The exact ACL response ETag was:

```text
"a1ad08cc6cfcc000e41dffaba041e9510a4e0fd0001c0b82868c2be2f888d616"
```

The baseline has one unrestricted grant: `src: ["*"]`, `dst: ["*"]`,
`ip: ["*"]`. This candidate replaces it, not supplements it. Existing `ssh`,
`nodeAttrs` (including Funnel permission), `tagOwners`, and all seven
`autoApprovers.services` entries retain their baseline values.

Personal devices stay **untagged**, authenticated as `maximilianpw@github`.
There is no `tag:personal`. User grants cover all current and future untagged
devices owned by that identity, not just Joyce. Kim retains `tag:homelab`, owned
by `autogroup:admin`; its returned `user` field does not make it user-authenticated.
No new tags or device assignments are proposed. Future role tags must start with
zero assigned devices; an empty `tagOwners` array does not establish that.

| Device | Current identity | Tailscale IPv4 | Last seen (UTC) |
| --- | --- | --- | --- |
| Kim | `tag:homelab` | `100.76.56.97` | 2026-10-25 11:12:57 |
| Joyce | User | `100.82.28.19` | 2026-10-25 11:12:57 |
| Cuno | User | `100.91.91.50` | 2026-09-25 15:00:07 |
| BIG-MAX-PC | User | `100.110.168.84` | 2026-09-20 16:06:13 |
| iPad (`ipad153`) | User | `100.117.103.44` | 2026-09-26 17:01:11 |
| iPhone (`iphone172`) | User | `100.99.94.79` | 2026-10-25 11:12:57 |

All six are authorized, report `isExternal: false`, and have the same returned
user. None is 60+ days stale; last-seen timestamps are not proof of continuous
availability or exclusive human control. IPv6 aliases in the policy come from
the same API response. Cuno's live address fills a gap in `lib/hosts.nix`, where
`client = null`; this does not enroll its Fleet SSH key or alter that inventory.

Joyce advertises `192.168.0.0/24` but has no enabled routes. All other advertised
route lists are empty; all six enabled-route lists are empty. No advertised or
approved exit-node default routes were visible. The candidate grants no subnet
or exit-node access. Direct internet egress is outside these tailnet grants.

Funnel is permitted for `autogroup:member` by the baseline `nodeAttrs`, preserved
unchanged. Actual active Funnel listeners are **unknown**, not absent. The
available Policy File read and Devices Core read scopes do not enumerate
Services (`services:read` is separate) or establish host-local Serve/Funnel state.

## Tags and ports

Host destinations use separate IPv4/IPv6 aliases, independent of destination
tagging order. Service destinations use `svc:` identities, not Kim's host IP or
loopback backend ports. Responses to permitted connections need no reverse grant.

All port grants below are **repository-derived proposals, not verified host
dependencies**. The isolated homelab orb cannot observe Kim's host network.
No grant for an unknown listener is inferred from an empty container scan.

| Source | Destination | Allowed initiation | Evidence / caveat |
| --- | --- | --- | --- |
| Max's untagged devices | Kim, Joyce, Cuno | TCP 22 | `modules/fleet/ssh-access.nix`; ordinary OpenSSH, not a new Tailscale SSH authorization |
| Max's untagged devices | Kim, Cuno | UDP 60000–61000 | `modules/fleet/nixos.nix`, mosh range |
| Max's untagged devices | Kim | TCP/UDP 22000 | Syncthing standard transfer ports; verify live overrides/pairing |
| Max's untagged devices | 23 named Services in the policy | TCP 443 | `lib/homelab-services.nix` and `homelab/tailscale-serve.nix` |
| `tag:homelab` | Joyce, Cuno | TCP 22 | Existing Fleet trust permits Kim as an SSH client |
| `tag:homelab` | Cuno | UDP 60000–61000 | Existing NixOS Fleet/mosh configuration |
| `tag:homelab` | Joyce | TCP/UDP 22000 | `users/maxpw/modules/syncthing.nix` declares the Mac peer; pairing remains mutable |

Everything else lacks a grant. In particular, Kim cannot initiate arbitrary
connections to personal devices; only the Fleet and Syncthing exceptions above
remain. The phone, tablet and Windows host receive no incoming grants. Windows
RDP, Joyce mosh, direct host HTTPS, raw application backends, LAN discovery,
and Kim-initiated Service access are not assumed necessary. Confirm those
omissions against usage before applying; this is not proof they are unused.
Jellyfin TCP 8096 and Plex TCP 32400 are declared in the repository, but actual
host exposure and tailnet consumers are unverified: no grants are invented for
them here. Tailscale ACLs do **not** restrict direct LAN access to those ports.

All 23 repository-declared Service names are enumerated and tested at TCP 443,
including the seven in the baseline's approval map. No Service is created,
deleted, renamed, or newly auto-approved. Actual advertisements, extra live
Services, machine-level Serve handlers and any host-originated Service consumers
remain an inventory gate. API policy validation alone cannot prove completeness
or application availability. Existing Tailscale SSH check-mode rules are
preserved, but network grants still constrain reachability; verify Kim's
`RunSSH` setting before relying on ordinary OpenSSH behavior.

## Validation and review

Use only short-lived OAuth access tokens in memory. Do not print credentials,
commit raw device responses, or store tokens, secret files, or live snapshots in
the Nix store. No policy-write or device-write scope is needed for this review.

1. `GET /api/v2/tailnet/-/acl` with `Accept: application/hujson`; retain the
   exact response and quoted ETag privately. Fetch devices with
   `GET /api/v2/tailnet/-/devices?fields=all`.
2. Review the **full baseline-to-candidate diff**, not just the Git new-file diff.
   Preserve unrelated policy sections semantically and inventory all removed
   access. Refresh the baseline if the ETag changes.
3. `POST /api/v2/tailnet/-/acl/validate` with the candidate JSON object (not a
   test-array-only body). This endpoint validates the hypothetical policy and
   embedded tests without changing the live policy; `policy_file:read` suffices.
   Inspect the response body: test failures can return HTTP 200 with
   `message: "test(s) failed"` and per-test errors. HTTP status alone is not success.
4. Embedded tests cover each explicit service/port, both host address families,
   TCP/UDP separation, mosh boundaries, prohibited personal-device access and
   forbidden subnet access. They are examples of denied traffic, not an
   exhaustive scan or proof that a service is listening.

The candidate's four test cases (149 assertions) returned **HTTP 200 `{}`** on
2026-10-25. Temporary mutations restoring allow-all, widening the mosh range,
allowing UDP SSH, and removing T3 Code access each produced test failures.
The live ACL bytes and ETag remained unchanged afterward. Live connectivity is
intentionally untested. Run `jq empty policies/tailscale.hujson` and
`git diff --check` for local syntax/whitespace checks; no Nix module changed.

## Kim inventory still required (read-only, host-authorized session)

The reported homelab orb is Docker container `20cfba550999` at `172.17.0.3`.
It cannot see `tailscale0`, `enp194s0`, host mounts/sockets, the tailscaled socket,
or host listeners. Its empty 100.x scan is **not host evidence**. Do not bypass
that isolation; use an explicitly authorized host session or have the operator
collect output. API-reported tags/routes above are control-plane observations,
not verification of Kim's running preferences, routing or Service VIPs.

The minimum initial host collection is:

```sh
ip -brief address show
sudo ss -lntup
sudo ss -ntup
sudo sshd -T | grep -E '^(port|listenaddress|allowusers|authenticationmethods) '
tailscale status --json
tailscale serve status --json
tailscale funnel status --json
sudo tailscale debug prefs | jq '{RunSSH, AdvertiseTags, AdvertiseRoutes, RouteAll, ExitNodeID, ExitNodeIP}'
```

Return interface identity, listener bind IP/protocol/port/process, observed
tailnet connections and their purpose, selected SSH/preferences fields, and
all Service/VIP/Serve/Funnel mappings actually exposed by these commands.
Redact unrelated peer information and any credential-bearing backend URLs.
If a command or field is unavailable, record that limitation instead of treating
it as an empty inventory. Capture host firewall rules via the active backend
(`sudo nft list ruleset` or `sudo iptables-save` plus `sudo ip6tables-save`),
and report the relevant `tailscale0`/LAN rules for SSH, mosh, Syncthing,
Jellyfin 8096 and Plex 32400. No commands here were run on Kim by this thread.

Return a sanitized table of **source identity/IP → destination IP/Service →
protocol/port → purpose → evidence**, distinguishing observations from inferred
requirements. Do not restart anything, change Serve/Funnel, or probe denied
access before a separately authorized rollout.

- List TCP and UDP listeners with process/unit names and bind addresses:
  `sudo ss -lntup`. Inspect established sockets with `sudo ss -ntup`; retain
  tailnet IPv4 (`100.64.0.0/10`), tailnet IPv6 (`fd7a:115c:a1e0::/48`), and any
  routed peers. Sample during normal Fleet, sync and service use; one idle
  snapshot cannot establish that outbound dependencies do not exist.
- Collect `tailscale status --json`, `tailscale serve status --json`, and
  `tailscale funnel status --json`. Account for every `Services` entry, endpoint,
  backend and machine-level handler; inspect `AllowFunnel` where exposed. Do not
  substitute this for the control-plane Service catalog if host output omits
  inactive or other-host Services. An administrator can supply that catalog.
- Extract only relevant fields from `tailscale debug prefs`: `RunSSH`,
  `AdvertiseTags`, `AdvertiseRoutes`, `RouteAll`, `ExitNodeID` and `ExitNodeIP`.
  Never publish the full preferences/persisted identity or authentication data.
- Confirm actual OpenSSH ports and listen addresses, mosh range, firewall
  interface rules, container/network-namespace listeners and published ports.
  Inspect only network fields, not full container environment/inspect output.
- Identify Syncthing peer names/addresses, listen addresses and connection
  protocols without API keys. Verify Kim↔Joyce TCP/UDP 22000 and any other peers,
  custom ports, relay dependency or discovery requirement.
- Search deployed configuration/scripts for tailnet IPs, MagicDNS names and
  `svc:` destinations. Return redacted references and required connections,
  especially Kim→Joyce/Cuno Fleet, Kim→Services, monitoring, agents, backups and
  container traffic. Do not dump secret-bearing configuration or runtime env.
- Inventory public ingress paths and their backend dependencies, including
  Cloudflare and any actual Funnel use. Record existing availability checks and
  an independent console/recovery path before proposing network changes.

No commands on Joyce or Cuno are required for this phase. Their configured roles
come from this repository; live reachability remains explicitly unverified.

## Later rollout requires separate authorization

The final candidate is **not inert staging**: replacing the wildcard immediately
affects already-tagged Kim and untagged clients. No device tagging can make that
replacement a one-device-at-a-time rollout by itself.

After inventory, derive separately reviewed intermediate policies: retain the
baseline only for explicit not-yet-migrated device IPs (both families), then
remove one device's temporary compatibility grants at a time. Never retain a
global wildcard source grant alongside the restrictions. Each intermediate
policy needs its own tests, validation, complete diff and approval; the final
candidate's deny tests may intentionally fail during compatibility stages.

Before any later authorized write, freshly fetch the live ACL/ETag, archive the
reviewed rollback policy outside Git, validate both candidates, and establish
independent recovery access. Use the exact reviewed ETag in `If-Match` for
`POST /api/v2/tailnet/-/acl`; on HTTP 412 stop, refetch and re-review, never retry
unconditionally. No write credentials are requested as part of this PR.

After each separately authorized stage, check permitted flows, prohibited flows
from the affected device, Service availability and public ingress. Stop on a
regression. A rollback is a reviewed policy restoration using a freshly checked
ETag, not removal of Kim's last tag. Personal devices keep user identity
throughout. Device deletion, Funnel changes and route approval remain separate
decisions, outside this plan.

References: [original planning gist](https://gist.github.com/alexknowshtml/515c5e741dc4c157d2293f782d15ed41),
[policy API](https://tailscale.com/api),
[policy/test syntax](https://tailscale.com/docs/reference/syntax/policy-file),
[tag identity](https://tailscale.com/docs/features/tags).
