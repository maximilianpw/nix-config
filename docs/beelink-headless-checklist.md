# Beelink Headless Homelab Operations Checklist

The host is configured as a headless homelab. Use this checklist after hardware
changes, reinstallations, or recovery work.

## 1. Before rebuilding

- [ ] **Check for libvirt VMs you care about** (Docker stays; only the
      libvirtd/virt-manager stack is being removed):

  ```sh
  sudo virsh list --all
  ```

- [ ] **Keep the current config recoverable** so the rebuild generation maps
      to reviewed history you can return to. This checkout currently uses Git;
      inspect it before rebuilding.

  ```sh
  git status --short
  ```

## 2. BIOS settings (needs a reboot + monitor/keyboard one last time)

Reboot and hold `Del` to enter the BIOS:

- [ ] **Restore on AC Power Loss → Power On** — so the box comes back by
      itself after a power cut. This is the most important step.
- [ ] **Performance profile → Balanced/Quiet** — caps TDP for less heat,
      noise, and idle draw on a 24/7 box.
- [ ] **Wake on LAN → Enabled** (if the BIOS has the option).

## 3. Rebuild

```sh
make rebuild
```

Note: this switches kernels (zen → default) *and* strips the desktop stack in
one generation. If anything misbehaves:

```sh
make rollback
```

## 4. Verify after reboot

```sh
# Governor is schedutil (not powersave)
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Wake-on-LAN stuck ("Wake-on: g")
sudo ethtool enp194s0 | grep Wake

# Watchdog armed (should show 30s)
systemctl show -p RuntimeWatchdogUSec

# Wi-Fi/Bluetooth modules gone (no output = good)
lsmod | grep -E "iwlwifi|btusb"

# TRIM + SMART timers/services present
systemctl status fstrim.timer smartd

# Homelab services up
systemctl status nextcloud-setup home-assistant miniflux uptime-kuma

# Docker back with the old containers/volumes intact
docker ps -a && docker volume ls

# Ollama and the T3 Code user service running
systemctl status ollama
systemctl --user status t3code
```

From the MacBook:

```sh
# Confirm fleet SSH still reaches the box:
fleet ssh main-pc

# T3 Code forward still works
fleet t3 main-pc

# Tailnet-only desktop endpoint responds over HTTPS
curl --fail https://t3code.tail7161c3.ts.net/.well-known/t3/environment
```

If `Wake-on: g` did **not** stick, set it on the NetworkManager connection:

```sh
sudo nmcli connection modify <connection-name> 802-3-ethernet.wake-on-lan magic
```

## 5. Cleanup

- [ ] Run `sudo borg-job-main list` and stage a small restore with
      `borg-restore-main`; do not restore over live service paths.
- [ ] Verify both the Paperless export and PostgreSQL dump exist in the staged
      archive.
- [ ] Confirm the independent offline Age recipient and off-site Borg copy
      described in `docs/config-ownership-and-recovery.md` are current.

- [ ] **Test WoL once** before going fully headless — shut the box down and
      wake it from the Mac:

  ```sh
  # on the Mac (get the MAC address from `ip link show enp194s0` first)
  wakeonlan 78:55:36:02:58:77
  ```

- [ ] **Unplug monitor and keyboard.** Plug a monitor in *before* boot if you
      ever need a console — do not hotplug while running (DCN 3.5 display bug
      crashes the GPU driver).
