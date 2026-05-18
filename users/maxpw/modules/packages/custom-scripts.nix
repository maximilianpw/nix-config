{pkgs, ...}: {
  home.packages = [
    (pkgs.writeShellApplication {
      name = "npmrc-token";
      text = ''
        set -euo pipefail

        token=""
        token_source=""
        fallback_dir="$HOME/local/vev platform services/vev-docker-compose/submodules/vev-server"

        for f in .env.local .env "$fallback_dir/.env.local" "$fallback_dir/.env"; do
          if [[ -f "$f" ]]; then
            line=$(grep -E "^NODE_AUTH_TOKEN=" "$f" | tail -1 || true)
            if [[ -n "$line" ]]; then
              token="''${line#NODE_AUTH_TOKEN=}"
              token="''${token%\"}"
              token="''${token#\"}"
              token="''${token%\'}"
              token="''${token#\'}"
              token_source="$f"
              break
            fi
          fi
        done

        if [[ -z "$token" ]]; then
          echo "error: NODE_AUTH_TOKEN not found in .env.local, .env, or $fallback_dir" >&2
          exit 1
        fi

        if [[ ! -f .npmrc ]]; then
          echo "error: .npmrc not found in $(pwd)" >&2
          exit 1
        fi

        sed -i.bak "s|\''${NODE_AUTH_TOKEN}|$token|g" .npmrc
        rm -f .npmrc.bak
        echo "replaced \''${NODE_AUTH_TOKEN} in ./.npmrc using $token_source"
      '';
    })
  ];
}
