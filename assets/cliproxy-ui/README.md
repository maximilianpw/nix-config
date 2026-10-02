# CLIProxy management UI

`management.html` is the single-file production build served by Nginx at
`https://cliproxy.maximilian.pw/management.html`. It uses the existing backend
and management key. No credentials are embedded in this artifact.

- Source: the `cliproxy-ui/` directory in the Fleet repository.
- Source commit: `b6544f4c05298883f92b1d2fbf8f2c46cd05ca7e`.
- Build version: `cliproxy-ui-b6544f4`.
- Artifact SHA-256: `ec33b5695b0a70b7b8438dde144be73ef057d73d401075dd42306e2316a9546d`.
- Upstream MIT license: `LICENSE` in this directory.

To update, commit the UI source, run `bun run verify` in `cliproxy-ui/`, then
build with `VERSION="cliproxy-ui-<source-commit>" bun run build`. Copy the
resulting `dist/index.html` over this directory's `management.html`, update
this provenance record and license as needed, and commit the artifact with
the Nix changes. Activate through the usual Nix rebuild. Nix generations
retain the previous artifact for rollback.

The backend's own management-panel updater does not control this Nginx-served
file. Inference requests and management API requests still use the existing
proxy routes in `homelab/cliproxyapi.nix`.
