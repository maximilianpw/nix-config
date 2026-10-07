{
  config,
  inputs,
  lib,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit (homelab.endpoints) superlocal;
in {
  # The flake input's revision identifies the deployed source.
  custom.backup.applicationVersions.superlocal = "${config.services.superlocal.package.version}-${inputs.superlocal.shortRev or "dirty"}";

  services.superlocal = {
    enable = true;
    # Real mail; mailboxes and their app passwords are added in Settings and
    # stored encrypted in the state directory, never in Nix.
    mode = "real";
    # Tailscale Serve terminates HTTPS for this origin and proxies to the web
    # port; Superlocal's loopback mode accepts exactly one such ts.net origin.
    origin = superlocal.url;
    webPort = superlocal.port;
    # Internal loopback API behind the web port. It is not an inventory
    # endpoint, so keep it clear of the ports in lib/homelab-services.nix.
    apiPort = 19012;
  };
}
