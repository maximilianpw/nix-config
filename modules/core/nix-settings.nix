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
    substituters = [
      "https://cache.nixos.org"
      "https://hyprland.cachix.org"
      "https://maximilianpw.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "maximilianpw.cachix.org-1:RgUBJCLYTHNEeg67Pht2cf6VGG2NQnyxmn6jTCU+TsA="
    ];
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
