{
  # Public stand-in for the private superlocal input, used only by CI through
  # `nix flake lock --override-input superlocal path:./tests/stubs/superlocal`.
  # CI pushes Kim's builds to a public Cachix cache, so the real application
  # must never be fetched or built there. Mirror the real module's options
  # (superlocal's nix/module.nix) when they change; the service is inert.
  description = "CI stub for the private Superlocal flake";

  outputs = _: {
    nixosModules.default = {
      config,
      lib,
      pkgs,
      ...
    }: let
      cfg = config.services.superlocal;
      inherit (lib) mkOption types;
    in {
      options.services.superlocal = {
        enable = lib.mkEnableOption "the Superlocal CI stub";
        package = mkOption {
          type = types.package;
          default = (pkgs.writeShellScriptBin "superlocal" "exit 1") // {version = "0.0.0-ci-stub";};
        };
        webPort = mkOption {
          type = types.port;
          default = 5178;
        };
        apiPort = mkOption {
          type = types.port;
          default = 8790;
        };
        bind = mkOption {
          type = types.enum ["127.0.0.1" "0.0.0.0"];
          default = "127.0.0.1";
        };
        origin = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        stateDir = mkOption {
          type = types.str;
          default = "/var/lib/superlocal";
        };
        environmentFile = mkOption {
          type = types.nullOr types.path;
          default = null;
        };
        user = mkOption {
          type = types.str;
          default = "superlocal";
        };
        group = mkOption {
          type = types.str;
          default = "superlocal";
        };
        extraEnvironment = mkOption {
          type = types.attrsOf types.str;
          default = {};
        };
      };

      config = lib.mkIf cfg.enable {
        users.groups.${cfg.group} = {};
        users.users.${cfg.user} = {
          isSystemUser = true;
          inherit (cfg) group;
        };
        systemd.services.superlocal = {
          description = "Superlocal (CI stub)";
          wantedBy = ["multi-user.target"];
          serviceConfig = {
            ExecStart = lib.getExe cfg.package;
            User = cfg.user;
            Group = cfg.group;
            StateDirectory = lib.removePrefix "/var/lib/" cfg.stateDir;
          };
        };
      };
    };
  };
}
