#!/usr/bin/env bash

set -euo pipefail

# CI must not fetch/build private applications into the public Cachix cache.
# Keep this historical entry point for the workflows; all private application
# overrides below are CI-local and must never be committed after running it.
nix flake lock \
  --override-input superlocal path:./tests/stubs/superlocal \
  --override-input homelab-mcp path:./tests/stubs/homelab-mcp \
  --override-input food-tracker-src path:./tests/stubs/food-tracker
cp tests/stubs/food-tracker/package.nix packages/food-tracker.nix
