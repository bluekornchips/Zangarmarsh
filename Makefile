.PHONY: test-all test-format test-lint help clean

# Default target
all: test-all

# Run all tests
test-all:
# Profile
	bats --timing --verbose-run ./profile/tests/zangarmarsh-tests.sh \
	./profile/tests/prompt-tests.sh \
	./profile/tests/profile-tests.sh \
	./profile/tests/penv-tests.sh \
	./profile/tests/nvm-tests.sh \
	./tools/quest-log/tests/quest-log-tests.sh \
	./tools/dalaran/tests/dalaran-tests.sh \
	./tools/dalaran/tests/arcane-linguist-tests.sh \
	./tools/trilliax/tests/trilliax-tests.sh

# Format shell scripts
format:
	find . -name "*.sh" -exec shfmt --ln=bats -w {} \;

# Lint shell scripts with custom ignore rules
lint:
	shellcheck --rcfile=.shellcheckrc profile/**/*.sh tools/**/*.sh zangarmarsh.sh

# Clean generated files and directories using trilliax script
clean:
	./tools/trilliax/trilliax.sh --targets python,node

# Check code quality
check: lint test-all

# Show help
help:
	@echo "Available targets:"
	@echo "  test-all  - Run all tests"
	@echo "  format    - Format shell scripts"
	@echo "  lint      - Lint shell scripts"
	@echo "  clean     - Remove .cursor dirs, claude files, and python venv files"
	@echo "  check     - Run lint and tests"
	@echo "  help      - Show this help"
