{lib, ...}: {
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    keep-outputs = true;
    keep-derivations = true;
    trusted-users = ["root" "maxpw"];
  };
}
