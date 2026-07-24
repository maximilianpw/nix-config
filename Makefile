.PHONY: help bootstrap chezmoi-bootstrap chezmoi-check chezmoi-preview chezmoi-apply rebuild rebuild-processes cleanup-rebuild check-nvim check-scripts lint update update-all update-packages build generations rollback wsl info

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

chezmoi-bootstrap: ## Clone dotfiles source without applying it
	@$(SCRIPT_DIR)/chezmoi.sh bootstrap

chezmoi-check: ## Validate chezmoi source with a no-write dry run
	@$(SCRIPT_DIR)/chezmoi.sh check

chezmoi-preview: ## Show changes chezmoi would apply
	@$(SCRIPT_DIR)/chezmoi.sh preview

chezmoi-apply: ## Review and interactively apply chezmoi dotfiles
	@$(SCRIPT_DIR)/chezmoi.sh apply

rebuild: ## Rebuild system configuration (NixOS/Darwin)
	@echo "Starting system rebuild..."
	@$(SCRIPT_DIR)/nixos-rebuild.sh

rebuild-processes: ## Show the identity-checked active rebuild process tree
	@$(SCRIPT_DIR)/lib/rebuild-state.sh list

cleanup-rebuild: ## Stop only the tracked active rebuild process tree
	@$(SCRIPT_DIR)/lib/rebuild-state.sh cleanup

update: ## Update flake inputs (skips Hyprland & NixOS-only inputs)
	@echo "Updating shared flake inputs (skipping hyprland, sops-nix, nixos-wsl, disko)..."
	@nix flake update nixpkgs nixpkgs-unstable home-manager nix-darwin fenix llm-agents
	@echo "Done! Run 'make rebuild' to apply updates."

update-all: ## Update all flake inputs including Hyprland & NixOS-only
	@echo "Updating all flake inputs..."
	@nix flake update
	@echo "Done! Run 'make rebuild' to apply updates."

update-packages: ## Bump repo-local custom packages (helium, obsidian, coderabbit, cliproxyapi) via nix-update
	@echo "Bumping custom packages via nix-update..."
	@echo "Note: Linux-only packages (helium, obsidian, cliproxyapi) cannot be built"
	@echo "from macOS. The CI workflow handles them; here we only bump what"
	@echo "this host can actually evaluate."
	@echo "(skills/hunkdiff come from the llm-agents input: use 'make update')"
	@for pkg in helium obsidian coderabbit cliproxyapi; do \
		echo ">> nix-update $$pkg"; \
		nix run .#nix-update -- --flake "$$pkg" || echo "(skipped: $$pkg)"; \
	done


check-nvim: ## Verify every tool the Neovim config uses is on PATH
	@$(SCRIPT_DIR)/check-nvim-tooling.sh

check-scripts: ## Run shell syntax, ShellCheck, and safety regression tests
	@bash -n $(SCRIPT_DIR)/*.sh $(SCRIPT_DIR)/lib/*.sh $(SCRIPT_DIR)/tests/*.sh
	@shellcheck --severity=warning $(SCRIPT_DIR)/*.sh $(SCRIPT_DIR)/lib/*.sh $(SCRIPT_DIR)/tests/*.sh
	@for test in $(SCRIPT_DIR)/tests/*-test.sh; do bash "$$test"; done

lint: ## Run Nix linters (statix, deadnix) and format check
	nix build .#checks.$$(nix eval --impure --raw --expr builtins.currentSystem).pre-commit-check --no-link

build: ## Build system configuration without switching
	@echo "Building system configuration..."
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		nix build ".#darwinConfigurations.joyce.system"; \
	else \
		host="$$(hostname -s)"; \
		case "$$host" in main-pc) host=kim ;; wsl) host=cuno ;; esac; \
		nix build ".#nixosConfigurations.$$host.config.system.build.toplevel"; \
	fi
	@echo "Build complete!"

generations: ## List system generations
	@echo "System generations:"
	@sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

rollback: ## Rollback to previous generation
	@echo "Rolling back to previous generation..."
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		sudo darwin-rebuild --rollback; \
	else \
		sudo nixos-rebuild --rollback; \
	fi
	@echo "Rollback complete!"

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
