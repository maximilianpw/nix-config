{
  isLinuxDesktop,
  lib,
  ...
}: {
  # RTK for real-time priority management (needed for PipeWire and audio)
  security.rtkit.enable = lib.mkDefault isLinuxDesktop;

  # Polkit for privilege prompts (desktop authentication agent)
  security.polkit.enable = lib.mkDefault isLinuxDesktop;

  # SSH server with secure defaults
  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
