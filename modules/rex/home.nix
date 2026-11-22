{
  config,
  inputs,
  lib,
  ...
}: {
  imports = [inputs.rex.homeManagerModules.default];

  # Rex Beta.app runs Joyce's server; this adds its CLI, terminfo and ssh guard.
  programs.rex.enable = true;

  # Rex delivers events only to a running `rex do` script, never to init.lua,
  # so labelling panes as they change directory needs this process. The app
  # owns the server: with autostart the CLI would start its own, older or
  # newer than the app expects, whenever this ran first at login.
  launchd.agents.rex-pane-labels = {
    enable = true;
    config = {
      ProgramArguments = [
        "${config.home.profileDirectory}/bin/rex"
        "--autostart=false"
        "do"
        "${./pane-labels.lua}"
        "--all"
        "git=${lib.getExe config.programs.git.package}"
        "jj=${lib.getExe config.programs.jujutsu.package}"
      ];
      RunAtLoad = true;
      # The script exits when the server is away or restarts; retry until it is back.
      KeepAlive = true;
      ThrottleInterval = 30;
      ProcessType = "Background";
    };
  };
}
