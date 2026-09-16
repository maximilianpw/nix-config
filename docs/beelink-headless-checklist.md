# Kim headless operations checklist

Use this checklist after a hardware change, reinstall, recovery, or explicitly
approved system activation.

## Hardware constraints

Kim's Beelink SER9 firmware does not provide reliable s2idle. The AMD DCN 3.5
display controller also times out when Hyprland power-cycles or hotplugs the
display, and the same failure has occurred after hibernation. Kim therefore has
no supported sleep, hibernate, DPMS, or live monitor-hotplug workflow.

- Keep the host running or shut it down fully.
- If a local console is needed, connect the monitor before boot. Do not hotplug
  it while the graphical profile is running.
- Monitor hardware auto-sleep is safe to test because it does not ask the GPU
  driver to disable and re-enable the display pipeline.
- Reassess only after a kernel or firmware change, using a local console and a
  recoverable generation.

Relevant kernel errors contain `optc35_disable_crtc` timeouts. The workaround
is operational; do not add an unverified kernel parameter to a routine rebuild.

## BIOS settings

Enter the BIOS with `Del` and confirm:

- Restore on AC power loss is set to Power On.
- The performance profile is Balanced or Quiet for 24/7 use.
- Wake on LAN is enabled when the firmware exposes it.

## Post-boot verification

Run read-only checks first:

```sh
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
sudo ethtool enp194s0 | grep Wake
systemctl show -p RuntimeWatchdogUSec
systemctl status fstrim.timer smartd
sudo homelab-check
systemctl --failed
systemctl --user status t3code
```

Use the archive-aware check only when attaching the backup automount is
intentional:

```sh
sudo env HOMELAB_CHECK_ARCHIVE=1 homelab-check
```

From Joyce, confirm the declared remote-development paths:

```sh
fleet run kim true
fleet t3 kim
curl --fail https://t3code.liger-shilling.ts.net/.well-known/t3/environment
```

If Wake on LAN is not set to `g`, update the reviewed NetworkManager connection
and test one complete shutdown and wake cycle before removing local input and
display hardware.

## Recovery readiness

- List the latest archive with `sudo borg-job-main list`, then inspect it with
  `sudo homelab-backup-inspect <archive>`.
- Stage restores only through `borg-restore-main` into an existing empty
  directory. Never restore over live service paths.
- Confirm the manifest, PostgreSQL dumps, transformed Home Assistant and T3
  Code archives, Paperless export and pending files, Nextcloud, Uptime Kuma,
  Vaultwarden, and the archived configuration checkout are present.
- Confirm the latest quarterly record under `docs/restore-drills/` follows the
  [recovery runbook](homelab-recovery.md) and also exists outside Kim.
- Track the independent Age identity, off-site Borg copy, and external alert
  delivery in the [homelab backlog](homelab-backlog.md).
