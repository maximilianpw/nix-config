{
  config,
  pkgs,
  ...
}: {
  # Fonts and typography configuration module
  # This module provides font management for development and general use
  
  home.packages = with pkgs; [
    # Nerd Fonts for terminal and coding (ARM64 compatible)
    (nerdfonts.override {
      fonts = [
        "FiraCode" 
        "JetBrainsMono" 
        "Hack"
        "Iosevka"
        "CascadiaCode"
        "SourceCodePro"
      ];
    })
    
    # Additional useful fonts
    fira-code
    jetbrains-mono
    source-code-pro
    
    # System fonts
    liberation_ttf
    dejavu_fonts
  ];

  # Font configuration
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

  # Font-related session variables
  home.sessionVariables = {
    # Font rendering settings
    FREETYPE_PROPERTIES = "truetype:interpreter-version=40";
  };
}
