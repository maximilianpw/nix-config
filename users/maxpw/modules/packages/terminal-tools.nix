{pkgs, ...}: {
  home.packages = [
    # Environment management
    pkgs.chezmoi
    pkgs.stow
    # File navigation & search
    pkgs.bat
    pkgs.eza
    pkgs.tree
    pkgs.fzf
    pkgs.ripgrep
    pkgs.fd
    pkgs.yazi

    # Git tools
    pkgs.gnupg
    pkgs.gh
    pkgs.lazygit
    pkgs.lazydocker

    # System utilities
    pkgs.fastfetch
    pkgs.btop
    pkgs.cmatrix

    # Compression & file tools
    pkgs.zip
    pkgs.unzip
    pkgs.xdg-utils

    # Linting & validation
    pkgs.vale
    pkgs.glow
    pkgs.python313Packages.mkdocs
    pkgs.python313Packages.mkdocs-material
    pkgs.python313Packages.mkdocs-mermaid2-plugin
    pkgs.python313Packages.pymdown-extensions

    # Security & secrets
    pkgs._1password-cli
    pkgs.ngrok

    # Tmux tools
    pkgs.sesh

    # AI tools
    pkgs.claude-code
    pkgs.codex
    pkgs.gemini-cli
    pkgs.opencode
  ];
}
