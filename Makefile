# Makefile for NixOS Configuration Management

.PHONY: help switch build test update clean gc check format install backup

# Default target
.DEFAULT_GOAL := help

# Configuration path
CONFIG_PATH := /etc/nixos

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

help: ## Show this help message
	@echo "$(BLUE)NixOS Configuration Management$(NC)"
	@echo ""
	@echo "$(GREEN)Available commands:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf "\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(BLUE)%-15s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""

##@ Building & Testing

switch: ## Build and activate new configuration
	@echo "$(BLUE)Building and activating configuration...$(NC)"
	sudo nixos-rebuild switch --flake $(CONFIG_PATH)#nixos

build: ## Build without activating
	@echo "$(BLUE)Building configuration...$(NC)"
	sudo nixos-rebuild build --flake $(CONFIG_PATH)#nixos

test: ## Build and test without activating
	@echo "$(BLUE)Testing configuration...$(NC)"
	sudo nixos-rebuild test --flake $(CONFIG_PATH)#nixos

boot: ## Build and set as boot default (activate on next boot)
	@echo "$(BLUE)Setting configuration for next boot...$(NC)"
	sudo nixos-rebuild boot --flake $(CONFIG_PATH)#nixos

check: ## Check flake for errors
	@echo "$(BLUE)Checking flake configuration...$(NC)"
	nix flake check $(CONFIG_PATH)

dry-run: ## Show what would be built
	@echo "$(BLUE)Performing dry run...$(NC)"
	sudo nixos-rebuild dry-run --flake $(CONFIG_PATH)#nixos

##@ Updates

update: ## Update flake inputs and rebuild
	@echo "$(BLUE)Updating flake inputs...$(NC)"
	sudo nix flake update $(CONFIG_PATH)
	@echo "$(GREEN)Rebuilding with updates...$(NC)"
	sudo nixos-rebuild switch --flake $(CONFIG_PATH)#nixos

update-input: ## Update specific flake input (usage: make update-input INPUT=nixpkgs)
	@if [ -z "$(INPUT)" ]; then \
		echo "$(YELLOW)Usage: make update-input INPUT=<input-name>$(NC)"; \
		echo "Available inputs: nixpkgs, home-manager"; \
		exit 1; \
	fi
	@echo "$(BLUE)Updating input: $(INPUT)$(NC)"
	sudo nix flake lock --update-input $(INPUT) $(CONFIG_PATH)

show-updates: ## Show available updates
	@echo "$(BLUE)Checking for available updates...$(NC)"
	nix flake update --dry-run $(CONFIG_PATH) 2>&1 | grep -E "updated|Updated" || echo "No updates available"

##@ Maintenance

gc: ## Clean old generations
	@echo "$(BLUE)Garbage collecting...$(NC)"
	sudo nix-collect-garbage -d

gc-old: ## Remove generations older than 30 days
	@echo "$(BLUE)Removing old generations...$(NC)"
	sudo nix-collect-garbage --delete-older-than 30d

optimize: ## Optimize nix store
	@echo "$(BLUE)Optimizing nix store...$(NC)"
	sudo nix-store --optimize

clean: gc optimize ## Full cleanup (gc + optimize)

##@ Backup & Recovery

backup: ## Backup current configuration
	@echo "$(BLUE)Backing up configuration...$(NC)"
	@BACKUP_DIR="$(CONFIG_PATH).backup.$$(date +%Y%m%d_%H%M%S)"; \
	sudo cp -r $(CONFIG_PATH) "$$BACKUP_DIR"; \
	echo "$(GREEN)Backed up to: $$BACKUP_DIR$(NC)"

list-backups: ## List available backups
	@echo "$(BLUE)Available backups:$(NC)"
	@ls -dt /etc/nixos.backup.* 2>/dev/null || echo "No backups found"

list-generations: ## List system generations
	@echo "$(BLUE)System generations:$(NC)"
	sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

rollback: ## Rollback to previous generation
	@echo "$(BLUE)Rolling back to previous generation...$(NC)"
	sudo nixos-rebuild switch --rollback

##@ Development

format: ## Format nix files
	@echo "$(BLUE)Formatting nix files...$(NC)"
	find $(CONFIG_PATH) -name "*.nix" -type f -exec nixfmt {} \;

lint: ## Lint nix files
	@echo "$(BLUE)Linting nix files...$(NC)"
	find $(CONFIG_PATH) -name "*.nix" -type f -exec nix-instantiate --parse {} \; > /dev/null

edit: ## Open configuration in VSCode
	@code $(CONFIG_PATH)

show-config: ## Show current system configuration
	@echo "$(BLUE)Current configuration path:$(NC) $(CONFIG_PATH)"
	@echo ""
	@echo "$(BLUE)Flake inputs:$(NC)"
	@nix flake metadata $(CONFIG_PATH)

diff: ## Show diff between current and new configuration
	@echo "$(BLUE)Configuration diff:$(NC)"
	@sudo nixos-rebuild build --flake $(CONFIG_PATH)#nixos && \
	nix store diff-closures /run/current-system ./result

##@ Services

start-db: ## Start all database services
	@echo "$(BLUE)Starting database services...$(NC)"
	sudo systemctl start postgresql mysql mongodb redis

stop-db: ## Stop all database services
	@echo "$(BLUE)Stopping database services...$(NC)"
	sudo systemctl stop postgresql mysql mongodb redis

restart-db: ## Restart all database services
	@echo "$(BLUE)Restarting database services...$(NC)"
	sudo systemctl restart postgresql mysql mongodb redis

status-db: ## Check status of database services
	@echo "$(BLUE)Database service status:$(NC)"
	@echo ""
	@echo "$(GREEN)PostgreSQL:$(NC)"
	@sudo systemctl status postgresql --no-pager || true
	@echo ""
	@echo "$(GREEN)MySQL:$(NC)"
	@sudo systemctl status mysql --no-pager || true
	@echo ""
	@echo "$(GREEN)MongoDB:$(NC)"
	@sudo systemctl status mongodb --no-pager || true
	@echo ""
	@echo "$(GREEN)Redis:$(NC)"
	@sudo systemctl status redis --no-pager || true

##@ Information

info: ## Show system information
	@echo "$(BLUE)System Information$(NC)"
	@echo ""
	@fastfetch || neofetch || echo "Install fastfetch or neofetch for system info"

tree: ## Show configuration file tree
	@echo "$(BLUE)Configuration structure:$(NC)"
	@tree -L 2 -I 'hardware-configuration.nix' $(CONFIG_PATH) || ls -R $(CONFIG_PATH)

search: ## Search for a package (usage: make search PKG=<name>)
	@if [ -z "$(PKG)" ]; then \
		echo "$(YELLOW)Usage: make search PKG=<package-name>$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Searching for: $(PKG)$(NC)"
	nix search nixpkgs $(PKG)

install: ## Install this configuration (run install.sh)
	@echo "$(BLUE)Running installation script...$(NC)"
	@sudo bash $(CONFIG_PATH)/install.sh
