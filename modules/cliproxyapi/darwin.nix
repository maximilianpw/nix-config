{currentSystemUser, ...}: let
  cliProxy = import ./config.nix;
  homeDirectory = "/Users/${currentSystemUser}";
in {
  # Homebrew owns the binary. nix-darwin owns the configuration and LaunchAgent
  # so the process never falls back to Homebrew's sample configuration.
  homebrew.brews = ["cliproxyapi"];

  environment.etc."cliproxyapi.conf".text = cliProxy.mkServerConfig {inherit homeDirectory;};

  launchd.user.agents.cliproxyapi.serviceConfig = {
    ProgramArguments = [
      "/opt/homebrew/opt/cliproxyapi/bin/cliproxyapi"
      "-config"
      "/etc/cliproxyapi.conf"
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
