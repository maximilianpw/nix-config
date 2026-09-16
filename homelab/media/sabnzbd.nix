{
  config,
  lib,
  pkgs,
  ...
}: let
  common = import ./common.nix {inherit config lib pkgs;};
  inherit
    (common)
    endpoints
    mkDeferredVpnService
    mkVpnContainer
    mullvadConnectionGate
    sabContainerAddress
    sabContainerHostAddress
    sabContainerLocalAddress
    sabContainerPort
    sabnzbdUid
    usenetRoot
    ;
in {
  containers.sab = mkVpnContainer {
    hostAddress = sabContainerHostAddress;
    localAddress = sabContainerLocalAddress;
    port = sabContainerPort;
    # Keep SABnzbd's existing host state path to make this namespace move
    # migration-free; the separate container root preserves Mullvad's login.
    bindMounts = {
      ${usenetRoot} = {
        hostPath = usenetRoot;
        isReadOnly = false;
      };
      "/var/lib/sabnzbd" = {
        hostPath = "/var/lib/sabnzbd";
        isReadOnly = false;
      };
    };

    applicationModule = {
      lib,
      pkgs,
      ...
    }: let
      sabPreStart = pkgs.writeShellApplication {
        name = "sabnzbd-vpn-prestart";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.mullvad
        ];
        text = mullvadConnectionGate "SABnzbd";
      };
    in {
      nixpkgs.config.allowUnfreePredicate = package: lib.getName package == "unrar";
      users.users.sabnzbd.uid = sabnzbdUid;

      services.sabnzbd = {
        enable = true;
        # Preserve credentials entered in the WebUI while keeping network,
        # path, TLS, and category policy declarative.
        configFile = null;
        allowConfigWrite = true;
        group = "media";
        openFirewall = false;
        settings = {
          misc = {
            host = sabContainerAddress;
            port = sabContainerPort;
            download_dir = "${usenetRoot}/incomplete";
            complete_dir = "${usenetRoot}/complete";
            backup_dir = "/var/lib/sabnzbd/backups";
            permissions = "2775";
            host_whitelist = "${endpoints.sabnzbd.host}, localhost, 127.0.0.1, ${sabContainerAddress}";
            # The host veth is the only direct client. Tailscale Serve's XFF
            # value must also remain within the private tailnet ranges.
            local_ranges = "${sabContainerHostAddress}, 100.64.0.0/10, fd7a:115c:a1e0::/48";
            verify_xff_header = true;
          };
          servers.eweka = {
            name = "eweka";
            displayname = "Eweka";
            host = "news.eweka.nl";
            port = 563;
            connections = 20;
            ssl = true;
            ssl_verify = "strict";
            required = true;
            priority = 0;
          };
          categories = {
            "*" = {
              order = 0;
              pp = 3;
              script = "None";
              dir = "";
              priority = 0;
            };
            "sonarr-usenet" = {
              order = 1;
              pp = 3;
              script = "Default";
              dir = "tv";
              priority = 0;
            };
            "radarr-usenet" = {
              order = 2;
              pp = 3;
              script = "Default";
              dir = "movies";
              priority = 0;
            };
            "lidarr-usenet" = {
              order = 3;
              pp = 3;
              script = "Default";
              dir = "music";
              priority = 0;
            };
          };
        };
      };

      systemd = mkDeferredVpnService {
        serviceName = "sabnzbd";
        description = "Start SABnzbd after the container reports ready";
        # Keep the module's generated config reconciliation after the
        # privileged VPN gate instead of replacing its ExecStartPre.
        vpnGate = lib.mkBefore ["+${lib.getExe sabPreStart}"];
        extraServiceConfig.StateDirectoryMode = "0700";
      };
    };
  };
}
