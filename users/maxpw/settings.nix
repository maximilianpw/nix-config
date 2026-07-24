{pkgs}: {
  cliProxy = rec {
    host = "127.0.0.1";
    port = 8317;
    baseUrl = "http://${host}:${toString port}";
    apiKey = "cliproxyapi-local-claudex";
    model = "gpt-5.6-sol";
  };

  t3codeRelease = {
    version = "0.0.29-nightly.20260724.893";
    darwinArm64Sha256 = "3a0cb7701de292a2815e736e036af1ffb3064b26349cb13404c1a6749de630be";
  };

  # SSH remote commands are parsed by the account login shell before any
  # interactive shell config can run. Fish can launch the `/bin/sh -c ...`
  # wrapper used by tools like Codex remote SSH; Nushell rejects that syntax.
  loginShell = pkgs.fish;
  interactiveShell = pkgs.nushell;

  sshKeys = {
    githubAuthentication = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSE4irNaEh8R1RxL0/839aKlA9KgdKIZl/uKgGCvMzs GitHub Authentication Key";
    kimUser = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB3qKWMhvPDxIo8U2S7VpC7eGtF5LATuGQ05gSlXmu+4 Kim SSH";
    fleetJoyceToKim = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO6WVItwXm6ybS0EbZY+URCvIqdhZMhj/cwU2d4RBDFl fleet kim from joyce";
    # Paste Cuno's public key here after generating it with:
    #   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "cuno-to-kim"
    cunoToKim = "";
  };
}
