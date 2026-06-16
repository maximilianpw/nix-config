# Syncthing peer for macOS "consuming" devices.
#
# On main-pc, Syncthing runs as a NixOS *system* service (homelab/syncthing.nix).
# On the Mac there's no such system service, so we run it per-user via Home
# Manager (launchd agent). This module is imported on every host but only
# activates on Darwin, so it never collides with the main-pc system service.
#
# Sync is peer-to-peer (not via the Cloudflare tunnel): after the first build,
# open the local GUI at http://127.0.0.1:8384, add main-pc as a remote device by
# its Device ID, and accept the share on main-pc. overrideDevices/Folders are
# off so those manual pairings survive rebuilds.
{isDarwin, ...}: {
  services.syncthing = {
    enable = isDarwin;
    overrideDevices = false;
    overrideFolders = false;
  };
}
