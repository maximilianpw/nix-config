{
  # Public stand-in for the token-gated rex input, used only by CI through
  # `nix flake lock --override-input rex path:./tests/stubs/rex`. CI has no
  # package token and pushes Kim's builds to a public Cachix cache, so the
  # proprietary binary must never be fetched or built there. Mirror the options
  # this repository sets from the real nixos-module.nix and
  # home-manager-module.nix when they change; the service is inert.
  description = "CI stub for the token-gated Rex flake";

  outputs = _: {
    nixosModules.default = {
      config,
      lib,
      pkgs,
      ...
    }: let
      cfg = config.services.rex.loginServer;
      inherit (lib) mkOption types;
    in {
      options.services.rex.loginServer = {
        enable = lib.mkEnableOption "the Rex login server CI stub";
        accounts = mkOption {
          type = types.attrsOf (types.submodule {
            options.principals = mkOption {
              type = types.listOf types.str;
              default = [];
            };
          });
          default = {};
        };
        extraListen = mkOption {
          type = types.listOf types.str;
          default = [];
        };
      };

      config = lib.mkIf cfg.enable {
        environment.etc."rex/accounts.jsonc".text = builtins.toJSON {
          version = 1;
          accounts = lib.mapAttrs (_: a: {inherit (a) principals;}) cfg.accounts;
        };
        systemd.services.rex-login-server = {
          description = "Rex Login Server (CI stub)";
          wantedBy = ["multi-user.target"];
          serviceConfig.ExecStart = lib.getExe (pkgs.writeShellScriptBin "rex" "exit 1");
        };
      };
    };

    homeManagerModules.default = {lib, ...}: {
      options.programs.rex.enable = lib.mkEnableOption "the Rex CI stub";
    };
  };
}
