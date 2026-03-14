test:
	clear && bats --timing --verbose-run $$(find . -name '*-tests.sh' -type f ! -path './.git/*' | sort)

lint:
	find . -name "*.sh" -type f | xargs shellcheck

.PHONY: test lint