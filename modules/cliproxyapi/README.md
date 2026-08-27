# CLIProxyAPI

This folder owns the local CLIProxyAPI gateway and the agent clients that use it.

- `config.nix` is the shared endpoint, authentication, model, and server configuration.
- `nixos.nix` installs the Linux package and runs the systemd service on NixOS and WSL.
- `darwin.nix` installs the Homebrew formula and runs the nix-darwin LaunchAgent.
- `home-manager.nix` generates the Claude, Codex, Grok, and OpenCode client adapters, their direct-access commands, and `cliproxyapi-util`. Its caller supplies the user's agent-config directory explicitly.

Both server adapters render `/run/secrets/rendered/cliproxyapi.conf` through the shared `config.nix` function. They differ only in platform paths, package ownership, process management, and logging. The OpenCode base configuration lives at `users/maxpw/agents/opencode/cliproxyapi.json`; Home Manager injects the shared endpoint and credentials when it generates the deployed `opencode.json`.

Provider OAuth credentials remain mutable state in `~/.cli-proxy-api`. The OpenCode Zen key comes from `secrets/secrets.yaml`, and its Chat Completions models are exposed under the `zen/` prefix. The Linux package definition remains in `packages/cliproxyapi.nix`.

Pi's dynamic model discovery and quota client are implemented in the separate `~/pi-config` repository and linked into `~/.pi/agent` by `users/maxpw/modules/agent-tools.nix`. The installed `cliproxyapi-util quota --json` command runs that shared client and reports deterministic availability for Codex, Claude, and Grok.
