{
  configs,
  hosts,
  lib,
  pkgs,
}: let
  enrolled = lib.filterAttrs (_: host: host.client != null) hosts;
  expectedKeys =
    lib.mapAttrsToList (_: host: ''from="${lib.concatStringsSep "," host.client.tailscaleIps}" ${host.client.key}'')
    enrolled;
  configuredKeys = map (entry: entry.config.users.users.${entry.user}.openssh.authorizedKeys.keys) configs;
  tailnetUsers = user: [
    "${user}@100.64.0.0/10"
    "${user}@fd7a:115c:a1e0::/48"
  ];
  hasBothAddressFamilies = host:
    lib.any (lib.hasPrefix "100.") host.client.tailscaleIps
    && lib.any (lib.hasPrefix "fd7a:115c:a1e0:") host.client.tailscaleIps;
  linuxPolicyMatches = entry: let
    settings = entry.config.services.openssh.settings;
  in
    settings.AllowUsers
    == tailnetUsers entry.user
    && settings.AuthenticationMethods == "publickey"
    && !settings.PasswordAuthentication
    && !settings.KbdInteractiveAuthentication
    && settings.PermitRootLogin == "no";
  darwinPolicyMatches = entry: let
    config = entry.config.services.openssh.extraConfig;
  in
    lib.all (lib.flip lib.hasInfix config) [
      "PasswordAuthentication no"
      "KbdInteractiveAuthentication no"
      "PermitRootLogin no"
      "AuthenticationMethods publickey"
      "AllowUsers ${lib.concatStringsSep " " (tailnetUsers entry.user)}"
    ];
in
  assert lib.assertMsg (builtins.length configs == builtins.length (builtins.attrNames hosts))
  "Fleet trust regression must cover every inventory host";
  assert lib.assertMsg (lib.all hasBothAddressFamilies (builtins.attrValues enrolled))
  "Every enrolled Fleet client must declare Tailscale IPv4 and IPv6 addresses";
  assert lib.assertMsg (lib.all (keys: keys == expectedKeys) configuredKeys)
  "Every Fleet server must receive exactly the same derived enrolled-client key set";
  assert lib.assertMsg (lib.all (entry:
    if entry.isDarwin
    then darwinPolicyMatches entry
    else linuxPolicyMatches entry)
  configs)
  "Every Fleet server must enforce key-only tailnet-source SSH policy";
    pkgs.runCommand "fleet-trust-regression" {} ''
      touch "$out"
    ''
