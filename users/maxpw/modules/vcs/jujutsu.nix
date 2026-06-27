# Jujutsu configuration
{config, ...}: {
  programs.jujutsu = {
    enable = true;
    settings = {
      "$schema" = "https://jj-vcs.github.io/jj/latest/config-schema.json";

      user = {
        name = "Maximilian PINDER-WHITE";
        email = "mpinderwhite@proton.me";
      };

      signing = {
        backend = "gpg";
        behavior = "drop";
        key = "992CF94F12CF7405147D81FD4AB37B87F45FAC60";
      };

      ui = {
        default-command = "log";
        editor = "nvim";
      };

      "--scope" = [
        {
          "--when".commands = ["diff" "show"];

          ui = {
            pager = ["hunk" "pager"];
            diff-formatter = ":git";
          };
        }
      ];

      aliases = {
        b = ["bookmark"];
        c = ["commit"];
        d = ["desc"];
        di = ["diff"];
        e = ["edit"];
        f = ["git" "fetch"];
        jrf = ["refetch"];
        l = ["log" "-r" "trunk()..@"];
        n = ["new"];
        p = ["git" "push"];
        s = ["status"];
        # Move the closest bookmark to the current commit. This is useful when
        # working on a named branch, creating a bunch of commits, and then
        # needing to update the bookmark before pushing.
        tug = ["bookmark" "move" "--from" "closest_bookmark(@-)" "--to" "@-"];
        # Rebase the current branch onto the trunk.
        retrunk = ["rebase" "-d" "trunk()"];
        # Tidy up the current branch, removing commits from dead branches.
        tidy = [
          "abandon"
          "mine() & ~bookmarks() & ~(bookmarks()::) & ~::@ & ~trunk() & mutable()"
        ];
        # Tidy up all commits that have been merged into trunk.
        tidy-all = ["abandon" "~bookmarks() & ~::@ & ~trunk() & mutable()"];
        a = ["absorb"];
        el = ["evolog" "-p"];
        sp = ["split"];
      };

      fix.tools = {
        prettier = {
          command = ["prettierd" "$path"];
          patterns = ["glob:'**/*.{js,jsx,ts,tsx,css,html,json,md,yaml,yml}'"];
        };

        eslint = {
          # ESLint v9 no longer has --fix-to-stdout. Run a dry fix on stdin
          # and emit the fixed source from the JSON formatter for jj fix to
          # consume.
          command = ["node" "-e" "const { spawnSync } = require('node:child_process'); const path = process.argv[1]; let input = ''; process.stdin.setEncoding('utf8'); process.stdin.on('data', c => input += c); process.stdin.on('end', () => { const r = spawnSync('eslint', ['--fix-dry-run', '--format', 'json', '--stdin', '--stdin-filename', path], { input, encoding: 'utf8' }); if (r.error) { console.error(r.error.message); process.exit(1); } try { const result = JSON.parse(r.stdout || '[]')[0]; process.stdout.write(result && Object.prototype.hasOwnProperty.call(result, 'output') ? result.output : input); process.exit(0); } catch (e) { if (r.stderr) process.stderr.write(r.stderr); if (r.stdout) process.stderr.write(r.stdout); process.exit(r.status || 1); } });" "$path"];
          patterns = ["glob:'**/*.{js,jsx,ts,tsx}'"];
        };

        rustfmt = {
          command = ["rustfmt" "$path"];
          patterns = ["glob:**/*.rs"];
        };
      };

      git = {
        abandon-unreachable-commits = false;
        sign-on-push = true;
      };

      remotes.origin.auto-track-bookmarks = "glob:main";

      templates = {
        git_push_bookmark = ''"maximilianpw/push-" ++ change_id.short()'';
        private-commits = "description(glob:'wip:*') | description(glob:'private:*')";
      };

      revset-aliases = {
        "closest_bookmark(to)" = "heads(::to & bookmarks())";
        "fork_history(to, from)" = "fork_point(to | from)..@";
      };

      template-aliases."format_timestamp(timestamp)" = "timestamp.ago()";
    };
  };

  home.file."${config.xdg.configHome}/jj/config.toml".force = true;
  programs.jjui.enable = true;
}
