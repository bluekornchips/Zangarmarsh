#!/usr/bin/env bats
#
# Tests for profile/install.sh: ~/.zshrc ~/.bashrc sourcing and the quest-log plugin
#

setup_file() {
	GIT_ROOT="$(git rev-parse --show-toplevel)" || return 1
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1

	SCRIPT="${ZANGARMARSH_ROOT}/profile/install.sh"
	export SCRIPT

	return 0
}

# Isolate HOME per test, then source install.sh with its guard variables
# set the same way the direct-run entry block would set them.
setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	TEST_HOME="$(mktemp -d "${base}/install-test.XXXXXX")"
	HOME="${TEST_HOME}"
	RC_FILE="${HOME}/.zshrc"
	DRY_RUN=false
	export HOME
	export RC_FILE
	export ZANGARMARSH_ROOT
	export DRY_RUN

	source "${SCRIPT}"
	source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/apply.sh"

	return 0
}

teardown() {
	rm -rf "${TEST_HOME}"
	return 0
}

########################################################
# main, CLI option parsing
########################################################
@test "main:: --help exits 0 and prints usage" {
	run "${SCRIPT}" --help
	[[ "${status}" -eq 0 ]]
	grep -q "Usage:" <<<"${output}"
	grep -q -- "--zsh" <<<"${output}"
	grep -q -- "--bash" <<<"${output}"
}

@test "main:: -h exits 0 and prints usage" {
	run "${SCRIPT}" -h
	[[ "${status}" -eq 0 ]]
	grep -q "Usage:" <<<"${output}"
}

@test "main:: unknown option returns 1" {
	run "${SCRIPT}" --bogus
	[[ "${status}" -eq 1 ]]
	grep -q "unknown option" <<<"${output}"
}

@test "main:: ignores an inherited ZANGARMARSH_ROOT from another checkout" {
	local other_root="${TEST_HOME}/other-root"
	mkdir -p "${other_root}"
	printf '# decoy\n' >"${other_root}/zangarmarsh.sh"

	run env HOME="${HOME}" ZANGARMARSH_ROOT="${other_root}" \
		"${SCRIPT}" --dry-run --zsh
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -Fq "${GIT_ROOT}/zangarmarsh.sh"
	echo "${output}" | grep -Fvq "${other_root}/zangarmarsh.sh"
}

########################################################
# validate_install_env, source helpers
########################################################
@test "validate_install_env:: fails when HOME is empty" {
	HOME="" run validate_install_env
	[[ "${status}" -eq 1 ]]
	grep -q "HOME is required" <<<"${output}"
}

