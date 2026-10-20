{
  pkgs,
  lib,
  kim,
  joyce,
  cuno,
  codex,
  version,
}: let
  homes = [kim joyce cuno];
  inboxConfig = builtins.fromJSON (builtins.readFile ../users/maxpw/app-config/.plannotator/config.json);
  cli = kim.home.file.".local/bin/plannotator".source;
  homelab = import ../lib/homelab.nix {inherit lib;};
  claude = builtins.fromJSON (builtins.readFile ../users/maxpw/agents/claude/settings.json);
  opencode = builtins.fromJSON (builtins.readFile ../users/maxpw/agents/opencode/cliproxyapi.json);
in
  assert lib.all (home: home.home.sessionVariables.PLANNOTATOR_INBOX_CONNECT == "0") homes;
  assert lib.all (home: home.home.sessionVariables.PLANNOTATOR_INBOX_NOTES == "0") homes;
  assert kim.home.sessionVariables.PLANNOTATOR_INBOX_TAILSCALE == "1";
  assert joyce.home.sessionVariables.PLANNOTATOR_INBOX_TAILSCALE == "0";
  assert cuno.home.sessionVariables.PLANNOTATOR_INBOX_TAILSCALE == "0";
  assert inboxConfig.inboxTool.pi && inboxConfig.inboxTool.opencode;
  assert inboxConfig.inboxTailscaleAllow == ["maximilianpw@github"];
  assert lib.all (home: !(home.home.file ? ".plannotator/inbox/inbox.json")) homes;
  assert kim.systemd.user.services ? plannotator-inbox;
  assert kim.systemd.user.services ? plannotator-inbox-redirect;
  assert !(joyce.systemd.user.services ? plannotator-inbox);
  assert !(cuno.systemd.user.services ? plannotator-inbox);
  assert homelab.endpoints.plannotator.url == "https://plannotator.liger-shilling.ts.net";
  assert homelab.services.plannotator.endpoint.monitorPath == "/health";
  assert claude.extraKnownMarketplaces.plannotator.source.ref == "v${version}";
  assert builtins.elem {package = "@plannotator/opencode@${version}";} opencode.plugins;
    pkgs.runCommand "plannotator-config-regression" {
      nativeBuildInputs = [pkgs.jq pkgs.python3];
    } ''
      export HOME="$TMPDIR/home"
      export XDG_CONFIG_HOME="$HOME/.config"
      mkdir -p "$HOME/.codex"
      ${cli} --version | grep -Fx 'plannotator ${version}'
      PYTHONDONTWRITEBYTECODE=1 PLANNOTATOR_INBOX_SCRIPT=${../scripts/user/plannotator-inbox.py} \
        python3 ${./plannotator-inbox-test.py}
      ${cli} inbox --help > help.txt
      head -n 1 help.txt | grep -Fx '# Plannotator Inbox: a guide for agents'
      test ! -e "$HOME/.plannotator/inbox/inbox.json"

      # Its supported merger must preserve unrelated settings on every activation.
      printf 'model = "fixture-model"\n[mcp_servers.fixture]\ncommand = "fixture"\n' > "$HOME/.codex/config.toml"
      ${codex}/bin/codex mcp add plannotator-inbox -- ${cli} inbox mcp
      cp "$HOME/.codex/config.toml" before.toml
      ${codex}/bin/codex mcp add plannotator-inbox -- ${cli} inbox mcp
      cmp before.toml "$HOME/.codex/config.toml"
      grep -Fx 'model = "fixture-model"' "$HOME/.codex/config.toml"
      grep -Fx '[mcp_servers.fixture]' "$HOME/.codex/config.toml"
      ${codex}/bin/codex mcp get plannotator-inbox --json | jq -e \
        --arg command '${cli}' '.transport.command == $command and .transport.args == ["inbox", "mcp"]'
      jq -e '."amp.mcpServers"."plannotator-inbox".args == ["inbox", "mcp"]' ${../users/maxpw/agents/amp/settings.json}
      jq -e '.mcpServers."plannotator-inbox".args == ["inbox", "mcp"]' ${../users/maxpw/agents/muse/settings.json}
      jq -e '.enabledPlugins."plannotator@plannotator" == true' ${../users/maxpw/agents/claude/settings.json}
      touch "$out"
    ''
