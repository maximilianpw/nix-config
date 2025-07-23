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
      "chatgpt"
      "discord"
      "google-chrome"
      "notion"
      "postman"
      "rectangle"
      "slack"
      "the-unarchiver"
      "visual-studio-code"
      "mongodb-compass"
      "proton-mail"
      "zen"
      "ghostty"
      "webstorm"
    ];

    masApps = {
    };

    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };
  };
}
