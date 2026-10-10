{
  pkgs,
  lib,
  home,
}: let
  git = home.programs.git;
  jj = home.programs.jujutsu;
  mergiraf = home.programs.mergiraf;
in
  assert mergiraf.enable && mergiraf.enableGitIntegration && mergiraf.enableJujutsuIntegration;
  assert builtins.elem mergiraf.package home.home.packages;
  assert builtins.elem "* merge=mergiraf" git.attributes;
  assert git.settings.merge.conflictStyle == "diff3";
  assert git.settings.push.useForceIfIncludes;
  assert git.settings.rebase.missingCommitsCheck == "error";
  assert git.settings.diff.colorMoved == "dimmed-zebra";
  assert git.settings.diff.colorMovedWS == "allow-indentation-change";
  assert git.settings.core.pager == "hunk pager";
  assert git.settings.pull.rebase == false;
  assert git.settings.rerere.enabled;
  assert jj.settings.ui.merge-editor == "mergiraf";
  assert jj.settings.merge-tools.mergiraf.program == lib.getExe mergiraf.package;
    pkgs.runCommand "git-merge-regression" {
      nativeBuildInputs = [git.package jj.package mergiraf.package];
    } ''
      export HOME="$TMPDIR/home"
      export XDG_CONFIG_HOME="$HOME/.config"
      export GIT_CONFIG_NOSYSTEM=1
      export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
      mkdir -p "$XDG_CONFIG_HOME/jj"
      git config --global user.name Fixture
      git config --global user.email fixture@example.invalid
      git config --global commit.gpgSign false
      git config --global core.hooksPath /dev/null
      git config --global merge.conflictStyle ${lib.escapeShellArg git.settings.merge.conflictStyle}
      git config --global merge.mergiraf.driver ${lib.escapeShellArg git.settings.merge.mergiraf.driver}
      printf '%s\n' '* merge=mergiraf' > "$HOME/attributes"
      git config --global core.attributesFile "$HOME/attributes"
      cat > "$XDG_CONFIG_HOME/jj/config.toml" <<'EOF'
      [user]
      name = "Fixture"
      email = "fixture@example.invalid"
      [signing]
      behavior = "drop"
      [ui]
      merge-editor = "${jj.settings.ui.merge-editor}"
      [merge-tools.mergiraf]
      program = "${jj.settings.merge-tools.mergiraf.program}"
      EOF

      git init -b base fixture
      cd fixture
      printf '%s\n' 'export const settings = { width: 1, height: 1 };' > settings.js
      git add settings.js
      git commit -m base
      git checkout -b left
      printf '%s\n' 'export const settings = { width: 2, height: 1 };' > settings.js
      git commit -am left
      git checkout -b right base
      printf '%s\n' 'export const settings = { width: 1, height: 2 };' > settings.js
      git commit -am right
      git checkout left
      git branch left-original
      git merge --no-edit right
      grep -F 'width: 2, height: 2' settings.js
      test -z "$(git ls-files -u)"

      # Recreate the conflict from the original parents in JJ, then exercise
      # its configured default merge editor rather than passing --tool.
      jj git init --colocate .
      jj new left-original right -m 'merge fixture'
      test -n "$(jj log -r 'conflicts() & @' --no-graph -T commit_id)"
      jj resolve
      test -z "$(jj log -r 'conflicts() & @' --no-graph -T commit_id)"
      grep -F 'width: 2, height: 2' settings.js
      touch "$out"
    ''
