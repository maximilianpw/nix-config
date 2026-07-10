{pkgs, ...}: {
  home.packages = [
    (pkgs.writeShellApplication {
      name = "npmrc-token";
      text = ''
        set -euo pipefail

        if [[ $# -eq 0 ]]; then
          echo "usage: npmrc-token <command> [args...]" >&2
          echo "runs a command with NODE_AUTH_TOKEN loaded from a local dotenv file" >&2
          exit 2
        fi

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

        # Export inside this process and exec directly: the token is never
        # written to .npmrc and never becomes a command-line argument.
        export NODE_AUTH_TOKEN="$token"
        echo "running $1 with NODE_AUTH_TOKEN from $token_source" >&2
        exec "$@"
      '';
    })
  ];
}
