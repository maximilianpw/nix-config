# Canonical host inventory. Keep this file data-only so flake outputs, fleet
# metadata, bootstrap validation, and documentation can all consume it.
{
  main-pc = {
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
      hostName = "main-pc";
      user = "maxpw";
      aliases = [
        "main"
        "desktop"
      ];
      tmuxSession = "main";
      tmuxCommand = "/run/current-system/sw/bin/tmux";
      # Cross-checked against the host's public key, ssh-keyscan over
      # Tailscale, and the existing known_hosts entry on 2026-07-09.
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO9tCTFAEd4W4eywYE3GJuYSh4mVbtImMtXIjQ3IIuhO";
    };
  };

  wsl = {
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

  macbook-pro-m1 = {
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
