{pkgs}: {
  t3codeRelease = {
    version = "0.0.46-nightly.20261003.2610";
    darwinArm64Sha256 = "e2a42be013107210cd18aacc6c4a435e60faf61289988ca0b9f6c392a24477a6";
  };

  # SSH remote commands are parsed by the account login shell before any
  # interactive shell config can run. Fish can launch the `/bin/sh -c ...`
  # wrapper used by tools like Codex remote SSH; Nushell rejects that syntax.
  loginShell = pkgs.fish;
  interactiveShell = pkgs.nushell;

  sshKeys.githubAuthentication = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSE4irNaEh8R1RxL0/839aKlA9KgdKIZl/uKgGCvMzs GitHub Authentication Key";
}
