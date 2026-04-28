{pkgs, ...}: {
  home.packages = [
    (pkgs.writeShellApplication {
      name = "npmrc-token";
      text = ''
        set -euo pipefail

        token=""
        for f in .env.local .env; do
          if [[ -f "$f" ]]; then
            line=$(grep -E "^NODE_AUTH_TOKEN=" "$f" | tail -1 || true)
            if [[ -n "$line" ]]; then
              token="''${line#NODE_AUTH_TOKEN=}"
              token="''${token%\"}"
              token="''${token#\"}"
              token="''${token%\'}"
              token="''${token#\'}"
              break
            fi
          fi
        done

        if [[ -z "$token" ]]; then
          echo "error: NODE_AUTH_TOKEN not found in .env.local or .env" >&2
          exit 1
        fi

        if [[ ! -f .npmrc ]]; then
          echo "error: .npmrc not found in $(pwd)" >&2
          exit 1
        fi

        sed -i.bak "s|\''${NODE_AUTH_TOKEN}|$token|g" .npmrc
        rm -f .npmrc.bak
        echo "replaced \''${NODE_AUTH_TOKEN} in ./.npmrc"
      '';
    })
  ];
}
