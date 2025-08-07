.PHONY: test-all test-format test-lint help

# Default target
all: test-all

# Run all tests
test-all:
	bats ./profile/tests/zangarmarsh-tests.sh
	bats ./profile/tests/prompt-tests.sh
	bats ./profile/tests/profile-tests.sh
	bats ./profile/tests/penv-tests.sh
	bats ./profile/tests/nvm-tests.sh
	bats ./tools/quest-log/tests/quest-log-tests.sh
	bats ./tools/dalaran/dalaran-tests.sh

# Format shell scripts
format:
	find . -name "*.sh" -exec shfmt --ln=bats -w {} \;

# Lint shell scripts
lint:
	shellcheck profile/**/*.sh tools/**/*.sh zangarmarsh.sh

# Check code quality
check: lint test-all

# Show help
help:
	@echo "Available targets:"
	@echo "  test-all  - Run all tests"
	@echo "  format    - Format shell scripts"
	@echo "  lint      - Lint shell scripts"
	@echo "  check     - Run lint and tests"
	@echo "  help      - Show this help"