@test "_canonical_source_command:: emits the source line without a trailing newline" {
	local expected
	expected="$(printf 'source %q' "${ZANGARMARSH_ROOT}/zangarmarsh.sh")"

	run _canonical_source_command
	[[ "${status}" -eq 0 ]]
	[[ "${output}" == "${expected}" ]]
	[[ "$(printf '%s\n' "$(_canonical_source_command)" | wc -c)" -eq $((${#output} + 1)) ]]
}

@test "_canonical_source_command:: quotes a root that contains shell metacharacters" {
	local marker="${TEST_HOME}/pwned"
	local weird_root="${TEST_HOME}/a\"b; touch ${marker}; echo \""
	local line
	line="$(ZANGARMARSH_ROOT="${weird_root}" _canonical_source_command)"

	run bash -c "${line}"
	[[ "${status}" -ne 0 ]]
	[[ ! -e "${marker}" ]]
}

########################################################
# has_source_line
########################################################
@test "has_source_line:: returns 1 when RC_FILE is missing" {
	run has_source_line "${RC_FILE}"
	[[ "${status}" -eq 1 ]]
}

@test "has_source_line:: returns 0 once the line is present" {
	printf '%s\n' "$(_canonical_source_command)" >"${RC_FILE}"

	run has_source_line "${RC_FILE}"
	[[ "${status}" -eq 0 ]]
}

@test "has_source_line:: matches a double-quoted absolute path" {
	printf 'source "%s/zangarmarsh.sh"\n' "${ZANGARMARSH_ROOT}" >"${RC_FILE}"

	run has_source_line "${RC_FILE}"
	[[ "${status}" -eq 0 ]]
}

@test "has_source_line:: matches a \$HOME form" {
	local zm_root="${HOME}/zm"
	mkdir -p "${zm_root}"
	touch "${zm_root}/zangarmarsh.sh"
	local home_line="source \"\$HOME/zm/zangarmarsh.sh\""
	printf '%s\n' "${home_line}" >"${RC_FILE}"

	ZANGARMARSH_ROOT="${zm_root}" run has_source_line "${RC_FILE}"
	[[ "${status}" -eq 0 ]]
}

@test "has_source_line:: ignores a stale source line from another root" {
	printf 'source "/other/root/zangarmarsh.sh"\n' >"${RC_FILE}"

	run has_source_line "${RC_FILE}"
	[[ "${status}" -eq 1 ]]
}

########################################################
# install_zangarmarsh
########################################################
@test "install_zangarmarsh:: creates RC_FILE and appends the source line" {
	run install_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]

	[[ -f "${RC_FILE}" ]]
	grep -Fqx "$(_canonical_source_command)" "${RC_FILE}"
	[[ "$(tail -c 1 "${RC_FILE}" | wc -c)" -eq 1 ]]
	[[ -z "$(tail -c 1 "${RC_FILE}")" ]]
}

@test "install_zangarmarsh:: preserves existing content and adds a newline first" {
	printf 'alias ll="ls -l"' >"${RC_FILE}"

	run install_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]

	local expected_file="${HOME}/expected.zshrc"
	printf 'alias ll="ls -l"\n%s\n' "$(_canonical_source_command)" >"${expected_file}"
	cmp -s "${expected_file}" "${RC_FILE}"
	[[ "$(wc -l <"${RC_FILE}")" -eq 2 ]]
}

@test "install_zangarmarsh:: is idempotent on a second run" {
	if ! install_zangarmarsh "${RC_FILE}" >/dev/null; then
		return 1
	fi

	run install_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]
	grep -q "Already installed" <<<"${output}"
	[[ "$(grep -Fcx "$(_canonical_source_command)" "${RC_FILE}")" -eq 1 ]]
}

@test "install_zangarmarsh:: collapses duplicate and alternate source forms" {
	local zm_root="${HOME}/zm"
	mkdir -p "${zm_root}"
	touch "${zm_root}/zangarmarsh.sh"
	local home_line="source \"\$HOME/zm/zangarmarsh.sh\""
	{
		printf 'alias ll="ls -l"\n'
		printf 'source "%s/zangarmarsh.sh"\n' "${zm_root}"
		printf '%s\n' "${home_line}"
		printf 'source "/other/root/zangarmarsh.sh"\n'
	} >"${RC_FILE}"

	ZANGARMARSH_ROOT="${zm_root}" run install_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]
	[[ "$(grep -Fc "zangarmarsh.sh" "${RC_FILE}")" -eq 2 ]]
	[[ "$(grep -Fcx "$(ZANGARMARSH_ROOT="${zm_root}" _canonical_source_command)" "${RC_FILE}")" -eq 1 ]]
	grep -Fqx 'source "/other/root/zangarmarsh.sh"' "${RC_FILE}"
	grep -Fqx 'alias ll="ls -l"' "${RC_FILE}"
}

@test "install_zangarmarsh:: removes the official eager NVM block from bashrc" {
	local rc="${HOME}/.bashrc"
	cat >"${rc}" <<EOF
alias ll="ls -l"
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \\. "\$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "\$NVM_DIR/bash_completion" ] && \\. "\$NVM_DIR/bash_completion"  # This loads nvm bash_completion
EOF

	run install_zangarmarsh "${rc}"
	[[ "${status}" -eq 0 ]]
	grep -Fqx 'alias ll="ls -l"' "${rc}"
	grep -Fqx "$(_canonical_source_command)" "${rc}"
	matched=0
	grep -Fq 'NVM_DIR' "${rc}" && matched=1
	[[ "${matched}" -eq 0 ]]
	matched=0
	grep -Fq 'nvm.sh' "${rc}" && matched=1
	[[ "${matched}" -eq 0 ]]
}

@test "install_zangarmarsh:: dry-run reports the change without writing" {
	DRY_RUN=true

	run install_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]
	grep -q "Would install into" <<<"${output}"
	[[ ! -e "${RC_FILE}" ]]
}

