TEST_FILES   := $(shell find . -name '*-tests.sh' -type f ! -path './.git/*')
SHELL_FILES  := $(shell find . -name '*.sh' -type f ! -path './.git/*' ! -name '*-tests.sh')
BATS_JOBS    ?= $(shell nproc 2>/dev/null || echo 4)
BATS_COMMAND := bats --timing --verbose-run --formatter pretty --jobs $(BATS_JOBS) --no-parallelize-within-files

.PHONY: test shellcheck install uninstall syntax

.DEFAULT_GOAL := ci

test:
	@$(BATS_COMMAND) $(TEST_FILES)

syntax:
	@bash -n $(SHELL_FILES)
	@zsh -n profile/zsh/*.zsh

shellcheck:
	@shellcheck --rcfile=.shellcheckrc $(SHELL_FILES)

install:
	@profile/install.sh

uninstall:
	@profile/install.sh --uninstall

ci: syntax shellcheck test
