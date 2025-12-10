{lib, ...}: {
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    keep-outputs = true;
    keep-derivations = true;
    nix.settings.trusted-users = ["root" "max-vev"];
    trusted-users = ["root" "maxpw"];
  };
}
