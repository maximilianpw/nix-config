.PHONY: help bootstrap rebuild rebuild-check rebuild-verbose rebuild-processes cleanup-rebuild check-nvim update update-all update-packages build generations rollback wsl info

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

rebuild-check: ## Rebuild with flake check before switching
	@echo "Starting system rebuild with flake check..."
	@$(SCRIPT_DIR)/nixos-rebuild.sh --check

rebuild-verbose: ## Rebuild with live build logs (-L -v --show-trace)
	@echo "Starting system rebuild with verbose output..."
	@$(SCRIPT_DIR)/nixos-rebuild.sh --verbose

rebuild-processes: ## Show Nix processes related to the last rebuild log
	@echo "Nix processes related to this config or the last rebuild log:"
	@{ \
		pattern='nix-config|darwin-rebuild|nixos-rebuild'; \
		if [ -f nixos-switch.log ]; then \
			drv_pattern=$$(sed -n 's|.*/\([^/]*\.drv\).*|\1|p' nixos-switch.log | sort -u | paste -sd '|' -); \
			if [ -n "$$drv_pattern" ]; then \
				pattern="$$pattern|nix-build-($$drv_pattern)-"; \
			fi; \
		fi; \
		ps -axo pid,ppid,pgid,stat,etime,command | grep -E "$$pattern" | grep -v grep || true; \
	}

cleanup-rebuild: ## Stop Nix build processes related to the last interrupted rebuild
	@echo "Stopping Nix processes related to this config or the last rebuild log..."
	@{ \
		pattern='nix-config|darwin-rebuild|nixos-rebuild'; \
		if [ -f nixos-switch.log ]; then \
			drv_pattern=$$(sed -n 's|.*/\([^/]*\.drv\).*|\1|p' nixos-switch.log | sort -u | paste -sd '|' -); \
			if [ -n "$$drv_pattern" ]; then \
				pattern="$$pattern|nix-build-($$drv_pattern)-"; \
			fi; \
		fi; \
		pids=$$(ps -axo pid,command | grep -E "$$pattern" | grep -v grep | awk '{print $$1}'); \
		if [ -z "$$pids" ]; then \
			echo "No matching rebuild processes found."; \
			exit 0; \
		fi; \
		echo "Sending TERM to: $$pids"; \
		sudo kill -TERM $$pids 2>/dev/null || true; \
		sleep 3; \
		remaining=$$(ps -axo pid,command | grep -E "$$pattern" | grep -v grep | awk '{print $$1}'); \
		if [ -n "$$remaining" ]; then \
			echo "Still running; sending KILL to: $$remaining"; \
			sudo kill -KILL $$remaining 2>/dev/null || true; \
		fi; \
	}

update: ## Update flake inputs (skips Hyprland & NixOS-only inputs)
	@echo "Updating shared flake inputs (skipping hyprland, sops-nix, nixos-wsl, disko)..."
	@nix flake update nixpkgs nixpkgs-unstable home-manager nix-darwin fenix llm-agents
	@echo "Done! Run 'make rebuild' to apply updates."

update-all: ## Update all flake inputs including Hyprland & NixOS-only
	@echo "Updating all flake inputs..."
	@nix flake update
	@echo "Done! Run 'make rebuild' to apply updates."

update-packages: ## Bump repo-local custom packages (helium, obsidian, t3code, coderabbit) via nix-update
	@echo "Bumping custom packages via nix-update..."
	@echo "Note: Linux-only packages (helium, obsidian, t3code) cannot be built"
	@echo "from macOS. The CI workflow handles them; here we only bump what"
	@echo "this host can actually evaluate."
	@echo "(skills/hunkdiff come from the llm-agents input: use 'make update')"
	@for pkg in helium obsidian t3code coderabbit; do \
		echo ">> nix-update $$pkg"; \
		nix run nixpkgs#nix-update -- --flake "$$pkg" || echo "(skipped: $$pkg)"; \
	done


check-nvim: ## Verify every tool the Neovim config uses is on PATH
	@$(SCRIPT_DIR)/check-nvim-tooling.sh

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

wsl: ## Build WSL tarball for import
	@echo "Building WSL tarball..."
	@nix build ".#nixosConfigurations.wsl.config.system.build.tarballBuilder" --no-link
	@echo "WSL tarball build complete!"

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
