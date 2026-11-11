.PHONY: help bootstrap rebuild rebuild-processes cleanup-rebuild check-scripts check-linux lint update update-all update-flake-inputs update-packages update-t3code update-nvim-plugins update-container-images update-fish-plugins update-agent-plugins build generations rollback gc wsl info

# Default target
.DEFAULT_GOAL := help

# Configuration
SCRIPT_DIR := scripts
CONFIG_DIR := $(shell pwd)
# Inputs bumped by `make update`; `make update-all` refreshes the full inventory.
# nixvim follows nixpkgs-unstable, so it must move in lockstep with it.
CORE_INPUTS := nixpkgs nixpkgs-unstable home-manager nix-darwin fenix llm-agents rex nixvim hjem
# Only update commands inherit temporary GitHub credentials.
UPDATE_AUTH := $(SCRIPT_DIR)/dev/with-github-auth.sh
SHELL_SCRIPTS = $(SCRIPT_DIR)/*/*.sh $(SCRIPT_DIR)/rebuild/lib/*.sh tests/*.sh packages/scripts/*.sh

help: ## Show this help message
	@echo "Nix-Config Management Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

bootstrap: ## Bootstrap a new system (initial setup)
	@echo "Starting bootstrap process..."
	@$(SCRIPT_DIR)/rebuild/bootstrap.sh

rebuild: ## Build and switch this checkout's configuration (NixOS/Darwin)
	@$(SCRIPT_DIR)/rebuild/nixos-rebuild.sh "$(CONFIG_DIR)"

rebuild-processes: ## Show the identity-checked active rebuild process tree
	@$(SCRIPT_DIR)/rebuild/lib/rebuild-state.sh list

cleanup-rebuild: ## Stop only the tracked active rebuild process tree
	@$(SCRIPT_DIR)/rebuild/lib/rebuild-state.sh cleanup

update: ## Update core flake inputs, T3 Code, and Neovim plugin pins
	@echo "Updating core flake inputs: $(CORE_INPUTS)"
	@$(UPDATE_AUTH) nix flake update $(CORE_INPUTS)
	@$(MAKE) update-agent-plugins
	@$(MAKE) update-t3code
	@$(MAKE) update-nvim-plugins
	@echo "Done! Run 'make rebuild' to apply updates."

update-all: ## Refresh every repo-managed runtime pin (no deployment)
	@failed=""; \
	for target in update-flake-inputs update-agent-plugins update-packages update-t3code update-nvim-plugins update-container-images update-fish-plugins; do \
		echo "=== $$target ==="; \
		$(MAKE) "$$target" PACKAGES= || failed="$$failed $$target"; \
	done; \
	if [ -n "$$failed" ]; then \
		echo "Update incomplete. Failed targets:$$failed" >&2; \
		echo "Successful updates remain in the worktree. Review the diff and retry the failed targets before building." >&2; \
		exit 1; \
	fi; \
	echo "All runtime pins refreshed. Review the diff, build and check before 'make rebuild'. Nothing was deployed."

update-flake-inputs: ## Refresh explicit flake release/commit pins and every locked input
	@status=0; \
	$(UPDATE_AUTH) python3 $(SCRIPT_DIR)/dev/update-source-pins.py flake-inputs || status=1; \
	$(UPDATE_AUTH) nix flake update || status=1; \
	exit $$status

update-packages: ## Refresh all custom packages, including cross-platform binary hashes
	@$(UPDATE_AUTH) $(SCRIPT_DIR)/ci/update-packages.sh --local

update-t3code: ## Refresh the shared Linux/macOS T3 Code nightly pin
	@$(UPDATE_AUTH) python3 packages/scripts/update-t3code.py

update-container-images: ## Refresh homelab image digests without pulling into Docker or restarting services
	@$(UPDATE_AUTH) nix shell --inputs-from . nixpkgs#skopeo --command python3 $(SCRIPT_DIR)/dev/update-source-pins.py containers

update-agent-plugins: ## Match Plannotator agent-plugin pins to the locked CLI
	@$(UPDATE_AUTH) python3 $(SCRIPT_DIR)/dev/update-source-pins.py agent-plugins

update-fish-plugins: ## Refresh Fish plugin source revisions and hashes
	@$(UPDATE_AUTH) python3 $(SCRIPT_DIR)/dev/update-source-pins.py fish-plugins

update-nvim-plugins: ## Move Neovim's pinned Lua plugins to upstream HEAD (replaces :Lazy update)
	@$(UPDATE_AUTH) $(SCRIPT_DIR)/dev/nvim-plugin-pins.sh --all
	@echo "Check the editor before rebuilding:"
	@echo "  nix build .#checks.$$(nix eval --impure --raw --expr builtins.currentSystem).nvim-candidate .#checks.$$(nix eval --impure --raw --expr builtins.currentSystem).hjem-lifecycle-regression --no-link"

check-scripts: ## Run shell syntax, ShellCheck, and safety regression tests
	@command -v shellcheck >/dev/null || { echo "shellcheck not on PATH; run inside 'nix develop'" >&2; exit 1; }
	@set -e; for script in $(SHELL_SCRIPTS); do bash -n "$$script"; done
	@shellcheck --severity=warning $(SHELL_SCRIPTS)
	@set -e; for test in $(SCRIPT_DIR)/tests/*-test.sh; do bash "$$test" || { echo "FAILED: $$test" >&2; exit 1; }; done

check-linux: ## Evaluate every x86_64-linux check (forces regression assertions on any host)
	@$(SCRIPT_DIR)/dev/check-linux-eval.sh

lint: ## Run Nix linters (statix, deadnix) and format check
	nix build .#checks.$$(nix eval --impure --raw --expr builtins.currentSystem).pre-commit-check --no-link

build: ## Build system configuration without switching
	@echo "Building system configuration..."
	@$(SCRIPT_DIR)/rebuild/nixos-build.sh "$(CONFIG_DIR)"
	@echo "Build complete!"

generations: ## List system generations
	@echo "System generations:"
	@sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

rollback: ## Rollback to previous generation (Kim re-runs its homelab checks)
	@$(SCRIPT_DIR)/rebuild/nixos-rollback.sh

gc: ## Delete old generations now (keeps the last 5 and anything from 30 days)
	@nh clean all --keep 5 --keep-since 30d

wsl: ## Build the WSL import image
	@echo "Building WSL import image..."
	@mkdir -p .artifacts
	@nix build ".#nixosConfigurations.cuno.config.system.build.tarballBuilder" --out-link .artifacts/wsl-builder
	@sudo rm -f .artifacts/nixos.wsl
	@sudo .artifacts/wsl-builder/bin/nixos-wsl-tarball-builder "$(CONFIG_DIR)/.artifacts/nixos.wsl"
	@test -s .artifacts/nixos.wsl
	@echo "WSL image: $(CONFIG_DIR)/.artifacts/nixos.wsl"

info: ## Show system information
	@echo "System Information:"
	@echo "  Platform:    $$(uname -s)"
	@echo "  Hostname:    $$(hostname)"
	@echo "  User:        $$(whoami)"
	@echo "  Config dir:  $(CONFIG_DIR)"
	@echo "  Nix version: $$(nix --version)"
	@if [ -f "flake.lock" ]; then \
		echo "  Last update: $$(stat -c %y flake.lock 2>/dev/null || stat -f '%Sm' flake.lock)"; \
	fi
