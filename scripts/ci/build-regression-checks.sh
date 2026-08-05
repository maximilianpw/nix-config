#!/usr/bin/env bash

set -euo pipefail

nix build --no-link \
  .#checks.x86_64-linux.homelab-ingress-regression \
  .#checks.x86_64-linux.homelab-inventory-regression \
  .#checks.x86_64-linux.tailscale-serve-regression \
  .#checks.x86_64-linux.paperless-backup-regression \
  .#checks.x86_64-linux.paperless-config-regression \
  .#checks.x86_64-linux.homepage-calendar-regression \
  .#checks.x86_64-linux.monitoring-regression \
  .#checks.x86_64-linux.fleet-agent-forwarding-regression \
  .#checks.x86_64-linux.fleet-ssh-regression \
  .#checks.x86_64-linux.fleet-ghostty-regression \
  .#checks.x86_64-linux.fleet-trust-regression
