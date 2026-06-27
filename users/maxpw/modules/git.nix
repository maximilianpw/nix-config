# Git configuration
{
  pkgs,
  lib,
  isDarwin,
  ...
}: {
  programs.gh.enable = true;
  programs.lazygit.enable = true;
  home.packages = [pkgs.hunkdiff];
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
      gpg.format = "openpgp";
      alias = {
        cleanup = "!git branch --merged | grep -E -v '\\*|master|develop' | xargs -n 1 -r git branch -d";
        prettylog = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(r) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
        root = "rev-parse --show-toplevel";
      };
      core.pager = "hunk pager";
      core.askPass = ""; # needs to be empty to use terminal for ask pass
      # Avoid plaintext ~/.git-credentials: macOS Keychain on Darwin,
      # in-memory cache (1h) elsewhere. SSH auth goes through 1Password.
      credential.helper =
        if isDarwin
        then "osxkeychain"
        else "cache --timeout=3600";
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
