# Beelink SER9 (main-pc) Hardware Issues

## AMD Radeon 880M/890M — DCN 3.5 Display Controller Bug

**Problem:** The GPU's display controller (`optc35_disable_crtc`) times out whenever the display pipeline is power-cycled. This causes Hyprland to crash (SIGABRT in `CHyprRenderer::renderMonitor` → `CAsyncResourceGatherer::asyncAssetSpinLock`), followed by `hyprland-dialog` also crashing, the greeter failing ("greeter exited without creating a session"), and greetd auto-rebooting the system.

**Kernel errors:**
```
amdgpu 0000:c5:00.0: [drm] REG_WAIT timeout 1us * 100000 tries - optc35_disable_crtc line:162
amdgpu 0000:c5:00.0: [drm] REG_WAIT timeout 1us * 100000 tries - optc35_disable_crtc line:165
```

**All three approaches crash the GPU:**
1. `hyprctl dispatch dpms off/on` — DPMS power signaling
2. `hyprctl keyword monitor ,disable` / `,preferred,auto,1.6` — monitor hotplug
3. `systemctl hibernate` → resume — hibernate/resume cycle

**Note:** These `optc35_disable_crtc` errors also appear during every fresh boot (during `fbcon` initialization), but don't cause issues there since Hyprland hasn't started yet.

## Broken S2idle Firmware

The Beelink SER9 has broken s2idle (S0 idle / Modern Standby) firmware. The kernel reports `Low-power S0 idle used by default for system suspend` but it doesn't work reliably. The config comment says "broken s2idle firmware".

**Current config:** `SuspendState=disk` + `HibernateMode=shutdown` in `machines/main-pc.nix`, but systemd rejects this: `Sleep state 'disk' is not supported by operation suspend, ignoring.`

## Combined Result: No Sleep Mode Works

- s2idle: broken firmware
- Suspend-to-RAM: not available (redirected to hibernate via `SuspendState=disk`, which is rejected)
- Hibernate: crashes the AMD GPU display controller on resume
- DPMS off/on: crashes the AMD GPU display controller
- Monitor disable/enable: crashes the AMD GPU display controller

**Current workaround (2026-03-04):** All idle display/sleep actions removed from hypridle on main-pc. The system stays fully on until manually shut down. The `network-resume` service was also fixed (`|| true` on `modprobe -r snd_usb_audio`) so it no longer fails when the audio module is busy.

## Potential Future Fixes

- Newer kernel versions may have DCN 3.5 driver fixes
- `amdgpu.dcdebugmask=0x10` kernel parameter reported to help with some DCN issues
- Bug report at https://gitlab.freedesktop.org/drm/amd/-/issues with `optc35_disable_crtc` traces
- Monitor hardware-level auto-sleep (via OSD settings) may work since it doesn't involve the GPU's display controller code path
