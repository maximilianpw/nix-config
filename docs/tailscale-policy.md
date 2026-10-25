# Tailscale policy: review-only lockdown candidate

[`policies/tailscale.hujson`](../policies/tailscale.hujson) is a complete candidate,
not the applied policy. HuJSON comments classify the evidence for each grant.
Nothing in the flake, activation, or CI uploads it. Opening or merging its PR
does not apply it. **Do not apply before the remaining gates below are resolved.**

## Baseline and identity

Initial device snapshot: 2026-10-25, approximately 11:12 UTC (12:12 Europe/Paris).
The ACL was fetched again at **2026-10-25 13:06:38 UTC (14:06:38 Europe/Paris)**;
its unrestricted grant and ETag were unchanged:

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
unchanged. The later host capture's Serve and Funnel JSON contain the same 23
private Services and no `AllowFunnel` or machine-level handlers
([L1083–1827](kim-tailscale-inventory.txt#L1083-L1827)). This shows no enabled
Funnel handler in that snapshot, not a tailnet-wide public-ingress audit.
The available read scopes still cannot enumerate the control-plane Service
catalog; the host status now supplies Service/VIP evidence below.

## Verified observations versus provisional grants

Evidence is the complete 2,078-line [Kim host capture](kim-tailscale-inventory.txt)
at [commit 590d38e](https://github.com/maximilianpw/nix-config/commit/590d38ef2e6b0bdb2648aeb702f15252852a1f02),
captured 2026-10-25 around 13:52 Europe/Paris (12:52 UTC). All inventory line
citations and policy comments refer to that immutable version. Unlike the
earlier isolated-orb scan, it shows the actual host interfaces
([L1–17](kim-tailscale-inventory.txt#L1-L17)). No new host commands were run here.

**Verified** below means a captured listener, configuration or connection—not
an end-to-end application test. **Provisional** grants retain repository-backed
requirements whose clients, direction or live usage are not established by this
single snapshot. Personal grants remain user-based; observing Joyce does not
prove every device owned by Max uses each allowed port.

Host destinations use separate IPv4/IPv6 aliases, independent of destination
tagging order. Service destinations use `svc:` identities, not Kim's host IP or
loopback backend ports. Responses to permitted connections need no reverse grant.

| Source | Destination | Protocol/port | Purpose | Evidence | Grant decision |
| --- | --- | --- | --- | --- | --- |
| Max's untagged devices (Joyce observed) | Kim | TCP 22 | OpenSSH / Fleet | Listeners [L114,147](kim-tailscale-inventory.txt#L114-L147); Joyce sessions [L161–171](kim-tailscale-inventory.txt#L161-L171); `RunSSH=false` [L1830](kim-tailscale-inventory.txt#L1830) | Keep; verified IPv4 flow and both-family listeners. Other clients/IPv6 flow not observed. |
| Max's untagged devices | 23 Kim-hosted `svc:` endpoints | TCP 443 | Private HTTPS apps | VIP map [L423–518](kim-tailscale-inventory.txt#L423-L518), Serve [L1083–1454](kim-tailscale-inventory.txt#L1083-L1454) | Keep; hosting verified, per-client use not measured. No raw backend grants. |
| `tag:homelab` (Kim) | `svc:git` | TCP 443 | Forgejo runner → Forgejo | Connection [L172](kim-tailscale-inventory.txt#L172), VIP [L437–440](kim-tailscale-inventory.txt#L437-L440), proxy [L1133–1148](kim-tailscale-inventory.txt#L1133-L1148) | Add; verified dependency missing from initial draft. |
| Max's untagged devices | `svc:leerr`, `svc:plannotator` | TCP 443 | Preserve existing Service access | Catalog definitions/VIPs [L615–626](kim-tailscale-inventory.txt#L615-L626), [L675–686](kim-tailscale-inventory.txt#L675-L686); absent from hosted map/Serve | Add explicit preservation grants; definitions verified, current host/use provisional. Do not delete or auto-approve them. |
| Max's untagged devices | Kim | TCP/UDP 22000 | Syncthing | Listeners [L81,151](kim-tailscale-inventory.txt#L81-L151); firewall [L1929–1933](kim-tailscale-inventory.txt#L1929-L1933) | Keep; listener verified, direct tailnet peer use provisional. |
| Max's untagged devices | Kim, Cuno | UDP 60000–61000 | mosh | Kim range [L1936](kim-tailscale-inventory.txt#L1936), [L2041](kim-tailscale-inventory.txt#L2041); no mosh socket in [L18–213](kim-tailscale-inventory.txt#L18-L213); `modules/fleet/nixos.nix` | Keep provisional; firewall allowance is not proof of a session. Cuno offline [L892](kim-tailscale-inventory.txt#L892). |
| Max's untagged devices; `tag:homelab` | Joyce, Cuno | TCP 22 | Fleet | `modules/fleet/ssh-access.nix`; no matching outbound Kim flow [L152–213](kim-tailscale-inventory.txt#L152-L213) | Keep provisional; incoming Joyce→Kim SSH does not prove the reverse direction. |
| `tag:homelab` | Cuno | UDP 60000–61000 | Outbound mosh | `modules/fleet/nixos.nix`; offline peer [L867–905](kim-tailscale-inventory.txt#L867-L905) | Keep provisional; no live listener/session evidence. |
| `tag:homelab` | Joyce | TCP/UDP 22000 | Syncthing reverse initiation | `users/maxpw/modules/syncthing.nix`; [L163](kim-tailscale-inventory.txt#L163) instead shows public-IP TCP 22067, consistent with a relay | Keep provisional; no captured direct peering, identity or folder confirmation. |
| LAN clients | Kim | TCP 8096 / 32400 | Jellyfin / Plex | Wildcard listeners [L115,140](kim-tailscale-inventory.txt#L115-L140); LAN-specific accepts [L1930–1942](kim-tailscale-inventory.txt#L1930-L1942) | No tailnet grant; explicit deny tests. See firewall caveat below. |

The 23 hosted names exactly match `lib/homelab-services.nix`. The status also
defines `leerr` and `plannotator`, so the earlier 23-name list was not the entire
known catalog. The runner flow to `100.125.229.20:443` maps specifically to
`svc:git`, not Kim's host-IP HTTPS port or every Service. Existing seven Service
approval entries and the Tailscale SSH section remain unchanged.

Kim's preferences verify `tag:homelab`, `RunSSH=false`, no advertised subnet
routes, `RouteAll=false` and no selected exit node
([L1828–1838](kim-tailscale-inventory.txt#L1828-L1838)). Its Service VIP
`PrimaryRoutes` ([L290–337](kim-tailscale-inventory.txt#L290-L337)) are not
evidence of a LAN subnet router or exit node. No subnet/internet grant is added.

### LAN-only intent is not verified tailnet isolation

Jellyfin/Plex have explicit **LAN-interface-only NixOS accept rules**, but their
listeners bind `0.0.0.0`, not just `192.168.1.99`. More importantly, `INPUT`
jumps to `ts-input` before `nixos-fw`
([L1886–1887](kim-tailscale-inventory.txt#L1886-L1887)), and `ts-input` accepts
all `tailscale0` input ([L1953](kim-tailscale-inventory.txt#L1953)). IPv6 has
the same ordering ([L2023–2024](kim-tailscale-inventory.txt#L2023-L2024),
[L2055](kim-tailscale-inventory.txt#L2055)). Thus those LAN-specific rules do
**not prove the media ports are unreachable through Tailscale** under the live
allow-all policy. No reachability probe was performed. The candidate denies
tailnet access to both ports, while direct LAN access is outside Tailscale ACL
control. Confirm whether any existing tailnet media clients would be affected.

Other omissions remain intentional review decisions: Windows RDP, Joyce mosh,
host-IP HTTPS, raw application backends, LAN discovery and arbitrary Kim→Service
access. Do not infer unused services from absent traffic in a single sample.

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

The updated candidate's four test cases (**163 assertions**) returned **HTTP 200
`{}`** on 2026-10-25. The previous draft fails the three new Service acceptance
assertions. Mutations using the host IP instead of the git VIP, allowing UDP
for the runner, or adding media-port grants also fail. Baseline SSH, tags,
Funnel and auto-approval sections match structurally, and a final read confirmed
the live ACL bytes and ETag were unchanged. No live connectivity probe was run.
For the current file's full-line-comment-only format, the local syntax check is:

```sh
sed '/^[[:space:]]*\/\//d' policies/tailscale.hujson | jq empty
git diff --check
```

This removes only whole-line comments, not arbitrary HuJSON syntax. Submit the
resulting JSON object to the read-only validator. No Nix module changed.

## Remaining evidence before rollout

- **Effective sshd configuration was not captured.** `=== sshd ===` is immediately
  followed by the next section ([L214–215](kim-tailscale-inventory.txt#L214-L215)).
  There is no captured command, stderr or exit status explaining why; do not
  infer a missing daemon, disabled SSH, or verified authentication settings.
  Listeners and sessions independently prove ordinary SSH is running. In an
  authorized host session, inspect `systemctl show sshd.service -p ExecStart`,
  then run that binary/configuration with `-T` (and representative `-C` context
  if Match rules apply), retaining stderr and exit status. Return only port,
  listenaddress, allowusers, authenticationmethods, passwordauthentication,
  kbdinteractiveauthentication and permitrootlogin values. Do not hide a failed
  command behind a filtering pipeline.
- Confirm direct Syncthing peers/addresses/folders and initiation direction
  without API keys. The observed public-IP TCP 22067 session is consistent with
  a relay; it does not establish direct Kim↔Joyce traffic or require an exit-node
  grant. Keep proposed direct transfer grants provisional until confirmed.
- Confirm intended mosh use and Kim→Joyce/Cuno Fleet access from operator usage
  or a representative host observation. Do not require commands on Joyce/Cuno
  for this phase; their service configuration remains repository-derived.
- Resolve the host/usage of `svc:leerr` and `svc:plannotator`, any additional
  catalog entries, and existing tailnet Jellyfin/Plex clients. The capture's
  missing handlers do not authorize deleting Services or withdrawing access.
- Sample normal agent, backup, sync and monitoring workloads for additional
  outbound dependencies; inspect relevant deployed references with secrets
  redacted. Confirm public ingress availability checks and independent console
  recovery. The earlier isolated-orb scan remains unusable as host evidence.

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
