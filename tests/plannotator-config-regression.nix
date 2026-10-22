{
  pkgs,
  lib,
  kim,
  joyce,
  cuno,
  version,
}: let
  homes = [kim joyce cuno];
  appConfig = builtins.fromJSON (builtins.readFile ../users/maxpw/app-config/.plannotator/config.json);
  cli = kim.home.file.".local/bin/plannotator".source;
  homelab = import ../lib/homelab.nix {inherit lib;};
  claude = builtins.fromJSON (builtins.readFile ../users/maxpw/agents/claude/settings.json);
  opencode = builtins.fromJSON (builtins.readFile ../users/maxpw/agents/opencode/cliproxyapi.json);
  removeCodexInbox = pkgs.writeShellScript "remove-plannotator-codex-inbox-fixture" ''
    set -euo pipefail
    run() { "$@"; }
    ${kim.home.activation.removePlannotatorInboxCodex.data}
  '';
in
  assert lib.all (home:
    lib.all (name: home.home.sessionVariables.${name} == "0") [
      "PLANNOTATOR_INBOX_CONNECT"
      "PLANNOTATOR_INBOX_NOTES"
      "PLANNOTATOR_INBOX_TAILSCALE"
      "PLANNOTATOR_INBOX_TOOL"
    ])
  homes;
  assert !appConfig.inboxTool && !appConfig.inboxReminder && !appConfig.inboxTailscale;
  assert !(appConfig ? inboxTailscaleAllow) && !(appConfig ? inboxSound) && !(appConfig ? inboxNotifications);
  assert lib.all (home:
    !(home.home.file ? ".local/bin/inbox")
    && !(home.home.file ? ".plannotator/inbox/inbox.json")
    && !(home.systemd.user.services ? plannotator-inbox)
    && !(home.systemd.user.services ? plannotator-inbox-redirect)
    && !(home.home.activation ? configurePlannotatorCodex))
  homes;
  assert !(homelab.services ? plannotator) && !(homelab.endpoints ? plannotator);
  assert claude.extraKnownMarketplaces.plannotator.source.ref == "v${version}";
  assert builtins.elem {package = "@plannotator/opencode@${version}";} opencode.plugins;
    pkgs.runCommand "plannotator-config-regression" {
      nativeBuildInputs = [pkgs.jq pkgs.python3];
    } ''
      export HOME="$TMPDIR/home"
      export XDG_CONFIG_HOME="$HOME/.config"
      export CODEX_HOME="$HOME/.codex"
      mkdir -p "$CODEX_HOME" "$HOME/.plannotator/inbox"
      ${cli} --version | grep -Fx 'plannotator ${version}'
      ${cli} review --help > help.txt
      grep -F 'plannotator review' help.txt

      # Exercise the actual activation snippet against disposable mutable config.
      # Both repeated activation and an absent server must preserve other settings.
      printf 'model = "fixture-model"\n[mcp_servers.fixture]\ncommand = "fixture"\n[mcp_servers.plannotator-inbox]\ncommand = "plannotator"\nargs = ["inbox", "mcp"]\n' > "$CODEX_HOME/config.toml"
      printf 'saved messages must survive\n' > "$HOME/.plannotator/inbox/fixture.txt"
      ${removeCodexInbox}
      cp "$CODEX_HOME/config.toml" before.toml
      ${removeCodexInbox}
      cmp before.toml "$CODEX_HOME/config.toml"
      python3 - <<'PY'
      import os
      from pathlib import Path
      import tomllib
      config = tomllib.loads((Path(os.environ["CODEX_HOME"]) / "config.toml").read_text())
      assert config["model"] == "fixture-model"
      assert config["mcp_servers"]["fixture"]["command"] == "fixture"
      assert "plannotator-inbox" not in config["mcp_servers"]
      grok = tomllib.loads(Path("${../users/maxpw/agents/grok/config.toml}").read_text())
      assert "plannotator-inbox" not in grok.get("mcp_servers", {})
      PY
      grep -Fx 'saved messages must survive' "$HOME/.plannotator/inbox/fixture.txt"
      test ! -e "$HOME/.plannotator/inbox/inbox.json"
      jq -e '(."amp.mcpServers" // {} | has("plannotator-inbox")) | not' ${../users/maxpw/agents/amp/settings.json}
      jq -e '.mcpServers | has("plannotator-inbox") | not' ${../users/maxpw/agents/muse/settings.json}
      jq -e '.enabledPlugins."plannotator@plannotator" == true' ${../users/maxpw/agents/claude/settings.json}
      touch "$out"
    ''
