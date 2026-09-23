{
  lib,
  pkgs,
}: let
  template = import ../lib/template.nix {inherit lib;};
  fixture = builtins.toFile "template-fixture" "run @TOOL@ --flag @MODE@ for user@example.com\n";
  renders = values: builtins.tryEval (builtins.deepSeq (template.render fixture values) true);
in
  assert lib.assertMsg (template.render fixture {
      TOOL = "/bin/tool";
      MODE = "fast";
    }
    == "run /bin/tool --flag fast for user@example.com\n")
  "template.render must substitute every declared marker";
  assert lib.assertMsg (!(renders {TOOL = "/bin/tool";}).success)
  "template.render must reject a marker that has no value";
    pkgs.runCommand "template-regression" {} ''
      touch "$out"
    ''
