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
      "jandedobbeleer/oh-my-posh/oh-my-posh"
    ];

    casks = [
      "1password"
      "1password-cli"
      "rectangle"
      "figma"
      "hiddenbar"
      "whatsapp"
    ];

    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };
  };
}
