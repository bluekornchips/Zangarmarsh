TEST_FILES    := $(shell find . -name '*-tests.sh' -type f ! -path './.git/*')
BATS_COMMAND  := bats --timing --verbose-run

.PHONY: test

#################################################
# Testing
#################################################

test:
	clear && $(BATS_COMMAND) $(TEST_FILES)