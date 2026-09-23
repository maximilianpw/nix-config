{
  currentSystemUser,
  isLinuxDesktop,
  lib,
  ...
}: {
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;

    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      # Also decrypt with the machine identity. Its public half is a second
      # recipient in .sops.yaml; the private host key never leaves Kim.
      sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    };

    secrets = {
      maxpw-password = {
        neededForUsers = true; # Decrypt early for user creation
      };
      borg-backup-passphrase = {
        # Readable by root only (borgbackup runs as root)
      };
      himalaya-bridge-password = {
        # Proton Bridge password for this host; read at runtime by himalaya,
        # which runs as the user, so it must be owned by the user (not root).
        owner = currentSystemUser;
      };
      linear-api-key = {
        owner = currentSystemUser;
        mode = "0400";
      };
      github-ssh-private-key = lib.mkIf (!isLinuxDesktop) {
        owner = currentSystemUser;
        mode = "0600";
      };
    };
  };
}
