{
  lib,
  currentSystemUser,
  ...
}: {
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    auto-optimise-store = true;
    keep-outputs = true;
    keep-derivations = true;
    trusted-users = ["root"];
    allowed-users = ["root" currentSystemUser];
  };
}