@test "install_zangarmarsh:: writes through a symlinked RC_FILE" {
	local real_rc="${HOME}/real-zshrc"
	printf 'alias ll="ls -l"\n' >"${real_rc}"
	ln -s "${real_rc}" "${RC_FILE}"

	run install_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]
	[[ -L "${RC_FILE}" ]]
	grep -Fqx 'alias ll="ls -l"' "${real_rc}"
	grep -Fqx "$(_canonical_source_command)" "${real_rc}"
}

@test "install_zangarmarsh:: fails when RC_FILE is not writable" {
	mkdir -p "${RC_FILE}"

	run install_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 1 ]]
	grep -q "failed to append" <<<"${output}"
}

########################################################
# uninstall_zangarmarsh
########################################################
@test "uninstall_zangarmarsh:: reports not installed when RC_FILE is missing" {
	run uninstall_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]
	grep -q "Not installed" <<<"${output}"
}

@test "uninstall_zangarmarsh:: removes only the Zangarmarsh line" {
	printf 'alias ll="ls -l"\n%s\n' "$(_canonical_source_command)" >"${RC_FILE}"

	run uninstall_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]

	grep -Fqx 'alias ll="ls -l"' "${RC_FILE}"
	matched=0
	grep -Fqx "$(_canonical_source_command)" "${RC_FILE}" && matched=1
	[[ "${matched}" -eq 0 ]]
}

@test "uninstall_zangarmarsh:: removes every matching source form for this root" {
	{
		printf 'alias ll="ls -l"\n'
		printf 'source "%s/zangarmarsh.sh"\n' "${ZANGARMARSH_ROOT}"
		printf '%s\n' "$(_canonical_source_command)"
		printf 'source "/other/root/zangarmarsh.sh"\n'
	} >"${RC_FILE}"

	run uninstall_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]

	grep -Fqx 'alias ll="ls -l"' "${RC_FILE}"
	grep -Fqx 'source "/other/root/zangarmarsh.sh"' "${RC_FILE}"
	matched=0
	grep -Fq "${ZANGARMARSH_ROOT}/zangarmarsh.sh" "${RC_FILE}" && matched=1
	[[ "${matched}" -eq 0 ]]
}

@test "uninstall_zangarmarsh:: preserves a symlinked RC_FILE" {
	local real_rc="${HOME}/real-zshrc"
	printf 'alias ll="ls -l"\n%s\n' "$(_canonical_source_command)" >"${real_rc}"
	ln -s "${real_rc}" "${RC_FILE}"

	run uninstall_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]
	[[ -L "${RC_FILE}" ]]
	grep -Fqx 'alias ll="ls -l"' "${real_rc}"
	matched=0
	grep -Fq "zangarmarsh.sh" "${real_rc}" && matched=1
	[[ "${matched}" -eq 0 ]]
}

@test "uninstall_zangarmarsh:: dry-run reports the change without writing" {
	printf '%s\n' "$(_canonical_source_command)" >"${RC_FILE}"
	DRY_RUN=true

	run uninstall_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]
	grep -q "Would remove" <<<"${output}"
	grep -Fqx "$(_canonical_source_command)" "${RC_FILE}"
}

