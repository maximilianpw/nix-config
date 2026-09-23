{
  config,
  lib,
  pkgs,
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  homepage = config.services.homepage-dashboard;

  groupName = group: builtins.head (builtins.attrNames group);
  allCards = lib.concatMap (group: group.${groupName group}) homepage.services;
  serviceGroup = name:
    lib.findFirst
    (group: builtins.hasAttr name group)
    (throw "Homepage service group not found: ${name}")
    homepage.services;
  serviceCard = group: name:
    lib.findFirst
    (card: builtins.hasAttr name card)
    (throw "Homepage service card not found: ${group}/${name}")
    (serviceGroup group).${group};
  nextcloudCard = (serviceCard "Applications" "Nextcloud").Nextcloud;
  cardUsesLoopbackMonitor = card: let
    name = groupName card;
  in
    lib.hasPrefix "http://127.0.0.1:" card.${name}.siteMonitor;
in
  assert lib.assertMsg (lib.all cardUsesLoopbackMonitor allCards)
  "Every Homepage service card must monitor its direct loopback endpoint";
  assert lib.assertMsg (nextcloudCard.siteMonitor == "${homelab.loopbackUrl homelab.publicServices.nextcloud.port}/status.php")
  "Homepage must monitor Nextcloud's non-redirecting status endpoint";
    pkgs.runCommand "homepage-regression" {} ''
      touch "$out"
    ''
