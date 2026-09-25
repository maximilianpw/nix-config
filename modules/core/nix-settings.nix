{
  config,
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
    substituters = [
      "https://cache.nixos.org"
      "https://hyprland.cachix.org"
      "https://maximilianpw.cachix.org"
      "https://cache.numtide.com"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "maximilianpw.cachix.org-1:RgUBJCLYTHNEeg67Pht2cf6VGG2NQnyxmn6jTCU+TsA="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  # nh keeps a rollback floor; age-only nix.gc could delete every rollback
  # target after an idle month. scripts/nixos-rebuild.sh no longer cleans.
  programs.nh = lib.mkIf config.nix.enable {
    enable = true;
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep 5 --keep-since 30d";
    };
  };
}
