{pkgs, ...}: {
  home.packages = [
    # Environment management
    pkgs.chezmoi
    pkgs.stow
    pkgs.direnv

    # File navigation & search
    pkgs.bat
    pkgs.eza
    pkgs.tree
    pkgs.fzf
    pkgs.ripgrep
    pkgs.fd
    pkgs.zoxide
    pkgs.ranger

    # Git tools
    pkgs.gnupg
    pkgs.gh
    pkgs.lazygit
    pkgs.lazydocker

    # Shell & prompt
    pkgs.oh-my-posh
    pkgs.starship

    # System utilities
    pkgs.neofetch
    pkgs.btop
    pkgs.cmatrix

    # Compression & file tools
    pkgs.zip
    pkgs.unzip
    pkgs.xdg-utils

    # Linting & validation
    pkgs.vale

    # Security & secrets
    pkgs._1password-cli
    pkgs.ngrok

    # AI tools
    pkgs.claude-code
    pkgs.gemini-cli
  ];
}
