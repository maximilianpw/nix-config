{
  inputs,
  pkgs,
  lib,
  ...
}: {
  fonts.packages = with pkgs; [
    pkgs."nerd-fonts".fira-code
    pkgs."nerd-fonts".jetbrains-mono
  ];
  homebrew = {
    enable = true;

    brews = [
      "zsh"
      "jsonlint"
      "gnupg"
      "codex"
    ];

    casks = [
      "colemak-dh"
      "1password"
      "rectangle"
      "figma"
      "hiddenbar"
      "whatsapp"
      "raycast"
      "arc"
      "appcleaner"
      "chatgpt"
      "discord"
      "google-chrome"
      "notion"
      "postman"
      "slack"
      "visual-studio-code"
      "mongodb-compass"
      "proton-mail"
      "ghostty"
      "webstorm"
      "protonvpn"
      "aws-vpn-client"
      "orbstack"
      "claude"
      "helium-browser"
      "yaak"
      "github"
      "logi-options+"
      "datagrip"
    ];

    masApps = {
      "Poolsuite FM" = 1514817810;
      "XCode" = 497799835;
    };

    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };
  };
  # The user should already exist, but we need to set this up so Nix knows
  # what our home directory is (https://github.com/LnL7/nix-darwin/issues/423).
  # macOS primary login user. We keep configs in users/maxpw but the on-system
  # account remains max-vev. This indirection is handled via userDir in mksystem.nix.
  users.users.max-vev = {
    home = "/Users/max-vev";
    shell = pkgs.nushell;
  };

  # Required for some settings like homebrew to know what user to apply to.
  system.primaryUser = "max-vev";
}
