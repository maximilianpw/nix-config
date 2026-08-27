{
  currentSystemUser,
  isDarwin,
  ...
}: let
  homeDirectory =
    if isDarwin
    then "/Users/${currentSystemUser}"
    else "/home/${currentSystemUser}";
in {
  # Workstations restore the shared admin identity from 1Password before the
  # first rebuild. It is also used by Home Manager for user-scoped secrets.
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "${homeDirectory}/.config/sops/age/keys.txt";
  };
}
