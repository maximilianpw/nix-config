{
  lib,
  pkgs,
  ...
}: let
  homelab = import ../../../../lib/homelab.nix {inherit lib;};
  vaultwardenUrl = homelab.privateUrl "vaultwarden";
in {
  home.packages = [
    (pkgs.writeShellApplication {
      name = "npmrc-token";
      text = builtins.readFile ../../../../scripts/user/npmrc-token.sh;
    })
    (pkgs.writeShellApplication {
      name = "dcompose";
      text = ''
        # APFS is case-insensitive, so ~/Local/vev and ~/local/vev are the same tree.
        cwd=$(pwd -P)
        vev_root="$HOME/local/vev"
        case "''${cwd,,}/" in
          "''${vev_root,,}/"*) exec npmrc-token docker compose "$@" ;;
        esac
        exec docker compose "$@"
      '';
    })
    (pkgs.writeShellApplication {
      name = "vault-backup";
      runtimeInputs = [
        pkgs.bitwarden-cli
        pkgs.coreutils
        pkgs.expect
        pkgs.jq
      ];
      text = ''
        export VAULTWARDEN_URL=${lib.escapeShellArg vaultwardenUrl}
        ${builtins.readFile ../../../../scripts/user/vault-backup.sh}
      '';
    })
  ];
}
