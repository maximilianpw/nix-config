# Headless NixOS server (kim): homelab services come from machines/kim.nix;
# this adds the local CLIProxyAPI server, unattended agent work and host-key
# sops decryption.
{hostRecord, ...}: {
  imports = [
    ./nixos-base.nix
    ../modules/agent-tools/nixos.nix
    ../modules/himalaya/nixos.nix
    ../modules/nixos/keyboard.nix
    ../modules/nixos/networking.nix
    ../modules/onepassword/nixos.nix
    ../modules/ssh/nixos.nix
    ../modules/user-account/sops-password.nix
  ];

  custom.sops.keySource = "host";
  custom.cliproxyapi.server.enable = true;

  home-manager.sharedModules = [
    ../modules/morning-report/home.nix
    ../modules/t3code/home.nix
    {
      custom = {
        cliproxyapi.endpoint = "local";
        morningReport.enable = hostRecord.longRunningAgents;
        t3code.server = {
          enable = hostRecord.t3codePort != null;
          port = hostRecord.t3codePort;
        };
      };
    }
  ];
}
