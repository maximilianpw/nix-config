{pkgs}: {
  # SSH remote commands are parsed by the account login shell before any
  # interactive shell config can run. Fish can launch the `/bin/sh -c ...`
  # wrapper used by tools like Codex remote SSH; Nushell rejects that syntax.
  loginShell = pkgs.fish;
  interactiveShell = pkgs.nushell;

  sshKeys = {
    githubAuthentication = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSE4irNaEh8R1RxL0/839aKlA9KgdKIZl/uKgGCvMzs GitHub Authentication Key";
    mainPcUser = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB3qKWMhvPDxIo8U2S7VpC7eGtF5LATuGQ05gSlXmu+4 Main PC SSH";
    fleetMacbookToMainPc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO6WVItwXm6ybS0EbZY+URCvIqdhZMhj/cwU2d4RBDFl fleet main-pc from macbook-pro-m1";
  };
}
