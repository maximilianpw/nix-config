# Amp self-hosted orbs on NixOS

The [Amp announcement](https://ampcode.com/news/self-hosted-orbs) and
[dispatch contract](https://ampcode.com/docs/orbs/self-hosted) describe a provider
that receives lifecycle jobs over outbound HTTPS. This repository implements
that contract with a NixOS service and Docker containers. No inbound listener,
public hostname, Cloudflare route, or Tailscale serve rule is needed.

## Configuration

Kim imports and enables `modules/amp-orb-provider` using its existing Docker
daemon. It waits for `/run/secrets/amp-orb-provider-token` before starting.
`machines/kim.nix` registers the SOPS secret automatically once the encrypted
`secrets/amp-orb-provider.yaml` file is present in the flake source; until then,
the configuration still evaluates without a dummy or plaintext token. This
checkout has not been activated just by editing it.

The reusable module remains opt-in on other x86_64 NixOS hosts:

```nix
{
  config,
  ...
}: {
  imports = [../modules/amp-orb-provider];

  services.amp-orb-provider = {
    enable = true;
    tokenFile = config.sops.secrets.amp-orb-provider-token.path;
    # Defaults, shown for capacity planning:
    cpus = "4";
    memory = "8g";
    pidsLimit = 2048;
    maxRunning = 4;
  };

  sops.secrets.amp-orb-provider-token = {
    sopsFile = ../secrets/amp-orb-provider.yaml;
    restartUnits = ["amp-orb-provider.service"];
  };
}
```

Paths above are relative to a file in `machines/`. The flake's existing
`pkgs.amp-cli` comes from the locked llm-agents input. The module enables Docker
but preserves the host's selected Docker package. It does not affect Darwin or
WSL hosts unless explicitly imported and enabled (x86_64 Linux is required).

`image = null` uses the `ORB_IMAGE` supplied by Amp. To use a reviewed immutable
image, set `services.amp-orb-provider.image` to a registry reference with a digest.
Orbs use Amp's glibc Linux image, **not a NixOS container**. Nix is not automatically
installed inside an orb; add project toolchains through `.agents/setup` or supply
a custom image meeting [Amp's image requirements](https://ampcode.com/docs/orbs/self-hosted#bring-your-own-image).
Never mount the host Nix daemon, Docker socket, or credentials into the orb.

## Register and provision the token (operator only)

1. Open [Amp workspace settings](https://ampcode.com/workspace), then
   **Settings → Orbs → Add Orb Provider**. Create a workspace first if needed.
   Choose a name such as `kim`. Copy the `aop_live_…` token, which is shown once.
2. From the repository, run `sops secrets/amp-orb-provider.yaml` and enter:

   ```yaml
   amp-orb-provider-token: <the provider token>
   ```

   Save through SOPS so only ciphertext reaches disk in the repository. The
   existing `.sops.yaml` creation rule encrypts for the admin and Kim. Do not
   create a plaintext YAML file first, use a Nix string/path for the token, put
   it in shell history, or send it to an agent/chat.
3. Run `git add secrets/amp-orb-provider.yaml` **after SOPS has encrypted it** so
   the new file is included in the Git-backed flake source. Kim's configuration
   already includes the provider enablement and conditional secret declaration;
   no additional Nix edit is needed. The default token path is
   `/run/secrets/amp-orb-provider-token`. The service is skipped while that file
   is absent, rather than connecting without authentication. Adding the runtime
   file alone does not retry a skipped unit: SOPS `restartUnits` or an explicit
   service start handles that.
4. Review and evaluate the configuration. Activation/rebuild is a separate,
   explicit operator action; building the flake does not start the provider.
5. After activation, inspect `systemctl status amp-orb-provider` and
   `journalctl -u amp-orb-provider -b`. If the token appeared after a skipped
   start, run `sudo systemctl start amp-orb-provider`.
6. Start a new Amp thread, open **Orb → Self-Hosted**, and select the provider.
   Amp should clone the repository, run `.agents/setup`, and connect the agent.
   From the CLI: `amp -ox "Check this repository" --orb-provider kim`.
7. Let the thread pause, then send another message. The same checkout should
   resume. Deleting a disposable test thread should remove only its container.

The raw token is read with systemd `LoadCredential` and exported only at runtime.
It is not embedded in a unit, Nix derivation, or container configuration. No
interactive `amp login` is needed for the provider service.

## Lifecycle, capacity, and security

- Containers are named `amp-orb-<ORB_ID>` and labeled
  `pw.maximilian.amp-orb-provider=true`. Dispatch refuses to touch a pre-existing
  container at that name without the ownership label.
- `spawn` starts an existing stopped container, or creates a new one. Bootstrap
  runs detached as the image's default user. An in-container `flock` prevents
  duplicate bootstrap processes on repeated spawn requests. `ORB_TOKEN` and
  optional `AMP_URL` are passed by environment name, not as secret argv values.
- `pause` stops the container, retaining its writable layer. When Amp supplies
  `ORB_SNAPSHOT_ID`, it also commits a local image under
  `amp-orb-provider/snapshot:<sha256-of-id>`. New orbs prefer that image when
  available; otherwise they use `ORB_IMAGE`. Snapshot IDs are opaque and never
  used as raw shell paths or Docker options.
- `delete` removes the owned container and its anonymous volumes. Shared project
  snapshot images remain available for other threads. Deleting an absent orb or
  pausing it is harmless; daemon/start/stop/commit failures are reported, not
  mistaken for missing state.
- Lifecycle operations are serialized; a job (including its lock wait) has a
  280-second timeout plus a 5-second kill grace. Slow image pulls or large
  snapshots can exceed this budget and need operator investigation.
- Each orb has CPU, memory, PID and log limits, applied when it is created;
  changing these settings does not rewrite existing containers. Orb logs explicitly
  use Docker's `json-file` driver with `max-size=10m` and `max-file=3`, independent
  of the daemon's default (`journald` on NixOS, which rejects these options).
  Swap is disabled for the orb. Docker restart policy is `no`, so sleeping orbs do
  not wake at host reboot. The provider resumes them on subsequent spawn jobs.
- The default limit allows four simultaneous orbs (up to 16 CPUs / 32 GiB), not
  unlimited resource use. Stopped disks and snapshot images **are not size- or
  count-bounded**. Monitor Docker's filesystem usage. `homelab.keep=true` marks
  these intentionally persistent containers; do not run broad prune/cleanup
  commands to manage them.
- The provider runs as a dedicated system user with a private state directory,
  but membership in the Docker group is **root-equivalent**. It is not a strong
  host security boundary. Containers have no host mounts, privileged mode,
  host networking, or published ports; Docker's default bridge still permits
  outbound access to the LAN. Use a separate VM/host and network policy before
  running untrusted repositories or sharing this provider broadly.

The provider and orbs need outbound access to Amp, its static assets and tunnel
endpoint, Git hosting, and the image registry. Self-hosting keeps checkouts and
disks local; it **does not keep all code local**: tool outputs, file contents
read by the agent, diffs, screenshots, and attachments still go to Amp. See
[What Leaves Your Network](https://ampcode.com/docs/orbs/self-hosted#what-leaves-your-network).

## State and recovery

- `/var/lib/amp-orb-provider`: private CLI config/cache and dispatch lock;
- Docker's data root: orb writable layers and project snapshot images;
- `secrets/amp-orb-provider.yaml`: encrypted provider credential;
- `/run/secrets/amp-orb-provider-token`: runtime decrypted credential.

Orb disks/snapshots are disposable development state, **not covered by the
homelab application recovery contract**. Push valuable commits to Git before
relying on them. Do not treat a Docker commit as a backup of mounted volumes.
Recreating the provider and token lets Amp start fresh orbs, but cannot recover
uncommitted work after loss of Docker's data root. Restore secrets only through
the repository's normal SOPS recovery procedure.

Stopping the provider does not stop running orbs. Disabling the NixOS service
also does not delete containers or images. Any cleanup of live orb state must be
reviewed and authorized separately, with exact owned container/image targets.

## Verification

```sh
bash scripts/tests/amp-orb-dispatch-test.sh
nix build .#checks.x86_64-linux.amp-orb-provider-regression --no-link
```

The regression uses a disposable Docker fixture, not the host daemon. It covers
create/repeat/resume/pause/delete, snapshot reuse and fallback, capacity limits,
ownership and ID validation, token forwarding, log-driver compatibility with a
`journald` daemon default, and failed Docker operations.
The Nix check evaluates opt-in behavior, credential loading and service wiring,
and builds the generated shell wrappers. A real Amp connection and container
bootstrap still require the operator smoke test above.
