all: test-all

test-all:
	bats --timing --verbose-run ./profile/tests/zangarmarsh-tests.sh \
	./profile/tests/prompt-tests.sh \
	./profile/tests/profile-tests.sh \
	./profile/tests/penv-tests.sh \
	./profile/tests/nvm-tests.sh \
	./tools/quest-log/tests/quest-log-tests.sh \
	./tools/dalaran/tests/dalaran-tests.sh \
	./tools/dalaran/tests/arcane-linguist-tests.sh \
	./tools/trilliax/tests/trilliax-tests.sh \
	./tools/hearthstone/tests/hearthstone-tests.sh

format:
	find . -name "*.sh" -exec shfmt --ln=bats -w {} \;