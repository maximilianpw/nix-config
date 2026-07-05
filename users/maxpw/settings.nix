{pkgs}: {
  # SSH remote commands are parsed by the account login shell before any
  # interactive shell config can run. Fish can launch the `/bin/sh -c ...`
  # wrapper used by tools like Codex remote SSH; Nushell rejects that syntax.
  loginShell = pkgs.fish;
  interactiveShell = pkgs.nushell;
}
