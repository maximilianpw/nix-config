{lib}: {
  # Assert a list of conditions under one message, naming which ones failed
  # (1-based positions) instead of reporting the whole chain as false.
  all = message: conditions: let
    failed = lib.filter (i: !(builtins.elemAt conditions (i - 1))) (lib.range 1 (builtins.length conditions));
  in
    lib.assertMsg (failed == [])
    "${message} (failed conditions ${lib.concatMapStringsSep ", " toString failed} of ${toString (builtins.length conditions)})";
}
