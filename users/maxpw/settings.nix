{pkgs}: {
  t3codeRelease = {
    version = "0.0.45-nightly.20260930.2481";
    darwinArm64Sha256 = "57beeb20878b09c9d61c11b9a45e74a506840d4189254f39755ceb94ea37f14e";
  };

  # SSH remote commands are parsed by the account login shell before any
  # interactive shell config can run. Fish can launch the `/bin/sh -c ...`
  # wrapper used by tools like Codex remote SSH; Nushell rejects that syntax.
  loginShell = pkgs.fish;
  interactiveShell = pkgs.nushell;

  sshKeys.githubAuthentication = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSE4irNaEh8R1RxL0/839aKlA9KgdKIZl/uKgGCvMzs GitHub Authentication Key";
}
