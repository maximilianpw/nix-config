{
  lib,
  pkgs,
  herdr,
  package,
  home,
}: let
  activation = home.home.activation.linkHerdrJJ;
  expectedLink = "run ${lib.getExe herdr} plugin link ${package}/share/herdr-jj";
in
  assert builtins.elem package home.home.packages;
  assert builtins.elem herdr home.home.packages;
  assert builtins.elem "writeBoundary" activation.after;
  assert activation.data == expectedLink + "\n";
    pkgs.runCommand "herdr-config-regression" {} ''
      touch "$out"
    ''
