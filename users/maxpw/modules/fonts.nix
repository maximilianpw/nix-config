{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    # Nerd/symbols (terminal, waybar, icons)
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.symbols-only

    # Non-nerd system stacks & coverage
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    liberation_ttf
    dejavu_fonts
    unifont

    # Optional extras (keep if you really use them)
    ibm-plex
    roboto
    roboto-mono
    ubuntu-classic
    cantarell-fonts
    # source-code-pro   # usually redundant if you already picked a mono
    # dina-font         # bitmap look; keep only if you like it
  ];

  fonts.fontconfig = {
    enable = true;

    defaultFonts = {
      monospace = [
        "JetBrainsMono Nerd Font"
        "FiraCode Nerd Font"
        "Hack Nerd Font" # only if you keep nerd-fonts.hack
        "Noto Sans Mono" # non-nerd fallback
        "Symbols Nerd Font" # icons/glyphs fallback
        "Noto Color Emoji"
      ];
      sansSerif = [
        "Noto Sans"
        "Liberation Sans"
        "DejaVu Sans"
        "Noto Sans CJK SC" # or JP/KR/TC as needed
        "Noto Color Emoji"
      ];
      serif = [
        "Noto Serif"
        "Liberation Serif"
        "DejaVu Serif"
        "Noto Color Emoji"
      ];
    };
  };
}
