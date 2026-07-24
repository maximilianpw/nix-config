# Canonical host inventory. Keep this file data-only so flake outputs, fleet
# metadata, bootstrap validation, and documentation can all consume it.
{
  kim = {
    system = "x86_64-linux";
    user = "maxpw";
    userDir = "maxpw";
    darwin = false;
    wsl = false;
    linuxDesktop = false;
    hardwareModules = [
      "common-cpu-amd"
      "common-pc-ssd"
    ];
    profiles = [
      "base"
      "dev"
      "agent"
      "homelab"
    ];
    role = "nixos-homelab";
    os = "nixos";
    gui = false;
    longRunningAgents = true;
    fleet = {
      hostName = "kim";
      user = "maxpw";
      aliases = [
        "main-pc"
        "main"
        "desktop"
      ];
      tmuxSession = "main";
      tmuxCommand = "/run/current-system/sw/bin/tmux";
      t3codePort = 51000;
      # Cross-checked against the host's public key, ssh-keyscan over
      # Tailscale, and the existing known_hosts entry on 2026-07-09.
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO9tCTFAEd4W4eywYE3GJuYSh4mVbtImMtXIjQ3IIuhO";
    };
  };

  cuno = {
    system = "x86_64-linux";
    user = "maxpw";
    userDir = "maxpw";
    darwin = false;
    wsl = true;
    linuxDesktop = false;
    hardwareModules = [];
    profiles = [
      "base"
      "dev"
      "agent"
      "wsl"
    ];
    role = "nixos-wsl";
    os = "nixos-wsl";
    gui = false;
    longRunningAgents = false;
    fleet = null;
  };

  joyce = {
    system = "aarch64-darwin";
    user = "max-vev";
    userDir = "maxpw";
    darwin = true;
    wsl = false;
    linuxDesktop = false;
    hardwareModules = [];
    profiles = [
      "base"
      "dev"
      "agent"
      "darwin"
    ];
    role = "darwin-workstation";
    os = "darwin";
    gui = true;
    longRunningAgents = false;
    fleet = null;
  };
}
