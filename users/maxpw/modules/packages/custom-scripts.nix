{
  hostname,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../../../../lib/homelab.nix {inherit lib;};
  vaultwardenUrl = homelab.privateUrl homelab.defaultTailnetDomain "vaultwarden";
  ynabMcpServerSource = pkgs.runCommand "ynab-mcp-server-source" {} ''
    mkdir --parents "$out"
    cp ${../../../../scripts/ynab-mcp-server.mjs} "$out/ynab-mcp-server.mjs"
    cp ${../../../../scripts/ynab-mcp-operations.json} "$out/ynab-mcp-operations.json"
  '';
in {
  home.packages = [
    (pkgs.writeShellApplication {
      name = "hs";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.fzf
        pkgs.herdr
        pkgs.jq
        pkgs.openssh
      ];
      text = ''
        export HERDR_SESSION_PICKER_LOCAL_HOST=${lib.escapeShellArg hostname}
        ${builtins.readFile ../../../../scripts/herdr-session-picker.sh}
      '';
    })
    (pkgs.writeShellApplication {
      name = "npmrc-token";
      text = builtins.readFile ../../../../scripts/npmrc-token.sh;
    })
    (pkgs.writeShellApplication {
      name = "ynab-mcp-server";
      runtimeInputs = [pkgs.nodejs pkgs._1password-cli];
      text = ''
        exec ${pkgs.nodejs}/bin/node ${ynabMcpServerSource}/ynab-mcp-server.mjs "$@"
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
        ${builtins.readFile ../../../../scripts/vault-backup.sh}
      '';
    })
  ];
}
