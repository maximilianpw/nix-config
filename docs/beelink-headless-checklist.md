# Beelink → Headless Homelab: What You Have To Do

The config work is done. These are the remaining manual steps, in order.

## 1. Before rebuilding

- [ ] **Check for libvirt VMs you care about** (Docker stays; only the
      libvirtd/virt-manager stack is being removed):

  ```sh
  sudo virsh list --all
  ```

- [ ] **Commit the current config** so the rebuild generation maps to a clean
      commit you can return to:

  ```sh
  git add -A && git commit -m "main-pc: convert to headless homelab"
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
# Fleet SSH now goes through the 1Password agent — 1Password must be
# unlocked. Confirm it still reaches the box:
fleet ssh main-pc

# T3 Code forward still works
fleet t3 main-pc
```

If `Wake-on: g` did **not** stick, set it on the NetworkManager connection:

```sh
sudo nmcli connection modify <connection-name> 802-3-ethernet.wake-on-lan magic
```

## 5. Cleanup

- [ ] **Remove the legacy fleet SSH key from sops** (nothing references it
      anymore):

  ```sh
  sops secrets/secrets.yaml   # delete the fleet-main-pc-ssh-key entry
  ```

- [ ] **Test WoL once** before going fully headless — shut the box down and
      wake it from the Mac:

  ```sh
  # on the Mac (get the MAC address from `ip link show enp194s0` first)
  wakeonlan 78:55:36:02:58:77
  ```

- [ ] **Unplug monitor and keyboard.** Plug a monitor in *before* boot if you
      ever need a console — do not hotplug while running (DCN 3.5 display bug
      crashes the GPU driver).
