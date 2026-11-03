BATS_JOBS   ?= $(shell nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)

TEST_FILES  := $(shell find . -name '*-tests.sh' -type f ! -path './.git/*')
SHELL_FILES := $(shell find . -name '*.sh' -type f ! -path './.git/*' \
        ! -name '*-tests.sh')
FMT_FILES   := $(shell find . -name '*.sh' -type f ! -path './.git/*')
ZSH_FILES   := $(shell find profile/zsh -name '*.zsh' -type f)

BATS_FLAGS  := --timing --verbose-run --formatter pretty
BATS         = TERM="$${TERM:-xterm}" bats $(BATS_FLAGS)

.DEFAULT_GOAL := ci

.PHONY: ci format help install lint shellcheck syntax test test-serial \
        test-smoke uninstall

#################################################
# Help
#################################################

help:
	@printf '%s\n' \
		'Targets:' \
		'  ci           syntax, lint, then test' \
		'  format       Rewrite shell scripts with shfmt defaults' \
		'  help         Show this help' \
		'  install      Install profile hooks and local Cursor plugin via profile/install.sh' \
		'  lint         Check shfmt diff and shellcheck non-test *.sh' \
		'  shellcheck   shellcheck -x on non-test *.sh' \
		'  syntax       bash -n on *.sh and zsh -n on profile/zsh/*.zsh' \
		'  test         Run all bats tests in parallel' \
		'  test-serial  Run all bats tests serially' \
		'  test-smoke   Run profile/tests/smoke-tests.sh' \
		'  uninstall    Remove profile hooks and local Cursor plugin via profile/install.sh --uninstall'

#################################################
# Lint & Format
#################################################

format:
	@command -v shfmt >/dev/null 2>&1 || { echo "shfmt is not installed" >&2; exit 1; }
	@echo "format: shfmt $$(shfmt -f . | wc -l) files"
	@shfmt -w .
	@echo "format: shfmt ok"

lint:
	@command -v shfmt >/dev/null 2>&1 || { echo "shfmt is not installed" >&2; exit 1; }
	@echo "lint: shfmt $$(shfmt -f . | wc -l) files"
	@shfmt -d .
	@echo "lint: shfmt ok"
	@$(MAKE) --no-print-directory shellcheck

syntax:
	@bash -n $(FMT_FILES)
	@zsh -n $(ZSH_FILES)

shellcheck:
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck is not installed" >&2; exit 1; }
	@echo "shellcheck: $$(echo $(SHELL_FILES) | wc -w) files"
	@shellcheck -x $(SHELL_FILES)
	@echo "shellcheck: ok"

#################################################
# Testing
#################################################

test:
	@$(BATS) --jobs $(BATS_JOBS) --no-parallelize-within-files $(TEST_FILES)

test-serial:
	@$(BATS) $(TEST_FILES)

test-smoke:
	@$(BATS) profile/tests/smoke-tests.sh

#################################################
# Install
#################################################

install:
	@profile/install.sh

uninstall:
	@profile/install.sh --uninstall

ci: syntax lint test
