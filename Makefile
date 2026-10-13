# ==============================================================================
# Makefile — VPS Infrastructure Operator and Test Automation Interface
# ==============================================================================

SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

# Colors for terminal output
BOLD   := \033[1m
RESET  := \033[0m
GREEN  := \033[0;32m
YELLOW := \033[0;33m
BLUE   := \033[0;34m
CYAN   := \033[0;36m

ARGS ?=

## help: Display this help message with descriptions of all targets
.PHONY: help
help:
	@printf "\n$(BOLD)$(CYAN)VPS Infrastructure Management Commands:$(RESET)\n\n"
	@printf "$(BOLD)Quality & Verification Targets:$(RESET)\n"
	@printf "  $(GREEN)make check$(RESET)           Run shell syntax checks (bash -n) and zero-secrets audit\n"
	@printf "  $(GREEN)make lint$(RESET)            Run ShellCheck static linter if installed\n"
	@printf "  $(GREEN)make test$(RESET)            Run complete automated TDD test suite\n"
	@printf "  $(GREEN)make clean$(RESET)           Remove temporary test outputs and staging caches\n"
	@printf "\n$(BOLD)Host Provisioning & Operational Targets:$(RESET)\n"
	@printf "  $(YELLOW)make preflight$(RESET)       Run read-only preflight diagnostic checks (scripts/preflight.sh)\n"
	@printf "  $(YELLOW)make bootstrap$(RESET)       Run base package and APT bootstrapping (scripts/bootstrap.sh)\n"
	@printf "  $(YELLOW)make harden$(RESET)          Run firewall and SSH hardening (scripts/harden-server.sh)\n"
	@printf "  $(YELLOW)make install-docker$(RESET)  Install Docker Engine CE via official repo (scripts/install-docker.sh)\n"
	@printf "  $(YELLOW)make install-coolify$(RESET) Install Coolify v4 PaaS safely (scripts/install-coolify.sh)\n"
	@printf "  $(YELLOW)make backup-setup$(RESET)    Configure backup paths and enable systemd timer (scripts/setup-backups.sh)\n"
	@printf "  $(YELLOW)make backup-now$(RESET)      Execute immediate two-tier encrypted backup (scripts/backup-now.sh)\n"
	@printf "  $(YELLOW)make backup-verify$(RESET)   Non-destructive remote backup inspection (scripts/verify-backups.sh)\n"
	@printf "  $(YELLOW)make backup-restore$(RESET)  Interactive disaster-recovery restore wizard (scripts/restore-backup.sh)\n"
	@printf "  $(YELLOW)make health$(RESET)          Run host resource and container health checks (scripts/health-check.sh)\n"
	@printf "\n$(BLUE)Note: You can pass arguments using ARGS=\"...\". Example: make harden ARGS=\"--dry-run\"$(RESET)\n\n"

## check: Syntax check all bash scripts and scan for accidentally committed secrets
.PHONY: check
check:
	@bash tests/test_scripts_syntax.sh
	@bash tests/test_secrets_scan.sh

## lint: Run ShellCheck on scripts if available
.PHONY: lint
lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		printf "$(GREEN)==> Running ShellCheck on all shell scripts...$(RESET)\n"; \
		find scripts tests -name "*.sh" -type f -exec shellcheck {} +; \
		printf "$(GREEN)✓ ShellCheck passed cleanly.$(RESET)\n"; \
	else \
		printf "$(YELLOW)[WARN] shellcheck is not installed. Skipping static analysis (bash -n verified in check).$(RESET)\n"; \
	fi

## test: Run the full automated TDD test suite across all tickets
.PHONY: test
test: check
	@printf "$(CYAN)$(BOLD)===> Executing Complete TDD Test Suite <===${RESET}\n"
	@for test_script in tests/test_*.sh; do \
		if [[ "$$test_script" != "tests/test_runner.sh" && "$$test_script" != "tests/test_scripts_syntax.sh" && "$$test_script" != "tests/test_secrets_scan.sh" ]]; then \
			bash "$$test_script"; \
		fi \
	done
	@printf "$(GREEN)$(BOLD)✓ ALL TEST SUITES PASSED GREEN$(RESET)\n"

## clean: Clean up temporary files
.PHONY: clean
clean:
	@rm -rf /tmp/vps_test_* /tmp/vps_backup_test_* .tmp
	@printf "$(GREEN)✓ Cleaned temporary test artifacts.$(RESET)\n"

# Operational script proxies
.PHONY: preflight
preflight:
	@bash scripts/preflight.sh $(ARGS)

.PHONY: bootstrap
bootstrap:
	@bash scripts/bootstrap.sh $(ARGS)

.PHONY: harden
harden:
	@bash scripts/harden-server.sh $(ARGS)

.PHONY: install-docker
install-docker:
	@bash scripts/install-docker.sh $(ARGS)

.PHONY: install-coolify
install-coolify:
	@bash scripts/install-coolify.sh $(ARGS)

.PHONY: backup-setup
backup-setup:
	@bash scripts/setup-backups.sh $(ARGS)

.PHONY: backup-now
backup-now:
	@bash scripts/backup-now.sh $(ARGS)

.PHONY: backup-verify
backup-verify:
	@bash scripts/verify-backups.sh $(ARGS)

.PHONY: backup-restore
backup-restore:
	@bash scripts/restore-backup.sh $(ARGS)

.PHONY: health
health:
	@bash scripts/health-check.sh $(ARGS)
