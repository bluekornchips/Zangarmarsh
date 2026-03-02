test:
	clear && bats --timing --verbose-run $$(find . -name '*-tests.sh' -type f ! -path './.git/*' | sort)

.PHONY: test