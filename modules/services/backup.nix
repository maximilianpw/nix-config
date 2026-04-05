{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.custom.backup;
in {
  options.custom.backup = {
    enable = lib.mkEnableOption "borgbackup to external drive";

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "/home/maxpw/nix-config"
        "/home/maxpw/Documents"
        "/home/maxpw/Projects"
        "/home/maxpw/.config"
        "/home/maxpw/.local/share"
        "/home/maxpw/.ssh"
        "/home/maxpw/.gnupg"
        "/var/lib"
      ];
      description = "Paths to back up";
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "**/node_modules"
        "**/.git/objects"
        "**/__pycache__"
        "**/.cache"
      ];
      description = "Patterns to exclude from backup";
    };

    repo = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/backups/borg";
      description = "Borg repository path";
    };

    driveUUID = lib.mkOption {
      type = lib.types.str;
      default = "73afcc5c-6148-4dc2-ae0e-61649ce71120";
      description = "UUID of the backup drive";
    };

    retention = lib.mkOption {
      type = lib.types.attrs;
      default = {
        within = "1d";
        daily = 7;
        weekly = 4;
        monthly = 6;
        yearly = 2;
      };
      description = "Borg prune retention policy";
    };
  };

  config = lib.mkIf cfg.enable {
    fileSystems."/mnt/backups" = {
      device = "/dev/disk/by-uuid/${cfg.driveUUID}";
      fsType = "ext4";
      options = [
        "nofail"
        "x-systemd.automount"
        "x-systemd.idle-timeout=10min"
      ];
    };

    services.borgbackup.jobs.main = {
      paths = cfg.paths;
      inherit (cfg) exclude repo;

      encryption = {
        mode = "repokey-blake2";
        passCommand = "cat ${config.sops.secrets.borg-backup-passphrase.path}";
      };

      compression = "auto,zstd";

      prune.keep = cfg.retention;

      startAt = "03:00";
      persistentTimer = true;

      extraCreateArgs = [
        "--stats"
        "--checkpoint-interval"
        "600"
      ];

      preHook = ''
        echo "Starting backup at $(date)"
      '';

      postHook = ''
        echo "Backup finished at $(date)"
      '';

      extraArgs = "--lock-wait 60";
    };

    environment.systemPackages = [pkgs.borgbackup];
  };
}
