{pkgs}: {
  t3codeRelease = {
    version = "0.0.43-nightly.20260925.2237";
    darwinArm64Sha256 = "482205415f993cac771c653cfb3b7ea743843652eb22a50c4db142a60c48b7a8";
  };

  # SSH remote commands are parsed by the account login shell before any
  # interactive shell config can run. Fish can launch the `/bin/sh -c ...`
  # wrapper used by tools like Codex remote SSH; Nushell rejects that syntax.
  loginShell = pkgs.fish;
  interactiveShell = pkgs.nushell;

  sshKeys.githubAuthentication = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSE4irNaEh8R1RxL0/839aKlA9KgdKIZl/uKgGCvMzs GitHub Authentication Key";
}
