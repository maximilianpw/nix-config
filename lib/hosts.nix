# Canonical host data. lib/inventory.nix applies defaults, derives capabilities,
# validates types, and rejects unknown fields before consumers see these records.
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
    longRunningAgents = true;
    client = {
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMXaaYJcFFLXio9Tzt+QxnkSYrpgGJGDOoJyAp8Rhjmh fleet kim";
      tailscaleIps = [
        "100.76.56.97"
        "fd7a:115c:a1e0::2a01:3881"
      ];
      identityFile = ".ssh/fleet_ed25519";
    };
    aliases = [
      "main-pc"
      "main"
      "desktop"
    ];
    t3codePort = 51000;
    # Cross-checked against the host's public key, ssh-keyscan over
    # Tailscale, and the existing known_hosts entry on 2026-07-09.
    hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO9tCTFAEd4W4eywYE3GJuYSh4mVbtImMtXIjQ3IIuhO";
  };

  cuno = {
    system = "x86_64-linux";
    user = "maxpw";
    userDir = "maxpw";
    darwin = false;
    wsl = true;
    linuxDesktop = false;
    profiles = [
      "base"
      "dev"
      "agent"
      "wsl"
    ];
    role = "nixos-wsl";
    longRunningAgents = false;
    # Enrol after `tailscale up` inside WSL and key generation; Fleet surfaces
    # this null explicitly instead of pretending outbound access is available.
    client = null;
    aliases = ["wsl"];
  };

  joyce = {
    system = "aarch64-darwin";
    user = "max-vev";
    userDir = "maxpw";
    darwin = true;
    wsl = false;
    linuxDesktop = false;
    profiles = [
      "base"
      "dev"
      "agent"
      "darwin"
    ];
    role = "darwin-workstation";
    longRunningAgents = false;
    client = {
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB3qKWMhvPDxIo8U2S7VpC7eGtF5LATuGQ05gSlXmu+4 Kim SSH";
      tailscaleIps = [
        "100.82.28.19"
        "fd7a:115c:a1e0::de01:1c2b"
      ];
      identityFile = ".ssh/fleet_1password_ed25519.pub";
      identityAgent = "%d/.1password/agent.sock";
    };
    # Tailscale still advertises the pre-nix-darwin machine name. `joyce`
    # remains the stable Fleet alias and can become the target after renaming it.
    hostName = "maximilians-macbook-pro-1";
    # Cross-checked against the host's public key and ssh-keyscan over
    # Tailscale on 2026-07-25.
    hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFiHFQW6b4qbruaHM9f4rXus/BAvYQUboN95vFG5FIKI";
    aliases = [
      "macbook"
      "mac"
    ];
  };
}
