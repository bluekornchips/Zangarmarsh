TEST_FILES   := $(shell find . -name '*-tests.sh' -type f ! -path './.git/*')
SHELL_FILES  := $(shell find . -name '*.sh' -type f ! -path './.git/*' ! -name '*-tests.sh')
BATS_COMMAND := bats --timing --verbose-run

.PHONY: test shellcheck lint

#################################################
# Testing and lint
#################################################

test:
	$(BATS_COMMAND) $(TEST_FILES)

shellcheck:
	shellcheck --rcfile=.shellcheckrc $(SHELL_FILES)

lint: shellcheck
