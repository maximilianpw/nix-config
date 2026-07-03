# Plan 008: Adopt nixos-hardware AMD profiles for main-pc and reconcile with hand-tuning

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat b31e6af..HEAD -- flake.nix flake.lock lib/mksystem.nix machines/main-pc.nix`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: MED (kernel-parameter changes on real hardware; eval-verifiable before switching)
- **Depends on**: plans/004-lint-format-gate.md (both edit `flake.nix`/`flake.lock`; run after to avoid conflicts — 002 also touches flake.nix)
- **Category**: direction
- **Planned at**: commit `b31e6af`, 2026-07-03

## Why this matters

main-pc (Beelink SER9, AMD Ryzen + integrated AMD GPU) hand-writes its AMD
tuning. The `nixos-hardware` community flake maintains tested profiles
(`common-cpu-amd`, `common-cpu-amd-pstate`, `common-gpu-amd`, `common-pc-ssd`)
that track kernel/AMD changes so this repo doesn't have to. Adopting them
keeps future AMD enablement maintained upstream. The catch: the existing
hand-tuning must win where it's deliberate — notably `amd_pstate=guided`
(the pstate profile may set a different mode) and the hibernate-related
settings, which exist because the SER9's s2idle is broken.

## Current state

- `machines/main-pc.nix:18-21` — hand-tuning:
  ```nix
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";
  services.power-profiles-daemon.enable = lib.mkDefault true;
  ```
- `machines/main-pc.nix:25-31` — zen kernel, `amd_pmc` module,
  `kernelParams = ["amd_pstate=guided" "resume=UUID=..."]`.
- `machines/main-pc.nix:40-45` — suspend disabled, hibernate only (broken
  s2idle on the SER9). Do not let any imported profile re-enable suspend.
- `machines/hardware/main-pc.nix:45` — microcode already conditioned on
  redistributable firmware (generated file; do not edit).
- `flake.nix:4-34` — inputs block; convention for module-only inputs: no
  `follows` needed (nixos-hardware has no nixpkgs input of consequence).
- **Wiring constraint**: `lib/mksystem.nix` injects `inputs` via
  `config._module.args` (line 71-73), which CANNOT be used inside a module's
  `imports` (infinite recursion). The nixos-hardware modules must therefore be
  added to the module list in `mksystem.nix`/`flake.nix`, not imported from
  `machines/main-pc.nix`. `mkSystem` currently takes
  `{ system, user, userDir?, darwin?, wsl? }` (mksystem.nix:5-13) and builds
  the module list at lines 47-74.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Eval check | `nix flake check --no-build` | exit 0 |
| Inspect resulting kernel params | `nix eval .#nixosConfigurations.main-pc.config.boot.kernelParams` | list containing `"amd_pstate=guided"` exactly once, no conflicting `amd_pstate=` value |
| Inspect governor | `nix eval .#nixosConfigurations.main-pc.config.powerManagement.cpuFreqGovernor` | `"schedutil"` |
| List profile contents | read files under the flake input source: `nix flake metadata --json \| jq -r '.locks.nodes["nixos-hardware"].locked'` then read `common/cpu/amd/*` in the store path | — |

## Scope

**In scope**:
- `flake.nix` (add input; pass extra modules for main-pc)
- `flake.lock` (new input only)
- `lib/mksystem.nix` (add an `extraModules ? []` parameter)
- `machines/main-pc.nix` (only if reconciliation requires `lib.mkForce` or removing a now-redundant line)

**Out of scope**:
- `machines/hardware/main-pc.nix` — generated, never edit.
- The systemd sleep settings (main-pc.nix:40-45) and the network-resume unit — hardware workarounds, keep verbatim.
- wsl and darwin configs.

## Git workflow

- Branch: `advisor/008-nixos-hardware`
- Commit style: `feat: adopt nixos-hardware AMD profiles for main-pc`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add the input and an extraModules seam

`flake.nix` inputs:

```nix
nixos-hardware.url = "github:NixOS/nixos-hardware";
```

`lib/mksystem.nix`: add `extraModules ? [],` to the second argument set
(after `wsl ? false,`) and append `++ extraModules` to the `modules` list
(after the final `[ ... ]` block at line 56-74).

`flake.nix` main-pc call site (lines 82-85):

```nix
nixosConfigurations.main-pc = mkSystem "main-pc" {
  system = "x86_64-linux";
  user = "maxpw";
  extraModules = with inputs.nixos-hardware.nixosModules; [
    common-cpu-amd
    common-cpu-amd-pstate
    common-gpu-amd
    common-pc-ssd
  ];
};
```

Run `nix flake lock`, then `alejandra flake.nix lib/mksystem.nix`.

**Verify**: `nix flake check --no-build` → exit 0.

### Step 2: Reconcile profile settings against hand-tuning

Read the four profile files in the nixos-hardware store path (see command
table) and compare with main-pc.nix. Resolve so the *effective config* keeps
the deliberate choices:

1. `nix eval .#nixosConfigurations.main-pc.config.boot.kernelParams` — must
   contain `amd_pstate=guided` and must NOT also contain `amd_pstate=active`
   (or any second `amd_pstate=` value). If the pstate profile injects one,
   either drop `common-cpu-amd-pstate` from the list (preferred — the local
   param already covers it) or `lib.mkForce` the local list.
2. `powerManagement.cpuFreqGovernor` must remain `"schedutil"` — the local
   `lib.mkDefault` (main-pc.nix:20) loses to any profile setting a plain
   value; upgrade the local one to a plain assignment (drop `mkDefault`) if
   the eval shows a different governor.
3. `hardware.cpu.amd.updateMicrocode` — now set by both; if redundant,
   remove the local line (main-pc.nix:19) and note it in the commit message.
4. `nix eval .#nixosConfigurations.main-pc.config.systemd.sleep.extraConfig`
   or the corresponding settings — confirm the AllowSuspend=no block is
   unchanged.

**Verify**: all four eval checks above show the deliberate values.

### Step 3: Apply on main-pc

`make rebuild` on main-pc (or `fleet run main-pc -- make -C ~/nix-config rebuild`
after syncing the branch there). After reboot or at least after switch:

```sh
cat /sys/devices/system/cpu/amd_pstate/status   # → "guided"
```

**Verify**: pstate status is `guided`; system boots and the desktop session works.

## Test plan

Eval assertions in Step 2 are the pre-merge tests; Step 3 is the hardware
test. Record the pstate status output in the completion report.

## Done criteria

- [ ] `nix flake check --no-build` → exit 0
- [ ] `mkSystem` has an `extraModules` parameter; main-pc passes nixos-hardware profiles
- [ ] Kernel params contain exactly one `amd_pstate=` entry with value `guided`
- [ ] Governor is `schedutil`; suspend remains disabled (sleep settings unchanged)
- [ ] After switch on main-pc: `/sys/devices/system/cpu/amd_pstate/status` → `guided`
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- Module names differ (e.g. `common-cpu-amd-pstate` doesn't exist in the
  fetched nixos-hardware) — list what exists under `common/cpu/amd/` and
  report; do not guess substitutes.
- Reconciliation requires touching the sleep/hibernate settings.
- After switch, the machine fails to reach the desktop or suspend behavior
  changes — `make rollback`, report.

## Maintenance notes

- nixos-hardware tracks master (no follows); `make update` will bump it —
  regressions would arrive via flake updates, and `git bisect`/input pinning
  is the rollback path.
- The new `extraModules` seam is generally useful (e.g. future disko or
  lanzaboote adoption uses the same hook) — mention in review.
