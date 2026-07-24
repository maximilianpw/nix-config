# Upstream Buzz Issue Draft

Target: [`block/buzz`](https://github.com/block/buzz)

Status: draft for review; not published

## Proposed title

RFC: community-maintained Nix packages for Buzz agent tooling

## Proposed body

### Summary

Would the maintainers be open to a community-maintained Nix integration focused
on Buzz's agent-facing Rust binaries?

I am evaluating a private Buzz deployment on NixOS. The official OCI image and
Compose/Helm assets already provide a sensible server deployment boundary, so I
am not proposing to replace them or add a Buzz-specific NixOS service module.
The gap for this deployment is installing the agent tooling reproducibly on
NixOS and other Nix-managed development machines.

### Current state

As of July 2026:

- Contributor tooling is provided through Hermit, with a manually managed
  Rust/Node/pnpm/`just` toolchain as the alternative.
- Linux desktop releases are distributed as `.AppImage` and `.deb` packages,
  with the agent executables bundled as Tauri sidecars.
- The agent-facing executables are not published as standalone release
  artifacts.
- The repository has no `flake.nix`, Nix package expressions, or existing
  Nix/NixOS issue or pull request that I could find.

NixOS can already run a relay from an OCI image pinned by digest. The remaining
friction is getting these tools from the Rust workspace onto agent hosts:

- `buzz-cli`
- `buzz-acp`
- `buzz-agent`
- `buzz-dev-mcp`

### Proposed initial scope

I would be happy to prototype and maintain a small, optional flake that:

1. Builds only the four agent-facing Rust packages above from the pinned
   workspace source and `Cargo.lock`.
2. Exposes conventional `packages` outputs and a `nix run` entry point for
   `buzz-cli`.
3. Starts with `x86_64-linux`, then adds other platforms only after their builds
   are validated.
4. Adds a lightweight flake check for the supported package outputs.
5. Coexists with Hermit rather than replacing the documented contributor
   workflow.

A Nix development shell could be considered separately after the package
boundary is working. It does not need to be part of the first contribution.

### Explicit non-goals

The initial work would not:

- Package the Tauri desktop application.
- Replace the official OCI, Compose, or Helm deployment paths.
- Add or maintain a bespoke NixOS module for the relay.
- Re-express Postgres, Redis, MinIO, or the production topology as native NixOS
  services.
- Require existing contributors to install or use Nix.

### Why ask upstream first?

An in-repository flake can track Buzz's workspace membership, Rust version, and
locked dependencies in the same change that updates them. It would also make
the CLI directly available through a command such as:

```text
nix run github:block/buzz#buzz-cli
```

However, carrying the packaging downstream may be preferable while Buzz is
moving quickly. I would rather follow the maintainers' preferred ownership and
CI boundary before preparing a pull request.

### Maintainer guidance requested

1. Would you accept an optional, community-maintained `flake.nix` and
   `flake.lock` with the narrow scope above?
2. Would you prefer that this remain in a separate downstream repository until
   Buzz's agent tooling stabilizes?
3. Are the four proposed binaries the right initial boundary, or should they be
   split or expanded?
4. Which platforms, if any, would you expect an in-repository flake to support
   in CI?
5. Would standalone upstream binary release artifacts be a better long-term
   integration boundary than building these tools from source with Nix?

If the in-repository direction is welcome, I can follow up with a focused PR
and take responsibility for the initial packaging updates.

## Adaptation notes

These notes are not intended to be included in the GitHub issue:

- The personal deployment proposal remains the source of truth for the
  `kim`, Tailscale Serve, sops-nix, Compose, and Borg design.
- Those deployment details were deliberately removed from the upstream issue
  because they do not require changes or maintenance from Buzz.
- Native desktop packaging and a NixOS relay module were excluded to keep the
  first upstream request small enough to accept and maintain.
