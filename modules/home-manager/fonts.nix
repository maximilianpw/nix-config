{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # Nerd Fonts — now using individual font packages
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.hack
    nerd-fonts.iosevka

    # Additional useful fonts
    fira-code
    jetbrains-mono
    source-code-pro

    # System fonts
    liberation_ttf
    dejavu_fonts
  ];

  fonts.fontconfig = {
    enable = true;

    defaultFonts = {
      monospace = [
        "FiraCode Nerd Font"
        "JetBrainsMono Nerd Font"
        "Hack Nerd Font"
        "Source Code Pro"
      ];
      sansSerif = [
        "Liberation Sans"
        "DejaVu Sans"
      ];
      serif = [
        "Liberation Serif"
        "DejaVu Serif"
      ];
    };
  };
}
