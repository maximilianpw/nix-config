{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  jjStack = inputs.jj-stack.packages.${pkgs.stdenv.hostPlatform.system}.jj-stack;
in {
  home.packages = [jjStack];

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
        editor = ["nvim" "+$line"];
      };

      "--scope" = [
        {
          "--when".commands = ["diff" "show"];

          ui = {
            pager = ["hunk" "pager"];
            diff-formatter = ":git";
          };
        }
        {
          "--when".environments = ["JJ_AGENT=1"];
          ui = {
            paginate = "never";
            color = "never";
            editor = ["false"];
            diff-formatter = ":git";
            conflict-marker-style = "snapshot";
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
        tug = {
          definition = ["bookmark" "advance" "--to" "@-"];
          doc = "Advance the closest bookmark to the working-copy parent";
        };
        retrunk = {
          definition = ["rebase" "-d" "trunk()"];
          doc = "Rebase the current branch onto trunk";
        };
        stack = {
          definition = ["util" "exec" "--" (lib.getExe jjStack)];
          doc = "Manage stacked pull requests with jj-stack";
        };
        sync = {
          definition = ["stack" "sync" "--all"];
          doc = "Sync all stacks; may update PRs and delete obsolete remote branches";
        };
        check-stack = {
          definition = ["run" "--ignore-changes" "--revision" "mutable() & ::@ & ~empty()" "--"];
          doc = "Check non-empty mutable ancestors without rewriting commits";
        };
        resolve-editor = {
          definition = ["resolve" "--tool" ":editor"];
          doc = "Resolve conflict markers in Neovim, including multi-sided conflicts";
        };
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
        abandon-unreachable-commits = true;
        private-commits = "description(glob:'wip:*') | description(glob:'private:*')";
      };

      revsets.git-sign-on-push = "~signed() & mine()";

      remotes.origin.auto-track-bookmarks = "glob:main";

      templates = {
        git_push_bookmark = ''"maximilianpw/push-" ++ change_id.short()'';
      };

      revset-aliases = {
        "fork_history(to, from)" = "fork_point(to | from)..@";
      };

      template-aliases."format_timestamp(timestamp)" = "timestamp.ago()";
    };
  };

  home.file."${config.xdg.configHome}/jj/config.toml".force = true;
  programs.jjui.enable = true;
}
