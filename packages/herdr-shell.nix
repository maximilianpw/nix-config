# Herdr's default pane shell. herdr, fleet and fish resolve from PATH.
{
  jq,
  writeShellApplication,
}:
writeShellApplication {
  name = "herdr-shell";
  runtimeInputs = [jq];
  # A failed workspace lookup must fall through to `exec fish`, not abort.
  bashOptions = [];
  text = builtins.readFile ./scripts/herdr-shell.sh;
}
