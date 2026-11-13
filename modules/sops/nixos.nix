{
  config,
  currentSystemUser,
  lib,
  ...
}: {
  options.custom.sops.keySource = lib.mkOption {
    type = lib.types.enum ["host" "user"];
    description = "Age identity for system secrets: the host's own key, or the admin key restored from 1Password.";
  };

  config.sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age =
      if config.custom.sops.keySource == "host"
      then {
        keyFile = "/var/lib/sops-nix/key.txt";
        # Also decrypt with the machine identity. Its public half is a second
        # recipient in .sops.yaml; the private host key never leaves Kim.
        sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
      }
      else {
        keyFile = "/home/${currentSystemUser}/.config/sops/age/keys.txt";
      };
  };
}