@test "uninstall_zangarmarsh:: leaves a stale source line from another root" {
	printf 'source "/other/root/zangarmarsh.sh"\n' >"${RC_FILE}"

	run uninstall_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]
	grep -q "Not installed" <<<"${output}"
	grep -Fqx 'source "/other/root/zangarmarsh.sh"' "${RC_FILE}"
}

########################################################
# install_cursor_plugin, uninstall_quest_plugin
########################################################
@test "quest_log_plugin_dir:: resolves under HOME" {
	run quest_log_plugin_dir
	[[ "${status}" -eq 0 ]]
	[[ "${output}" == "${HOME}/.cursor/plugins/local/quest-log" ]]
}

@test "install_cursor_plugin:: dry-run makes no changes" {
	DRY_RUN=true

	run install_cursor_plugin
	[[ "${status}" -eq 0 ]]
	grep -q "would replace" <<<"${output}"
	grep -q "would sync" <<<"${output}"
	[[ ! -e "$(quest_log_plugin_dir)" ]]
	[[ ! -e "$(quest_log_rules_dir)" ]]
}

@test "install_cursor_plugin:: installs the plugin manifest and user rules under HOME" {
	run install_cursor_plugin
	[[ "${status}" -eq 0 ]]
	[[ -f "$(quest_log_plugin_dir)/.cursor-plugin/plugin.json" ]]
	[[ -f "$(quest_log_rules_dir)/always.mdc" ]]
	[[ -f "$(quest_log_rules_dir)/.quest-log.manifest" ]]
}

@test "uninstall_quest_plugin:: reports not installed when the directory is absent" {
	run uninstall_quest_plugin
	[[ "${status}" -eq 0 ]]
	grep -q "not installed" <<<"${output}"
}

@test "uninstall_quest_plugin:: removes an installed plugin directory" {
	if ! install_cursor_plugin >/dev/null; then
		return 1
	fi

	run uninstall_quest_plugin
	[[ "${status}" -eq 0 ]]
	[[ ! -e "$(quest_log_plugin_dir)" ]]
}

@test "uninstall_quest_plugin:: dry-run makes no changes" {
	if ! install_cursor_plugin >/dev/null; then
		return 1
	fi
	DRY_RUN=true

	run uninstall_quest_plugin
	[[ "${status}" -eq 0 ]]
	grep -q "would remove" <<<"${output}"
	[[ -e "$(quest_log_plugin_dir)" ]]
}

@test "uninstall_quest_rules:: removes managed rules installed by install_cursor_plugin" {
	if ! install_cursor_plugin >/dev/null; then
		return 1
	fi

	run uninstall_quest_rules
	[[ "${status}" -eq 0 ]]
	[[ ! -f "$(quest_log_rules_dir)/always.mdc" ]]
	[[ ! -f "$(quest_log_rules_dir)/.quest-log.manifest" ]]
}

########################################################
# main, end to end via the CLI
########################################################
@test "integration:: install then uninstall via the CLI leaves no trace" {
	run "${SCRIPT}"
	[[ "${status}" -eq 0 ]]
	[[ -f "${TEST_HOME}/.zshrc" ]]
	[[ -f "${TEST_HOME}/.bashrc" ]]
	[[ -f "${TEST_HOME}/.cursor/plugins/local/quest-log/.cursor-plugin/plugin.json" ]]
	[[ -f "${TEST_HOME}/.cursor/rules/always.mdc" ]]
	[[ -f "${TEST_HOME}/.cursor/rules/.quest-log.manifest" ]]
	local expected
	expected="$(printf 'source %q' "${ZANGARMARSH_ROOT}/zangarmarsh.sh")"
	grep -Fqx "${expected}" "${TEST_HOME}/.zshrc"
	grep -Fqx "${expected}" "${TEST_HOME}/.bashrc"
	[[ ! -e "${TEST_HOME}/.aliases" ]]

	run "${SCRIPT}" --uninstall
	[[ "${status}" -eq 0 ]]
	matched=0
	grep -Fq "zangarmarsh.sh" "${TEST_HOME}/.zshrc" && matched=1
	[[ "${matched}" -eq 0 ]]
	matched=0
	grep -Fq "zangarmarsh.sh" "${TEST_HOME}/.bashrc" && matched=1
	[[ "${matched}" -eq 0 ]]
	[[ ! -e "${TEST_HOME}/.cursor/plugins/local/quest-log" ]]
	[[ ! -f "${TEST_HOME}/.cursor/rules/always.mdc" ]]
	[[ ! -f "${TEST_HOME}/.cursor/rules/.quest-log.manifest" ]]
}

