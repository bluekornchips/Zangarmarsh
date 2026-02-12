test:
	clear && bats --timing --verbose-run \
	./profile/tests/zangarmarsh-tests.sh \
	./profile/tests/prompt-tests.sh \
	./profile/tests/profile-tests.sh \
	./profile/tests/penv-tests.sh \
	./profile/tests/gw-tests.sh \
	./profile/tests/nvm-tests.sh \
	./tools/quest-log/tests/quest-log-tests.sh \
	./tools/trilliax/tests/trilliax-tests.sh \
	./tools/hearthstone/tests/hearthstone-tests.sh \
	./tools/talent-calculator/tests/talent-calculator-tests.sh \
	./tools/talent-calculator/tests/brew-tools-tests.sh \
	./tools/talent-calculator/tests/other-tools-tests.sh

lint:
	find . -name "*.sh" -type f | xargs shellcheck

.PHONY: test lint