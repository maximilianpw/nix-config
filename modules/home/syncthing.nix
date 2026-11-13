# Syncthing peer for the Mac, as a Home Manager launchd agent. On Kim,
# Syncthing is a NixOS system service (homelab/syncthing.nix).
#
# Sync is peer-to-peer (not via the Cloudflare tunnel): after the first build,
# open the local GUI at http://127.0.0.1:8384, add Kim as a remote device by
# its Device ID, and accept the share on Kim. overrideDevices/Folders are
# off so those manual pairings survive rebuilds.
_: {
  services.syncthing = {
    enable = true;
    overrideDevices = false;
    overrideFolders = false;
  };
}
