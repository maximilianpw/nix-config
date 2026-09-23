{lib}: {
  # Substitute `@NAME@` markers in a file from an attrset of values. Evaluation
  # fails if any marker remains, including one added to the template but not to
  # `values`.
  render = path: values: let
    names = builtins.attrNames values;
    rendered =
      lib.replaceStrings (map (name: "@${name}@") names) (map (name: values.${name}) names)
      (builtins.readFile path);
    leftover = builtins.match ".*(@[A-Z][A-Z0-9_]*@).*" rendered;
  in
    assert lib.assertMsg (leftover == null)
    "${toString path} contains the unsubstituted marker ${builtins.head leftover}"; rendered;
}
