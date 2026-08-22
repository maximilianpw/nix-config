{pkgs}: {
  cliProxy = rec {
    host = "127.0.0.1";
    port = 8317;
    baseUrl = "http://${host}:${toString port}";
    apiKey = "cliproxyapi-local-claudex";
    managementKeyHash = "$2b$12$NjrcwG.5nSCnzZRK0lAwAOTw0eDr.5PP1rVfd3q.YEdss3IHwP8CC";
    model = "gpt-5.6-sol";
  };

  t3codeRelease = {
    version = "0.0.32-nightly.20260731.966";
    darwinArm64Sha256 = "3b8ae151ec27d0dc551f95c662b99a676f614198c70727a79d1a4c8980d2c014";
  };

  # SSH remote commands are parsed by the account login shell before any
  # interactive shell config can run. Fish can launch the `/bin/sh -c ...`
  # wrapper used by tools like Codex remote SSH; Nushell rejects that syntax.
  loginShell = pkgs.fish;
  interactiveShell = pkgs.nushell;

  sshKeys.githubAuthentication = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSE4irNaEh8R1RxL0/839aKlA9KgdKIZl/uKgGCvMzs GitHub Authentication Key";
}
