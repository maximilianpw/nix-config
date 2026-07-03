{pkgs, ...}: {
  home.packages = [
    # Environment management
    pkgs.chezmoi
    # File navigation & search
    pkgs.bat
    pkgs.eza
    pkgs.tree
    pkgs.fzf
    pkgs.ripgrep
    pkgs.fd
    pkgs.yazi
    pkgs.jq
    pkgs.uv

    # Network & remote access
    pkgs.autossh
    pkgs.mosh
    pkgs.rsync
    pkgs.sshfs
    pkgs.wakeonlan

    # Git tools
    pkgs.gnupg
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
  ];
}