@test "integration:: --zsh installs only into ~/.zshrc" {
	run "${SCRIPT}" --zsh
	[[ "${status}" -eq 0 ]]
	local expected
	expected="$(printf 'source %q' "${ZANGARMARSH_ROOT}/zangarmarsh.sh")"
	grep -Fqx "${expected}" "${TEST_HOME}/.zshrc"
	[[ ! -e "${TEST_HOME}/.bashrc" ]]
}

@test "integration:: --bash installs only into ~/.bashrc" {
	run "${SCRIPT}" --bash
	[[ "${status}" -eq 0 ]]
	local expected
	expected="$(printf 'source %q' "${ZANGARMARSH_ROOT}/zangarmarsh.sh")"
	grep -Fqx "${expected}" "${TEST_HOME}/.bashrc"
	[[ ! -e "${TEST_HOME}/.zshrc" ]]
}

@test "integration:: --dry-run makes no changes" {
	run "${SCRIPT}" --dry-run
	[[ "${status}" -eq 0 ]]
	[[ ! -e "${TEST_HOME}/.zshrc" ]]
	[[ ! -e "${TEST_HOME}/.bashrc" ]]
	[[ ! -e "${TEST_HOME}/.cursor/plugins/local/quest-log" ]]
	[[ ! -e "${TEST_HOME}/.cursor/rules" ]]
}

@test "integration:: --dry-run --uninstall makes no changes" {
	if ! "${SCRIPT}" >/dev/null; then
		return 1
	fi

	run "${SCRIPT}" --dry-run --uninstall
	[[ "${status}" -eq 0 ]]
	grep -Fq "zangarmarsh.sh" "${TEST_HOME}/.zshrc"
	grep -Fq "zangarmarsh.sh" "${TEST_HOME}/.bashrc"
	[[ -e "${TEST_HOME}/.cursor/plugins/local/quest-log" ]]
	[[ -f "${TEST_HOME}/.cursor/rules/always.mdc" ]]
}

@test "integration:: rolls back the plugin and rules when rc install fails" {
	mkdir -p "${HOME}/.zshrc"

	run main --zsh
	[[ "${status}" -eq 1 ]]
	[[ ! -e "$(quest_log_plugin_dir)" ]]
	[[ ! -e "$(quest_log_rules_dir)/always.mdc" ]]
}

@test "main:: returns nonzero when plugin install fails" {
	install_quest_plugin() {
		printf 'install_quest_plugin:: forced failure\n' >&2

		return 1
	}

	run main
	[[ "${status}" -eq 1 ]]
	grep -q "forced failure" <<<"${output}"
	[[ ! -e "${HOME}/.zshrc" ]]
	[[ ! -e "${HOME}/.bashrc" ]]
}

@test "integration:: returns nonzero when uninstall_quest_plugin fails" {
	if ! "${SCRIPT}" >/dev/null; then
		return 1
	fi

	uninstall_quest_plugin() {
		printf 'uninstall_quest_plugin:: forced failure\n' >&2

		return 1
	}

	run main --uninstall
	[[ "${status}" -eq 1 ]]
	grep -q "forced failure" <<<"${output}"
	matched=0
	grep -Fq "zangarmarsh.sh" "${HOME}/.zshrc" && matched=1
	[[ "${matched}" -eq 0 ]]
	matched=0
	grep -Fq "zangarmarsh.sh" "${HOME}/.bashrc" && matched=1
	[[ "${matched}" -eq 0 ]]
}
