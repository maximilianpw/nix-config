# Leerr on Kim

Leerr is a private Tailscale service at `https://leerr.liger-shilling.ts.net`.
It runs the production `server/main.ts`, never `server/preview.ts`. The native
Nix package uses its locked Node dependencies and builds the web client; no
preview upstreams or fixture data are installed into the runtime.

The source is `packages/leerr/source.tar.gz`, based on the handoff directly from
[the implementation thread](https://ampcode.com/threads/T-01a086ce-b89c-76ae-b0c5-4b7277803964),
not GitHub `main`, plus the tested setup fixes from
[the setup investigation](https://ampcode.com/threads/T-01a0880a-ed61-76dc-939f-8e3caa112195).
Archive SHA256:
`b4dc546fa8cea3f7b5643b27ff154d7b38b2e3670f6a5ece20a0b8cc284a54a3`.
This adds artist/album search filters, artist discographies and matched Last.fm
artwork from [the search investigation](https://ampcode.com/threads/T-01a09537-cac2-7599-a2fb-755cc4c4757a),
on top of archive
`35bfe39eed6f2681757ca9eaa9e685e62ecc6ff1c4d4f5b140651632a41d80bc`,
which fixed stale HTML validators and missing-asset fallback on top of archive
`59db059104b594a4307f6b4d119eb9fff5d1b9a1726f1a31f54636af90792b05`,
which added modern Jellyfin token headers and Discover failure/empty-state fixes to
the rose archive
`86cb0ca42d3cf66bf46ef175b778f06c50ce75334be97f7b002dc43c7a875e67`,
which added the selected rose palette as CSS-only changes to the setup-fixed archive
`9811a9133e609497989b86249428d1b35ebdef34991d05b9fb9b5935c324aafa`.
The setup fixes, Inter/OFL, semantic green/red statuses and layout
are unchanged. Button hover uses deep rose to retain white-text contrast.
No palette switcher or design-preview overrides are included.
The original handoff SHA256 was
`d4c5f992a59ac12390dfcd3611402bb0fb084ada2c2b62a1a10bba54d2ad9b85`.
Retain the packaged snapshot for reproducible builds until an explicitly reviewed
upstream release replaces it. The Nix build runs the source's server tests and
lint before pruning development dependencies and omitting preview modules.
The source archive intentionally retains test fixtures for those build checks;
they are not served or copied into the installed application. The installed
package also removes dependency test/fixture directories and exposes only the
production start and operator npm commands. Shared `fixturePreview` API/UI
warning code remains, but `main.ts` always uses real `Upstreams` and exposes no
environment switch to enable preview. Missing or denied Jellyfin access returns
an error, never sample albums.

## Search and cover art

Search is MusicBrainz, not Last.fm. All / Artists / Albums filters preserve the
query and select from separately returned artist and album matches. Search treats
input as literal words, requires all words, and limits album results to album
release groups. Artist matches retain disambiguation, country and person/group
type. Their **Browse albums** action pages through the selected artist's MBID,
ranking official releases ahead of other albums without excluding the latter.
The UI shows the 10-artist/25-album search limits and pages artist albums by 25.
Album **Request** still requires edition selection and server identity validation.

The public repro `the life of pablo` returned many unrelated single-word Pablo
titles with the old raw MusicBrainz query. The all-term query returned three
matching album groups. Its intended group is
`8c18657a-6338-490d-a952-897663596b96`; MusicBrainz credits Kanye West while the
canonical artist name is Ye. Search now preserves that credited name.

On 2026-09-12, CAA correctly redirected that group to release
`99e14f9e-5831-4b2c-b595-531be0f225ea` on Internet Archive, but the image download
reset/timed out from Kim and Chromium. This was not a wrong entity path or a
missing CSP host. The same album's public Last.fm Fastly cover loaded normally.
When the caller already has Last.fm connected, search now makes one read-only
`album.search` call and attaches artwork only for exact case-insensitive album
title and credited-artist matches. Artist browsing uses `artist.getTopAlbums`
scoped by artist MBID; recommendations retain their existing top-album images.
Only HTTPS image paths on `lastfm-img.freetls.fastly.net` are accepted. Images
load directly in the browser, with CAA fallback and **Cover unavailable** when
both fail. No arbitrary URL proxy, shared image cache or new credential is used.
Without a usable Last.fm match, CAA remains the source; provider outages can still
leave missing covers. Last.fm MBIDs never replace MusicBrainz release-group IDs.

Contracts: [MusicBrainz search](https://musicbrainz.org/doc/Indexed_Search_Syntax),
[CAA API](https://musicbrainz.org/doc/Cover_Art_Archive/API),
[Last.fm album.search](https://www.last.fm/api/show/album.search), and
[artist.getTopAlbums](https://www.last.fm/api/show/artist.getTopAlbums).
Source verification includes real-socket HTTP regressions with captured public
MusicBrainz responses and controlled Last.fm envelopes, plus
`scripts/check-search-browser.mjs`. Set `PLAYWRIGHT_MODULE` and `CHROMIUM` to
installed tooling and run it with `node --import tsx` after `npm run build`.
It creates disposable in-memory users, fetches the public Fastly cover live, and
tests controlled image failure/fallback, filters, keyboard, pagination and mobile
states without production data or acquisition writes. Last.fm's keyed API was
not exercised live during this investigation; no stored credentials were read.

HTML entry points are served directly with `Cache-Control: no-store`, without
stat-derived validators. Nix normalizes output mtimes; same-length HTML in
different generations otherwise shares an ETag and incorrectly returns 304,
leaving browsers referencing removed JavaScript chunks. Missing assets return
404, not HTML. SPA fallback applies only to GET/HEAD HTML navigation without a
file extension outside `/api/` and `/assets/`. Build tests exercise actual Vite
JS/CSS/font files, old conditional headers, and fallback behavior. A hard reload
can recover a browser holding the old HTML while this fix awaits activation.

The `leerr` system user owns `/var/lib/leerr` (0700). SQLite, sessions, encrypted
connection credentials and the first-start setup token live there. The
independent encryption key comes from `secrets/leerr.yaml` through sops-nix at
`/run/secrets/leerr-encryption-key` (0400, readable only by Leerr and root).
Never regenerate that key to fix a login or database problem.

## Activation and enrollment

Build/evaluate before switching:

```sh
nix flake check --no-build
make build
```

Review the configuration diff and generation changes, then use the normal
interactive deployment command on Kim (requires sudo):

```sh
make -C /home/maxpw/nix-config rebuild
```

This is a **full system switch**, not a Leerr-only deployment. The September 12
search package builds successfully, and its closure differs from the unchanged
repository baseline only in Leerr. Compared with Kim's active September 5
generation, however, the build also includes existing kernel, Home Assistant,
SABnzbd and other updates. Those unrelated changes require separate review and
approval before running the command above. No narrow Leerr activation command
is currently supported; do not substitute an imperative service override.
This investigation did not activate anything (ordinary sudo requires a password).
Full flake evaluation and the headless Kim generation build pass. An initial
missing-store-source evaluation failure cleared after evaluating the unchanged
baseline and rerunning with the evaluation cache disabled.

The inventory adds `svc:leerr` to the existing Tailscale Serve reconciler.
No Cloudflare ingress, public Funnel or new firewall opening is needed. If the
tailnet requires service creation or host approval, approve only `svc:leerr`
for Kim's existing `tag:homelab` identity in the Tailscale admin console. Do not
reset Serve or replace unrelated service mappings.

If Leerr has no MagicDNS record even though its local Serve mapping is present,
open the Tailscale admin console's **Services** page, select **Advertise → Define
a Service**, name it `leerr`, and declare `tcp:443`. Then open that service and
approve Kim's pending advertisement under **Service hosts**, if required. Keep
access limited to the intended tailnet users. Local advertisement alone does
not establish the service definition or prove HTTPS reachability.

After activation, check the real listener and HTTPS route:

```sh
systemctl status leerr tailscale-serve --no-pager
curl --fail http://127.0.0.1:19008/health
curl --fail https://leerr.liger-shilling.ts.net/health
tailscale serve status
```

Use a trusted terminal on Kim to read `/var/lib/leerr/setup-token` with sudo;
never paste the token into an agent conversation. Open the private HTTPS URL
while connected to Tailscale, use that token to enroll the first administrator,
and choose a unique account password. Then configure:

- Jellyfin: `https://jellyfin.maximilian.pw` (strict TLS).
- Lidarr, only when wanted: `https://lidarr.liger-shilling.ts.net` and an
  intentionally supplied Lidarr API key. Do not test live acquisitions as part
  of deployment verification.
- Each Leerr user must sign into Jellyfin with their own Jellyfin account.
  Do not substitute a shared Jellyfin administrator API key for user playback.
- Last.fm is optional; leave it unset unless intentionally configuring it.

Settings now separates **Save Jellyfin server** from **Save Lidarr settings**.
Save the Jellyfin URL before signing into Jellyfin under Connections; until a
URL exists, administrators see a server-setup action and members see ask-admin
guidance instead of a nonfunctional login form. A missing URL also routes a
newly signed-in user to Settings.

Lidarr setup requires an API key from **Settings → General → Security** before
any upstream validation. A blank key keeps an existing key only for the same
server URL. Save the URL/key first, then select the root folder, quality profile,
and metadata profile and save again. A failed Lidarr setup cannot block a
separate Jellyfin save. Last.fm takes a username and **API key**, not the user's
password or the API secret; it uses read-only public profile access.

Connection errors now distinguish HTTP 401 from HTTP 403, report Last.fm's
numeric API error (including invalid/suspended API keys), and identify the
Lidarr rootfolder/qualityprofile/metadataprofile operation when validation
fails. Invalid endpoint syntax has its own actionable error. These messages
contain no upstream response body, credential, or authenticated URL. HTTP 403
can indicate remote-access or proxy policy rather than a wrong password.
If a connection still fails, report only this error text; do not share request
bodies, cookies, passwords, API keys, or HAR files containing credentials.

Jellyfin requests now use `Authorization: MediaBrowser Token="…"`, not the legacy
`X-Emby-Token` header. Current Jellyfin source gates that old header behind
`EnableLegacyAuthorization` and includes a migration disabling it. Kim's public
server reports version 12.0.0 and its journal records successful completion of
`DisableLegacyAuthorization` at 2026-09-08 14:09:11 UTC. Its current private
setting has not been inspected. This
compatibility defect can explain successful sign-in followed by library HTTP 401;
it does not prove that a particular stored token is otherwise valid. No account
reset, credential replacement, or server-side legacy-auth enablement is needed
to deploy this client fix.

Library and Discover both call Jellyfin's `/Items`: Discover uses it to exclude
owned albums after generating Last.fm/MusicBrainz candidates. Empty candidates
now skip that call. Nonempty recommendations are withheld if any library page
fails, with a Jellyfin-specific error rather than unverified ownership. Last.fm
and MusicBrainz HTTP authentication errors identify their service. Empty results
distinguish no source candidates from all candidates already owned/requested.
Acquisition creation still fails closed if connected-library access fails.

Saving credentials does not prove library permissions or acquisition readiness.
Confirm read-only library access as the actual Jellyfin user; an empty authorized
library or an explicit setup/error state is valid, synthetic demo content is not.
Mac Keychain secrets are not imported by this deployment.

`LEERR_ORIGIN` must exactly match the browser's HTTPS origin. Tailscale Serve
terminates HTTPS and forwards to `127.0.0.1:19008`; only `127.0.0.1` is trusted
for proxy headers. Never disable secure cookies, CSRF or certificate validation
to work around a URL mismatch.

## Recovery

Follow `docs/homelab-recovery.md` and restore into isolated staging first.
The inventory quiesces `leerr.service` while archiving `/var/lib/leerr`, and the
backup manifest records the pinned source version. The encrypted key is in the
archived Nix checkout; independent Age recovery material must remain available
outside Kim and outside its backup repository.

Stop Leerr before replacing state. Restore the entire data directory together
with its matching encryption key and archived package version. Preserve owner
`leerr:leerr`, directory mode 0700, file permissions and SQLite sidecar files.
Test SQLite integrity, account login and per-user Jellyfin library access in an
isolated instance before exposing the restored service. Never run reset,
migration, key rotation or restore tools against production as a diagnostic.

For code rollback, keep the previous NixOS generation. A generation rollback
does not undo a SQLite migration: restore the matching pre-upgrade database if
the older application cannot read the new schema. Keep service and ingress
stopped until that compatibility is established.
