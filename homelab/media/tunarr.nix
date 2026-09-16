{
  config,
  lib,
  pkgs,
  ...
}: let
  common = import ./common.nix {inherit config lib pkgs;};
  inherit (common) endpoints mediaRoot usenetRoot;
  tunarrReconcileSettings = let
    ffmpeg = lib.getExe pkgs.ffmpeg;
    ffprobe = lib.getExe' pkgs.ffmpeg "ffprobe";
  in
    pkgs.writeShellScript "tunarr-reconcile-settings" ''
      exec ${lib.getExe pkgs.tunarr} --database /var/lib/tunarr settings update \
        --settings.ffmpeg.ffmpegExecutablePath=${ffmpeg} \
        --settings.ffmpeg.ffprobeExecutablePath=${ffprobe} \
        >/dev/null
    '';
in {
  custom.backup.applicationVersions.tunarr = pkgs.tunarr.version;

  users = {
    groups.tunarr = {};
    users.tunarr = {
      isSystemUser = true;
      group = "tunarr";
      extraGroups = [
        "media"
        "render"
        "video"
      ];
    };
  };

  systemd.services.tunarr = {
    description = "Tunarr personal TV server";
    # Keep the pre-split unit's exact dependency order when
    # RequiresMountsFor adds srv.mount.
    after = lib.mkBefore ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    path = [pkgs.libva-utils];
    environment = {
      HOME = "/var/lib/tunarr";
      TZ = config.time.timeZone;
      TUNARR_BIND_ADDR = "127.0.0.1";
      TUNARR_LOG_LEVEL = "info";
      TUNARR_SERVER_PORT = toString endpoints.tunarr.port;
    };
    serviceConfig = {
      User = "tunarr";
      Group = "tunarr";
      # Use the unambiguous CLI flag: v1.3.10's source and published docs
      # disagree about the corresponding environment variable's name.
      ExecStart = "${lib.getExe pkgs.tunarr} --database /var/lib/tunarr";
      ExecStartPre = tunarrReconcileSettings;
      InaccessiblePaths = [
        "${mediaRoot}/torrents"
        usenetRoot
      ];
      LockPersonality = true;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadOnlyPaths = ["${mediaRoot}/library"];
      ReadWritePaths = ["/var/lib/tunarr"];
      Restart = "on-failure";
      RestartSec = "5s";
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
        "AF_UNIX"
      ];
      RestrictSUIDSGID = true;
      StateDirectory = "tunarr";
      StateDirectoryMode = "0700";
      UMask = "0077";
      WorkingDirectory = "/var/lib/tunarr";
    };
  };
}
