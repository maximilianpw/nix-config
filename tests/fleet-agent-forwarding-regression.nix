{
  lib,
  pkgs,
}: let
  fleet = import ../lib/fleet.nix {
    hostname = "joyce";
    homeDirectory = "/Users/max-vev";
    inherit lib pkgs;
  };
  blocks = builtins.attrValues fleet.sshSettings;
in
  assert lib.assertMsg (blocks != [])
  "Fleet agent-forwarding regression requires at least one remote SSH block";
  assert lib.assertMsg (lib.all (block: block.ForwardAgent == "no") blocks)
  "Fleet must disable SSH agent forwarding in plain, tmux, and forwarding blocks by default";
  assert lib.assertMsg (lib.all (block: !(block ? LocalForward)) blocks)
  "Fleet must keep on-demand service forwards out of ordinary SSH blocks";
    pkgs.runCommand "fleet-agent-forwarding-regression" {} ''
      touch "$out"
    ''
