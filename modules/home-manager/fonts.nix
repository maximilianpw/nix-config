{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # Nerd Fonts — now using individual font packages
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.hack
    nerd-fonts.iosevka
    nerd-fonts.ubuntu-mono

    # Additional useful fonts
    fira-code
    jetbrains-mono
    source-code-pro
    ibm-plex
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    roboto
    roboto-mono
    ubuntu_font_family
    cantarell-fonts

    # System fonts
    liberation_ttf
    dejavu_fonts
    unifont
    dina-font
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
