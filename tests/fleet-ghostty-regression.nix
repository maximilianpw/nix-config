{
  config,
  lib,
  pkgs,
}: let
  systemPackages = config.environment.systemPackages;
in
  assert lib.assertMsg (lib.elem pkgs.ghostty.terminfo systemPackages)
  "Kim must install Ghostty's terminfo output so fleet ssh works with TERM=xterm-ghostty";
    pkgs.runCommand "fleet-ghostty-regression" {} ''
      touch "$out"
    ''
