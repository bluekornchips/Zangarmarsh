TEST_FILES   := $(shell find . -name '*-tests.sh' -type f ! -path './.git/*')
SHELL_FILES  := $(shell find . -name '*.sh' -type f ! -path './.git/*' ! -name '*-tests.sh')
BATS_JOBS    ?= $(shell nproc 2>/dev/null || echo 4)
BATS_COMMAND := bats --timing --verbose-run --formatter pretty --jobs $(BATS_JOBS) --no-parallelize-within-files

.PHONY: test shellcheck install uninstall

.DEFAULT_GOAL := ci

test:
	@$(BATS_COMMAND) $(TEST_FILES)

shellcheck:
	@shellcheck --rcfile=.shellcheckrc $(SHELL_FILES)

install:
	@profile/install.sh

uninstall:
	@profile/install.sh --uninstall

ci: shellcheck test