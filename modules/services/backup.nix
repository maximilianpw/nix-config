{
  config,
  pkgs,
  lib,
  ...
}: {
  # ===========================================
  # Backup Services
  # ===========================================
  # Time Machine-like backups using Borg Backup
  # Target: /mnt/backups (external Toshiba drive)

  # -------------------------------------------
  # Backup Drive Mount
  # -------------------------------------------
  fileSystems."/mnt/backups" = {
    device = "/dev/disk/by-uuid/73afcc5c-6148-4dc2-ae0e-61649ce71120";
    fsType = "ext4";
    options = [
      "nofail" # Don't fail boot if drive is missing
      "x-systemd.automount" # Mount on first access
      "x-systemd.idle-timeout=10min" # Unmount after 10min idle (spin down drive)
    ];
  };

  # -------------------------------------------
  # Borg Backup
  # -------------------------------------------
  services.borgbackup.jobs.main = {
    paths = [
      "/home/maxpw"
      "/var/lib" # Service data (Nextcloud, Home Assistant, etc.)
    ];

    exclude = [
      # Caches and temp files
      "/home/*/.cache"
      "/home/*/.local/share/Trash"
      "/home/*/Downloads"
      "/home/*/.npm"
      "/home/*/.cargo/registry"
      "/home/*/.rustup"
      "/home/*/.local/share/Steam"
      "/home/*/.wine"

      # Large reproducible directories
      "/home/*/go/pkg"
      "/home/*/.gradle"
      "/home/*/.m2"
      "/home/*/node_modules"
      "**/node_modules"
      "**/.git/objects"
      "**/__pycache__"
      "**/.mypy_cache"
      "**/.pytest_cache"

      # Nix-related (reproducible from config)
      "/home/*/.nix-defexpr"
      "/home/*/.nix-profile"

      # Secrets already backed up elsewhere
      "/var/lib/sops-nix"

      # Temporary/runtime data
      "/var/lib/systemd/coredump"
      "/var/lib/docker" # Can be large, typically reproducible
    ];

    repo = "/mnt/backups/borg";

    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sops.secrets.borg-backup-passphrase.path}";
    };

    compression = "auto,zstd";

    # Prune old backups (Time Machine-like retention)
    prune.keep = {
      within = "1d"; # Keep all backups from last 24h
      daily = 7; # Keep 7 daily backups
      weekly = 4; # Keep 4 weekly backups
      monthly = 6; # Keep 6 monthly backups
      yearly = 2; # Keep 2 yearly backups
    };

    # Run daily at 3 AM
    startAt = "daily";
    persistentTimer = true;

    # Extra borg create options
    extraCreateArgs = [
      "--stats"
      "--checkpoint-interval"
      "600"
    ];

    # Pre/post hooks
    preHook = ''
      echo "Starting backup at $(date)"
    '';

    postHook = ''
      echo "Backup finished at $(date)"
    '';

    # Allow backup to complete even if some files change during backup
    extraArgs = "--lock-wait 60";
  };

  # Borg package for manual operations
  environment.systemPackages = [pkgs.borgbackup];
}
