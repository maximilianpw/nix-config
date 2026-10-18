{pkgs, ...}: let
  cliProxy = import ../modules/cliproxyapi/config.nix;
  serverConfig = pkgs.writeText "cliproxyapi-fixture.yaml" (cliProxy.mkServerConfig {
    homeDirectory = "/fixture";
    localApiKey = "fixture-local-key";
    openCodeZenApiKey = "fixture-zen-key";
  });
  python = pkgs.python3.withPackages (p: [p.pyyaml]);
in
  pkgs.runCommand "opencode-config-regression" {nativeBuildInputs = [python];} ''
    # Parse the rendered server configuration with fake keys only. Exact free
    # aliases and forced prefixes must not route this selection to a paid model.
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
    assert len(models) == 6
    assert len({model["alias"] for model in models}) == len(models)
    assert all(model["name"] == model["alias"] for model in models)
    free = [model for model in models if model["alias"] == "deepseek-v4.1-flash-free"]
    assert len(free) == 1
    assert free[0]["max-context-length"] == 200000
    assert free[0]["input-modalities"] == ["text", "image"]
    PY

    touch "$out"
  ''
