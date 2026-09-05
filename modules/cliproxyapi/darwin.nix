{
  config,
  currentSystemUser,
  lib,
  ...
}: let
  homeDirectory = "/Users/${currentSystemUser}";
in {
  imports = [(import ./sops.nix {inherit homeDirectory;})];

  # Homebrew owns the binary. nix-darwin owns the configuration and LaunchAgent
  # so the process never falls back to Homebrew's sample configuration.
  homebrew.brews = ["cliproxyapi"];

  # sops-nix renders the stable runtime path after activation. Restart the
  # existing agent so key rotations and model-list changes take effect now.
  system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
    user_uid=$(/usr/bin/id -u ${lib.escapeShellArg currentSystemUser})
    /bin/launchctl kickstart -k "gui/$user_uid/org.nixos.cliproxyapi" 2>/dev/null || true
  '';

  launchd.user.agents.cliproxyapi.serviceConfig = {
    ProgramArguments = [
      "/opt/homebrew/opt/cliproxyapi/bin/cliproxyapi"
      "-config"
      config.sops.templates."cliproxyapi.conf".path
    ];
    RunAtLoad = true;
    KeepAlive = true;
    EnvironmentVariables.MANAGEMENT_STATIC_PATH = "${homeDirectory}/Library/Application Support/CLIProxyAPI";
    ProcessType = "Background";
    ThrottleInterval = 5;
    StandardOutPath = "${homeDirectory}/Library/Logs/cliproxyapi.log";
    StandardErrorPath = "${homeDirectory}/Library/Logs/cliproxyapi.log";
  };
}
