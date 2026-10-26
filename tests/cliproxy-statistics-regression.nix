{
  kim,
  lib,
  pkgs,
}: let
  baseline = kim.config;
  enableWith = revision:
    (kim.extendModules {
      modules = [
        {
          homelab.cliproxyapi.quotaStatistics = {
            enable = true;
            reviewedBackendRevision = revision;
          };
        }
      ];
    }).config;
  enabled = enableWith "c050425e8dcc70654bef4745ccf62eed699f39da";
  unapproved = enableWith null;
  staleApproval = enableWith "an-older-reviewed-revision";
  proxy = enabled.systemd.services.cliproxyapi;
  baselineProxy = baseline.systemd.services.cliproxyapi;
  backendEnv = enabled.sops.templates."cliproxyapi-quota.env";
  databaseEnv = enabled.sops.templates."cliproxyapi-clickhouse.env";
  expect = import ./lib/expect.nix {inherit lib;};
  gateRejected = cfg: lib.any (a: !a.assertion && lib.hasInfix "reviewedBackendRevision" a.message) cfg.assertions;
  ingress = cfg: let
    vhost = cfg.services.nginx.virtualHosts."cliproxy.maximilian.pw";
  in {
    inherit (vhost) listen;
    locations =
      lib.mapAttrs (_: location: {
        inherit (location) proxyPass return alias extraConfig;
      })
      vhost.locations;
    inherit (cfg.services.nginx) appendHttpConfig;
  };
in
  assert expect.all "the default rebuild must retain the existing backend without new secrets or ClickHouse" [
    (!baseline.homelab.cliproxyapi.quotaStatistics.enable)
    (!baseline.services.cliproxyapi.enable)
    (!baseline.services.clickhouse.enable)
    (baselineProxy.serviceConfig.ExecStart == "${lib.getExe kim.pkgs.cliproxyapi} -config ${baseline.sops.templates."cliproxyapi.conf".path}")
    (!(baseline.sops.secrets ? cliproxyapi-clickhouse-password))
    (!(baseline.sops.secrets ? cliproxyapi-clickhouse-admin-password))
    (!lib.hasInfix "disable-auto-update-panel" baseline.sops.templates."cliproxyapi.conf".content)
    (gateRejected unapproved)
    (gateRejected staleApproval)
  ];
  assert expect.all "the approved switch must preserve auth, ingress, sidecar and runtime secret isolation" [
    (lib.all (a: a.assertion) enabled.assertions)
    enabled.services.cliproxyapi.enable
    enabled.services.clickhouse.enable
    (proxy.serviceConfig.User == baselineProxy.serviceConfig.User)
    (proxy.serviceConfig.WorkingDirectory == baselineProxy.serviceConfig.WorkingDirectory)
    (proxy.serviceConfig.User == "maxpw")
    (enabled.services.cliproxyapi.credentialDirectory == "/home/maxpw/.cli-proxy-api")
    (proxy.serviceConfig.ReadWritePaths == ["/home/maxpw/.cli-proxy-api"])
    (enabled.services.cliproxyapi.configFile == baseline.sops.templates."cliproxyapi.conf".path)
    (lib.replaceStrings ["  disable-auto-update-panel: true\n"] [""] enabled.sops.templates."cliproxyapi.conf".content == baseline.sops.templates."cliproxyapi.conf".content)
    (enabled.sops.templates."cliproxyapi.conf".owner == baseline.sops.templates."cliproxyapi.conf".owner)
    (enabled.systemd.services.cliproxyapi-quota.serviceConfig == baseline.systemd.services.cliproxyapi-quota.serviceConfig)
    (ingress enabled == ingress baseline)
    (enabled.services.clickhouse.serverConfig.listen_host == "127.0.0.1")
    (enabled.networking.firewall.allowedTCPPorts == baseline.networking.firewall.allowedTCPPorts)
    (backendEnv.owner == "root" && backendEnv.mode == "0400")
    (databaseEnv.owner == "root" && databaseEnv.mode == "0400")
    (lib.hasInfix enabled.sops.placeholder.cliproxyapi-clickhouse-password backendEnv.content)
    (lib.hasInfix enabled.sops.placeholder.cliproxyapi-clickhouse-password databaseEnv.content)
    (!lib.hasInfix "ADMIN_PASSWORD" backendEnv.content)
    (!lib.hasInfix enabled.sops.placeholder.cliproxyapi-clickhouse-admin-password backendEnv.content)
    (lib.hasInfix enabled.sops.placeholder.cliproxyapi-clickhouse-admin-password databaseEnv.content)
    (proxy.serviceConfig.EnvironmentFile == [backendEnv.path])
    (builtins.elem "cliproxyapi-quota-schema.service" proxy.requires)
  ];
    pkgs.runCommand "cliproxy-statistics-regression" {} ''
      echo 'Default-off, approval gates, enabled auth/ingress/sidecar preservation and secret separation passed' > "$out"
    ''
