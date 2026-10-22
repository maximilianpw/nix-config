{
  pkgs,
  home,
  stackPackage,
}: let
  jj = home.programs.jujutsu;
in
  assert builtins.elem stackPackage home.home.packages;
  assert jj.settings.git.abandon-unreachable-commits;
  assert jj.settings.git.sign-on-push;
  assert !(jj.settings.templates ? private-commits);
  assert !(jj.settings.aliases ? tidy) && !(jj.settings.aliases ? tidy-all);
  assert jj.settings.aliases.f == ["git" "fetch"];
  assert jj.settings.aliases.sync == ["stack" "sync" "--all"];
  assert jj.settings.remotes.origin.auto-track-bookmarks == "glob:main";
    pkgs.runCommand "jujutsu-workflow-regression" {
      nativeBuildInputs = [home.programs.git.package jj.package pkgs.python3];
    } ''
      export HOME="$TMPDIR/home"
      export XDG_CONFIG_HOME="$HOME/.config"
      export GIT_CONFIG_NOSYSTEM=1
      export GIT_CONFIG_GLOBAL=/dev/null
      export JJ_CONFIG=${home.home.file."${home.xdg.configHome}/jj/config.toml".source}
      mkdir -p "$HOME"
      python3 ${./jujutsu-workflow-regression.py}
      touch "$out"
    ''
