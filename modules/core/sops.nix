{
  config,
  lib,
  ...
}: {
  # Configure sops-nix
  sops = {
    # Default sops file location
    defaultSopsFile = ../../secrets/secrets.yaml;

    # Age key file location (will be read from ~/.config/sops/age/keys.txt on the system)
    age = {
      # This will be the path on the system where the age key is located
      keyFile = "/var/lib/sops-nix/key.txt";
      # Alternatively, for per-user keys:
      # keyFile = "/home/${config.users.users.maxpw.name}/.config/sops/age/keys.txt";
    };

    # Define secrets to decrypt
    secrets = {
      maxpw-password = {
        neededForUsers = true; # Decrypt early for user creation
      };
      nextcloud-admin-password = {
        owner = "nextcloud";
        group = "nextcloud";
      };
      borg-backup-passphrase = {
        # Readable by root only (borgbackup runs as root)
      };
    };
  };
}
