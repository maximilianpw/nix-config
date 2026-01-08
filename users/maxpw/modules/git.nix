# Git and Jujutsu configuration
{
  pkgs,
  lib,
  ...
}: {
  programs.jujutsu = {
    enable = true;
    # I don't use "settings" because the path is wrong on macOS at
    # the time of writing this.
  };

  programs.jjui.enable = true;

  programs.git = {
    enable = true;
    signing = {
      key = "992CF94F12CF7405147D81FD4AB37B87F45FAC60";
      signByDefault = true;
    };
    settings = {
      user = {
        name = "Maximilian PINDER-WHITE";
        email = "mpinderwhite@proton.me";
      };
      alias = {
        cleanup = "!git branch --merged | grep -E -v '\\*|master|develop' | xargs -n 1 -r git branch -d";
        prettylog = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(r) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
        root = "rev-parse --show-toplevel";
      };
      core.askPass = ""; # needs to be empty to use terminal for ask pass
      credential.helper = "store"; # want to make this more secure
      lfs.enable = true;
      branch.autosetuprebase = "always";
      color.ui = true;
      github.user = "maximilianpw";
      init.defaultBranch = "main";
      push.default = "tracking";
      push.autoSetupRemote = true;
      pull.rebase = false;
    };
  };
}
