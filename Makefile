# Makefile for NixOS Configuration Management

.PHONY: help switch build test boot check dry-run update gc optimize clean \
        rollback format lint edit show-config diff bootstrap hm-switch

.DEFAULT_GOAL := help

CONFIG_PATH ?= $(HOME)/Nixos-Dots
HOST ?= prague
USER ?= ivali

BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

help: ## Show this help message
	@echo "$(BLUE)NixOS (flake) Management$(NC)"
	@echo ""
	@echo "$(GREEN)Config:$(NC) $(CONFIG_PATH)#$(HOST)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(BLUE)%-15s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""

##@ Bootstrap

bootstrap: ## Link /etc/nixos -> repo and rebuild
	@bash $(CONFIG_PATH)/bootstrap.sh $(CONFIG_PATH)

##@ Build & Switch

switch: ## Build and activate new configuration
	sudo nixos-rebuild switch --flake "$(CONFIG_PATH)#$(HOST)" --accept-flake-config

build: ## Build without activating
	sudo nixos-rebuild build --flake "$(CONFIG_PATH)#$(HOST)" --accept-flake-config

test: ## Build and test without activating
	sudo nixos-rebuild test --flake "$(CONFIG_PATH)#$(HOST)" --accept-flake-config

boot: ## Build and set as boot default
	sudo nixos-rebuild boot --flake "$(CONFIG_PATH)#$(HOST)" --accept-flake-config

check: ## Check flake for errors
	nix flake check "$(CONFIG_PATH)"

dry-run: ## Show what would be built
	sudo nixos-rebuild dry-run --flake "$(CONFIG_PATH)#$(HOST)" --accept-flake-config

##@ Updates

update: ## Update flake inputs and rebuild
	sudo nix flake update "$(CONFIG_PATH)"
	sudo nixos-rebuild switch --flake "$(CONFIG_PATH)#$(HOST)" --accept-flake-config

##@ Maintenance

gc: ## Clean old generations
	sudo nix-collect-garbage -d

optimize: ## Optimize nix store
	sudo nix-store --optimize

clean: gc optimize ## Full cleanup

rollback: ## Rollback to previous generation
	sudo nixos-rebuild switch --rollback

##@ Dev

format: ## Format nix files
	find "$(CONFIG_PATH)" -name "*.nix" -type f -exec nixfmt {} \;

lint: ## Parse nix files
	find "$(CONFIG_PATH)" -name "*.nix" -type f -exec nix-instantiate --parse {} \; > /dev/null

edit: ## Open configuration in VSCode
	code "$(CONFIG_PATH)"

show-config: ## Show flake metadata
	nix flake metadata "$(CONFIG_PATH)"

diff: ## Diff current system vs build result
	sudo nixos-rebuild build --flake "$(CONFIG_PATH)#$(HOST)" --accept-flake-config && \
	nix store diff-closures /run/current-system ./result

hm-switch: ## Run home-manager directly (optional)
	home-manager switch --flake "$(CONFIG_PATH)#$(USER)"
