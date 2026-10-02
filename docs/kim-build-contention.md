# Kim build contention and Nix daemon scheduler weights

Decision record for how Nix builds on Kim share the CPU with interactive
sessions and homelab services. The measurement below is the evidence; the
setting it justifies lives in `machines/kim.nix` and is pinned by
`tests/monitoring-regression.nix`.

## Question

Kim runs the homelab, the T3 Code server, and every `nixos-rebuild` for itself.
Does a build degrade interactive work or service response enough to justify
limiting the Nix daemon, and if so, with what mechanism?

## Method

Measured on Kim as configured before this change: 24 cores, 58 GB RAM, Nix
`max-jobs = 24` and `cores = 0`, and no resource directives on
`nix-daemon.service` or the user `t3code-server.service`.

- Baseline: 10 samples at 4 s intervals with the machine idle.
- Build: `nix build --rebuild --no-link nixpkgs#git`, a 128 s compile, with
  24 samples during the build and 6 after it finished.
- Each sample recorded the 1-minute load average, CPU idle percent from `top`,
  `MemAvailable`, the wall time of `nix eval --expr '1+1'` as an
  interactive-latency proxy, and the loopback HTTP time to Grafana
  `/api/health` on `127.0.0.1:3000` as a homelab-service proxy.
- A second service probe against port 8082 had no listener and is discarded.

## Results

| phase | samples | load1 median / max | CPU idle % median / min | MemAvailable min (GB) | nix eval ms median / p95 | Grafana ms median / max |
| --- | --- | --- | --- | --- | --- | --- |
| baseline | 10 | 0.7 / 0.8 | 97.8 / 94.6 | 46.1 | 20 / 24 | 0 / 1 |
| build | 24 | 9.8 / 20.9 | 8.3 / 0.7 | 42.9 | 32 / 57 | 0 / 1 |
| recovery | 6 | 13.4 / 17.5 | 98.0 / 93.8 | 47.4 | 22 / 22 | 0 / 0 |

## Interpretation

One ordinary compile drove CPU idle to a median of 8 percent and a minimum
below 1 percent for the build. Memory headroom stayed large (over 42 GB
available at the worst point). The trivial evaluation used as a latency proxy
grew about 1.6x at the median and under 3x at p95. The single sampled
service endpoint showed no increase at millisecond resolution.

So the CPU is contended during a build, while memory is not. The two proxies
are narrow: neither T3 Code responsiveness nor homelab workload latency was
measured. That supports a provisional preference that only acts when the CPU
is contended, rather than a cap that also applies to an idle machine.

## Decision

`machines/kim.nix` sets `CPUWeight = 50` and `IOWeight = 50` on
`nix-daemon.service`, half of systemd's default weight of 100.

- Weights are relative preferences within one cgroup level, not allocation
  guarantees. They only matter when a resource is oversubscribed, so an idle
  machine should still give the daemon every core; build time after the change
  has not been measured.
- `nix-daemon.service` lives in `system.slice`, so the weight lowers the build's
  share against other system services such as the homelab containers and
  Grafana. Interactive sessions sit in `user.slice`, a sibling of
  `system.slice` at the root, and are affected only indirectly. Local builds
  spawned by the daemon stay in its cgroup; client-side evaluation does not.
- `IOWeight` takes effect only where the block layer honours proportional
  weights (the `io.cost` or BFQ controllers). It is set for consistency and its
  effect on Kim's NVMe devices is unverified.
- Rejected for now: `CPUQuota`, `MemoryMax`, or lowering `max-jobs`/`cores` in
  `modules/core/nix-settings.nix`. A quota or lower job count limits a build
  regardless of other demand, and the measurement shows no memory pressure.
- Rejected for now: resource directives on the T3 Code user service. Whether
  the daemon weight alone is enough is untested; revisit if T3 responsiveness
  degrades during builds.

The weights are applied only when Kim is next switched to a generation that
includes them; evaluating or building the configuration does not change the
running daemon.

## Not measured

- A real `nixos-rebuild` with many parallel derivations rather than one
  compile. The build phase here is a single derivation at `max-jobs = 24`.
- Docker workloads running alongside a build.
- Sustained multi-hour builds, where thermal limits or memory growth could
  change the picture.
- Disk-heavy builds. IO was not measured directly; `IOWeight` is set alongside
  `CPUWeight` for consistency, not from a measured IO result.
- The user-facing T3 Code server itself; Grafana over loopback was the only
  service proxy with a listener.

## When to revisit

- Interactive latency or service response visibly degrades during a build
  after this change is active. Rerun the method above with the weights applied
  and compare against this table.
- A future measurement shows memory pressure (`MemAvailable` approaching the
  working set of the homelab services). Weights do not help there; that would
  be the point to consider `MemoryHigh` on the daemon.
- `max-jobs` or `cores` change in `modules/core/nix-settings.nix`, or Kim's
  core count changes.
