#!/usr/bin/env bash

set -euo pipefail

# CI cannot fetch the token-gated rex input, and must not build it: Kim's CI
# builds are pushed to a public Cachix cache. Relock the CI checkout onto the
# public stub before any other nix command. The rewritten flake.lock is
# CI-local and must never be committed.
nix flake lock --override-input rex path:./tests/stubs/rex
