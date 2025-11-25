.PHONY: help bootstrap rebuild check update gc clean format diff test

# Default target
.DEFAULT_GOAL := help

# Configuration
SCRIPT_DIR := scripts
CONFIG_DIR := $(shell pwd)

help: ## Show this help message
	@echo "Nix-Config Management Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

bootstrap: ## Bootstrap a new system (initial setup)
	@echo "Starting bootstrap process..."
	@$(SCRIPT_DIR)/bootstrap.sh

rebuild: ## Rebuild system configuration (NixOS/Darwin)
	@echo "Starting system rebuild..."
	@$(SCRIPT_DIR)/nixos-rebuild.sh

check: ## Validate flake configuration
	@echo "Checking flake configuration..."
	@nix flake check

update: ## Update flake inputs to latest versions
	@echo "Updating flake inputs..."
	@nix flake update
	@echo "Done! Run 'make rebuild' to apply updates."

diff: ## Show uncommitted changes in Nix files
	@echo "Changes in Nix files:"
	@git diff --color=always -U2 '*.nix' || echo "No changes detected"

gc: ## Run garbage collection (clean old generations)
	@echo "Running aggressive garbage collection..."
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		nix-collect-garbage -d; \
	else \
		sudo nix-collect-garbage -d; \
	fi
	@echo "Aggressive garbage collection complete!"


build: ## Build system configuration without switching
	@echo "Building system configuration..."
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		nix build ".#darwinConfigurations.$$(hostname | sed 's/.local//' | tr '[:upper:]' '[:lower:]').system"; \
	else \
		nix build ".#nixosConfigurations.$$(hostname).config.system.build.toplevel"; \
	fi
	@echo "Build complete!"

generations: ## List system generations
	@echo "System generations:"
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		nix-env --list-generations --profile "$$HOME/.nix-profile"; \
	else \
		sudo nix-env --list-generations --profile /nix/var/nix/profiles/system; \
	fi

rollback: ## Rollback to previous generation
	@echo "Rolling back to previous generation..."
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		sudo darwin-rebuild --rollback; \
	else \
		sudo nixos-rebuild --rollback; \
	fi
	@echo "Rollback complete!"

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
