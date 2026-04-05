{
  config,
  lib,
  currentSystemUser,
  pkgs,
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

  nix.gc = lib.mkIf config.nix.enable ({
      automatic = true;
      options = "--delete-older-than 30d";
    }
    // (
      if pkgs.stdenv.isDarwin
      then {
        interval = {
          Weekday = 0;
          Hour = 3;
          Minute = 0;
        };
      }
      else {
        dates = "weekly";
        persistent = true;
      }
    ));
}
