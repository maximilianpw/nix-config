{
  lib,
  pkgs,
  ...
}: {
  # RTK for real-time priority management (needed for PipeWire and audio)
  security.rtkit.enable = lib.mkDefault true;

  # Polkit for privilege prompts (desktop authentication agent)
  security.polkit.enable = lib.mkDefault true;

  # SSH server with secure defaults
  services.openssh = {
    enable = lib.mkDefault true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PermitRootLogin = "no";
  };
}
