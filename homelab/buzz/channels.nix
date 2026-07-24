{
  config,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../../lib/homelab.nix {inherit lib;};
  inherit ((homelab.endpoints config.homelab.tailnet.domain)) buzz;

  # Nix owns channel existence and metadata only. Membership and roles remain
  # collaborative relay state managed in Buzz Desktop; reconciliation must
  # never add, remove, or rewrite channel members.
  managedChannels = {
    inbox = {
      type = "stream";
      visibility = "private";
      description = "Quick capture for notes, links, ideas, and tasks awaiting organization";
    };

    projects = {
      type = "forum";
      visibility = "private";
      description = "Active projects and initiatives, organized as individual threads";
    };

    homelab-ops = {
      type = "forum";
      visibility = "private";
      description = "Homelab operations, incidents, maintenance, upgrades, and service changes";
    };

    ai-lab = {
      type = "forum";
      visibility = "private";
      description = "AI agents, models, prompts, tooling, workflows, and experiments";
    };

    knowledge-base = {
      type = "forum";
      visibility = "private";
      description = "Durable decisions, runbooks, references, and lessons learned";
    };

    activity = {
      type = "stream";
      visibility = "private";
      description = "Automated deployment, monitoring, backup, and workflow activity";
    };

    vev = {
      type = "forum";
      visibility = "private";
      description = "VEV work, projects, decisions, references, and follow-ups";
    };

    nix-config = {
      type = "stream";
      visibility = "open";
      description = "Nix architecture, implementation, and review";
    };
  };

  reconcileChannelsScript = pkgs.writeShellScript "buzz-reconcile-channels" ''
    set -euo pipefail

    ${lib.concatMapStringsSep "\n" (name: let
      channel = managedChannels.${name};
      relayVisibility =
        if channel.visibility == "open"
        then "public"
        else channel.visibility;
    in ''
      matches="$(${lib.getExe pkgs.buzz-cli} channels search \
        --query ${lib.escapeShellArg name} --exact --include-archived)"
      match_count="$(printf '%s' "$matches" | ${lib.getExe pkgs.jq} -r 'length')"
      if [ "$match_count" -eq 0 ]; then
        ${lib.getExe pkgs.buzz-cli} channels create \
          --name ${lib.escapeShellArg name} \
          --type ${lib.escapeShellArg channel.type} \
          --visibility ${lib.escapeShellArg channel.visibility} \
          --description ${lib.escapeShellArg channel.description}
      elif [ "$match_count" -ne 1 ]; then
        echo "Managed Buzz channel ${name} must resolve exactly once, found $match_count" >&2
        exit 1
      else
        current="$(printf '%s' "$matches" | ${lib.getExe pkgs.jq} -c '.[0]')"
        channel_id="$(printf '%s' "$current" | ${lib.getExe pkgs.jq} -r '.channel_id')"
        actual_type="$(printf '%s' "$current" | ${lib.getExe pkgs.jq} -r '.channel_type')"
        actual_visibility="$(printf '%s' "$current" | ${lib.getExe pkgs.jq} -r '.visibility')"
        if [ "$actual_type" != ${lib.escapeShellArg channel.type} ]; then
          echo "Managed Buzz channel ${name} has immutable type '$actual_type', expected ${channel.type}" >&2
          exit 1
        fi
        if [ "$actual_visibility" != ${lib.escapeShellArg relayVisibility} ]; then
          echo "Managed Buzz channel ${name} has immutable visibility '$actual_visibility', expected ${relayVisibility}" >&2
          exit 1
        fi

        archived="$(printf '%s' "$current" | ${lib.getExe pkgs.jq} -r '.archived')"
        if [ "$archived" = true ]; then
          ${lib.getExe pkgs.buzz-cli} channels unarchive --channel "$channel_id"
        fi

        actual_name="$(printf '%s' "$current" | ${lib.getExe pkgs.jq} -r '.name')"
        actual_description="$(printf '%s' "$current" | ${lib.getExe pkgs.jq} -r '.about // ""')"
        if [ "$actual_name" != ${lib.escapeShellArg name} ] || \
           [ "$actual_description" != ${lib.escapeShellArg channel.description} ]; then
          ${lib.getExe pkgs.buzz-cli} channels update \
            --channel "$channel_id" \
            --name ${lib.escapeShellArg name} \
            --description ${lib.escapeShellArg channel.description}
        fi
      fi
    '') (lib.attrNames managedChannels)}
  '';
in {
  sops = {
    secrets.buzz-owner-private-key = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    templates."buzz-channels.env" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = ["buzz-channels.service"];
      content = ''
        BUZZ_RELAY_URL=wss://${buzz.host}
        BUZZ_PRIVATE_KEY=${config.sops.placeholder.buzz-owner-private-key}
      '';
    };
  };

  systemd.services.buzz-channels = {
    description = "Reconcile declarative Buzz channels";
    after = ["buzz.service" "network-online.target"];
    requires = ["buzz.service"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    restartTriggers = [reconcileChannelsScript];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      EnvironmentFile = config.sops.templates."buzz-channels.env".path;
      ExecStart = reconcileChannelsScript;
      User = "root";
      Group = "root";
      CapabilityBoundingSet = "";
      LockPersonality = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProcSubset = "pid";
      ProtectHome = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectProc = "invisible";
      ProtectSystem = "strict";
      RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      UMask = "0077";
    };
  };
}
