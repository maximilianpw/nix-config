{
  pkgs,
  package,
  home,
}: let
  configFile = home.home.file.".config/opencode/opencode.json".source;
  quotaFile = home.home.file.".config/opencode/opencode-quota/quota-toast.json".source;
  cliDefaults = ../users/maxpw/agents/opencode/cli.json;
  configureCli = ../scripts/user/opencode-configure-cli.sh;
  cliProxy = import ../modules/cliproxyapi/config.nix;
  serverConfig = pkgs.writeText "cliproxyapi-fixture.yaml" (cliProxy.mkServerConfig {
    homeDirectory = "/fixture";
    localApiKey = "fixture-local-key";
    openCodeZenApiKey = "fixture-zen-key";
  });
  python = pkgs.python3.withPackages (p: [p.pyyaml]);
in
  assert !(home.home.file ? ".local/bin/opencode-direct");
    pkgs.runCommand "opencode-config-regression" {nativeBuildInputs = [pkgs.jq python];} ''
      # Keep the native v2 shape, proxy transport, and runtime credential reference.
      jq -e '
        (has("provider") or has("permission") or has("plugin") or has("experimental") | not) and
        .providers.cliproxyapi.package == "aisdk:@ai-sdk/openai-compatible" and
        .providers.cliproxyapi.settings.apiKey == "{env:CLIPROXYAPI_API_KEY}" and
        .providers.cliproxyapi.compatibility.supportsPromptCacheKey == true and
        .plugins == [{package: "@plannotator/opencode@0.28.32"}, "cc-safety-net", "@slkiser/opencode-quota"] and
        .permissions[0] == {action: "shell", resource: "*", effect: "ask"}
      ' ${configFile}
      jq -e '
        .providers.cliproxyapi.models
        | to_entries
        | length > 0 and all(.[];
            (.value.limit.context | type == "number" and . > 0) and
            (.value.limit.output | type == "number" and . > 0) and
            (.value.limit.output <= .value.limit.context)
          )
      ' ${configFile}
      export HOME="$TMPDIR/home"
      export XDG_CONFIG_HOME="$HOME/.config"
      export XDG_DATA_HOME="$HOME/.local/share"
      export XDG_STATE_HOME="$HOME/.local/state"
      export XDG_CACHE_HOME="$HOME/.cache"
      export CLIPROXYAPI_API_KEY=regression-placeholder
      mkdir -p "$XDG_CONFIG_HOME/opencode"
      cp ${configFile} "$XDG_CONFIG_HOME/opencode/opencode.json"
      chmod u+w "$XDG_CONFIG_HOME/opencode/opencode.json"
      cd "$HOME"

      # Exercise the packaged v2 executable with canonical configuration.
      ${package}/bin/opencode --version | grep -E '^opencode v2\.'
      # Keep diagnostic commands in disposable private servers, too.
      ${package}/bin/opencode service set disabled true
      ${package}/bin/opencode debug config > resolved.json
      jq -e '
        [.[] | select(.type == "document") | .info] | first
        | .model.providerID == "cliproxyapi" and
          .update == "disable" and
          (.providers.cliproxyapi.models | length == 9) and
          .policies == [
            {action: "provider.use", resource: "*", effect: "deny"},
            {action: "provider.use", resource: "cliproxyapi", effect: "allow"},
            {action: "provider.use", resource: "opencode", effect: "allow"}
          ] and
          .agents.title.model.providerID == "opencode" and
          .agents.title.model.model == "deepseek-v4.1-flash-free" and
          (.providers.cliproxyapi.models | has("zen/deepseek-v4.1-flash-free") | not) and
          .providers.cliproxyapi.package == "aisdk:@ai-sdk/openai-compatible" and
          .plugins == [{package: "@plannotator/opencode@0.28.32"}, "cc-safety-net", "@slkiser/opencode-quota"] and
          .permissions[0] == {action: "shell", resource: "*", effect: "ask"} and
          (.permissions | any(.action == "shell" and .resource == "sudo *" and .effect == "deny")) and
          (.permissions | any(.action == "shell" and .resource == "rm -rf *" and .effect == "deny")) and
          (.permissions | any(.action == "shell" and .resource == "git push --force*" and .effect == "deny")) and
          (.permissions | any(.action == "shell" and .resource == "git reset --hard*" and .effect == "deny")) and
          (.permissions | any(.action == "shell" and .resource == "git status" and .effect == "allow")) and
          (.permissions | any(.action == "edit" and .effect == "ask")) and
          (.permissions | any(.action == "external_directory" and .resource == "~/Documents/obsidian vault/**" and .effect == "allow")) and
          (.mcp.servers.executor.disabled == false) and
          (.mcp.servers.executor.url == "https://executor.maximilian.pw/mcp")
      ' resolved.json

      # The rejected free-tier route must be absent from the proxy. Existing
      # paid models retain exact aliases and prefixes, using fake keys only.
      python3 - ${serverConfig} <<'PY'
      import sys
      import yaml

      with open(sys.argv[1]) as source:
          server = yaml.safe_load(source)
      assert server["routing"]["force-model-prefix"] is True
      upstreams = server["api-keys"]["openai-compatibility"]
      assert len(upstreams) == 1
      zen = upstreams[0]
      assert zen["name"] == "opencode-zen"
      assert zen["prefix"] == "zen"
      assert zen["base-url"] == "https://opencode.ai/inference/openai/v1"
      assert zen["keys"] == [{"api-key": "fixture-zen-key"}]
      models = zen["models"]
      assert len(models) == 5
      assert len({model["alias"] for model in models}) == len(models)
      assert all(model["name"] == model["alias"] for model in models)
      assert not any(model["name"].endswith("-free") or model["alias"].endswith("-free") for model in models)
      PY

      # Exercise actual provider filtering without downloading npm plugins,
      # connecting to MCP, using credentials, or making inference requests.
      jq '.plugins = [] | .mcp.servers = {}' ${configFile} > "$XDG_CONFIG_HOME/opencode/opencode.json"
      mkdir project
      cd project
      cat > opencode.json <<'JSON'
      {
        "policies": [{"action": "provider.use", "resource": "*", "effect": "allow"}],
        "providers": {
          "blocked-fixture": {
            "package": "aisdk:@ai-sdk/openai-compatible",
            "settings": {"apiKey": "fixture-key", "baseURL": "http://127.0.0.1:1/v1"},
            "models": {"must-not-appear": {"limit": {"context": 4096, "output": 1024}}}
          }
        }
      }
      JSON
      # A project cannot relax the global provider policy, even with credentials.
      ${package}/bin/opencode models --standalone > models.txt
      test "$(grep -c '^cliproxyapi/' models.txt)" -eq 9
      grep -Fx 'cliproxyapi/gpt-6-astra' models.txt
      grep -Fx 'opencode/deepseek-v4.1-flash-free' models.txt
      if grep -Fx 'cliproxyapi/zen/deepseek-v4.1-flash-free' models.txt; then
        echo 'OpenCode exposed the rejected free-tier proxy route' >&2
        exit 1
      fi
      if grep -vE '^(cliproxyapi|opencode)/' models.txt; then
        echo 'OpenCode exposed a model outside CLIProxyAPI or native OpenCode' >&2
        exit 1
      fi
      cd "$HOME"
      # Quota's separate settings retain the existing preferences.
      jq -e '
        .enableToast == false and .showSessionTokens == true and
        .enabledProviders == "auto" and .formatStyle == "grouped" and
        .percentDisplayMode == "remaining"
      ' ${quotaFile}

      # Fresh installation, then a writable config also owned by OpenCode/Herdr.
      cli="$XDG_CONFIG_HOME/opencode/cli.json"
      bash ${configureCli} ${cliDefaults} "$cli"
      jq -e '.attention == {notifications: true, sound: false} and .plugins == ["@slkiser/opencode-quota"]' "$cli"
      cat > "$cli" <<'JSON'
      {
        "theme": {"name": "catppuccin"},
        "session": {"thinking": "show"},
        "attention": {"sound": true, "volume": 0.3},
        "plugins": [
          "./herdr-opencode",
          {"package": "./custom", "options": {"enabled": true}},
          "@slkiser/opencode-quota",
          "-opencode.notifications"
        ]
      }
      JSON
      bash ${configureCli} ${cliDefaults} "$cli"
      jq -e '
        ."$schema" == "https://opencode.ai/v2/cli.json" and
        .theme.name == "catppuccin" and .session.thinking == "show" and
        .attention == {notifications: true, sound: false, volume: 0.3} and
        .plugins == [
          "@slkiser/opencode-quota", "./herdr-opencode",
          {package: "./custom", options: {enabled: true}}, "-opencode.notifications"
        ]
      ' "$cli"
      cp "$cli" cli-before.json
      inode=$(ls -i "$cli")
      bash ${configureCli} ${cliDefaults} "$cli"
      cmp "$cli" cli-before.json
      test "$(ls -i "$cli")" = "$inode"

      # Malformed/empty documents and another manager's symlink fail untouched.
      for content in 'not json' "" '[]'; do
        printf '%s' "$content" > invalid.json
        cp invalid.json invalid-before.json
        if bash ${configureCli} ${cliDefaults} invalid.json; then
          echo 'OpenCode CLI configuration accepted an invalid document' >&2
          exit 1
        fi
        cmp invalid.json invalid-before.json
      done
      ln -s "$cli" cli-link.json
      if bash ${configureCli} ${cliDefaults} cli-link.json; then
        echo 'OpenCode CLI configuration replaced a symlink' >&2
        exit 1
      fi
      test -L cli-link.json
      cmp "$cli" cli-before.json
      touch "$out"
    ''
