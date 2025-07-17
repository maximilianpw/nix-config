{
  inputs,
  pkgs,
  lib,
  ...
}: {
  homebrew = {
    enable = true;

    brews = [
      "zsh"
      "angular-cli"
      "jsonlint"
    ];

    casks = [
      "1password"
      "1password-cli"
      "rectangle"
      "figma"
      "hiddenbar"
      "whatsapp"
      "raycast"
      "arc"
      "appcleaner"
    ];

    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };
  };
}
