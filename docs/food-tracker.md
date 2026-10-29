# Foodlog food journal

Kim serves the pinned `food-tracker-src` revision as a compiled single-page app
at `https://food-tracker.liger-shilling.ts.net`. Nginx binds only
`127.0.0.1:19015`; the inventory generates `svc:food-tracker` HTTPS ingress,
monitoring and the Foodlog dashboard card. There is no public Cloudflare route
or firewall opening. Tailscale owns access control; this change does not alter
tailnet ACLs or approve a new Tailscale Service in the admin console.

The application is **browser-local**, not a server-backed diary. Kim holds no
journal data or secrets to back up. Use Settings → Export JSON to back up a
browser's journal and Import JSON to restore it. Export from the old preview
before moving to this new origin: browser storage is origin-specific. Changing
devices/browsers also requires export/import. Private/incognito storage may be
discarded by the browser.

WebMCP tools are available only in supporting browsers, with visible confirmation
before logging a prepared meal. This does not expose a remote MCP endpoint.

## Install on a phone

With Tailscale connected, open the HTTPS endpoint in Safari on iPhone and choose
Share → Add to Home Screen. On Android Chrome, choose Install app / Add to Home
screen from the browser menu. Foodlog opens in standalone mode with its own icon.
After the first online load finishes caching, the journal works offline. App
updates wait until every Foodlog window closes, preserving unfinished edits.
The service worker and manifest are revalidated rather than cached immutably.

Installation does not add sync or server storage. iOS and different browsers may
use separate storage for installed apps: export JSON before switching and import
it in the installed app if necessary. Keep exports as backups; uninstalling or
clearing browser data can erase a local journal. Tailscale is needed for initial
installation and updates, not for a fully cached offline journal.

## Build and updates

The private source input is pinned in `flake.nix` and `flake.lock`; evaluating
users need GitHub read access using their normal Git credential helper. No
credentials are embedded in the package. `packages/food-tracker.nix` builds the
existing UI in TanStack Start SPA mode, retaining the locked dependencies. Nix
provides Node/pnpm; Nginx serves only the resulting HTML, assets and fonts. No
development server or package downloads run at service startup.

To upgrade, change the source revision and package version, relock only
`food-tracker-src`, and regenerate the fixed dependency hash if its lock changes.
Build the real package privately and exercise the compiled site before applying
the configuration. Public CI replaces both the private input and package with
the explicit fixture through `scripts/ci/use-superlocal-stub.sh`, as it already
does for Superlocal. Never commit those CI substitutions or upload the real
private application build to the public Cachix cache.

After review, a separately authorized Kim rebuild activates Nginx and reconciles
Tailscale Serve. If required, approve `svc:food-tracker` and its host in the
Tailscale admin console. Verify the HTTPS page on a tailnet device, quick logging,
reload persistence and JSON export/import. This PR does not perform activation.
