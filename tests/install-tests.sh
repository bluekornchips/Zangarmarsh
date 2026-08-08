#!/usr/bin/env bats
#
# Tests for profile/install.sh: ~/.zshrc ~/.bashrc sourcing and the quest-log plugin
#

setup_file() {
	if ! GIT_ROOT="$(git rev-parse --show-toplevel)"; then
		echo "setup_file:: Failed to get git root" >&2
		return 1
	fi
	source "${GIT_ROOT}/tests/fixtures.sh"

	SCRIPT="${ZANGARMARSH_ROOT}/profile/install.sh"
	[[ -f "${SCRIPT}" ]] || {
		echo "Script not found: ${SCRIPT}" >&2
		return 1
	}
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
	source "${ZANGARMARSH_ROOT}/tools/quest-log/lib/plugin.sh"

	return 0
}

teardown() {
	rm -rf "${TEST_HOME}"

	return 0
}

teardown_file() {
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

########################################################
# validate_install_env, source helpers
########################################################
@test "validate_install_env:: fails when HOME is empty" {
	HOME=""

	run validate_install_env
	[[ "${status}" -eq 1 ]]
	grep -q "HOME is required" <<<"${output}"
}

@test "write_source_line:: emits a trailing newline" {
	run write_source_line
	[[ "${status}" -eq 0 ]]
	[[ "${output}" == "source \"${ZANGARMARSH_ROOT}/zangarmarsh.sh\"" ]]
	[[ "$(write_source_line | wc -c)" -eq $((${#output} + 1)) ]]
}

########################################################
# has_source_line
########################################################
@test "has_source_line:: returns 1 when RC_FILE is missing" {
	run has_source_line
	[[ "${status}" -eq 1 ]]
}

@test "has_source_line:: returns 0 once the line is present" {
	write_source_line >"${RC_FILE}"

	run has_source_line
	[[ "${status}" -eq 0 ]]
}

@test "has_source_line:: ignores a stale source line from another root" {
	printf 'source "/other/root/zangarmarsh.sh"\n' >"${RC_FILE}"

	run has_source_line
	[[ "${status}" -eq 1 ]]
}

########################################################
# install_zangarmarsh
########################################################
@test "install_zangarmarsh:: creates RC_FILE and appends the source line" {
	run install_zangarmarsh
	[[ "${status}" -eq 0 ]]

	[[ -f "${RC_FILE}" ]]
	grep -Fqx "$(source_line_text)" "${RC_FILE}"
	[[ "$(tail -c 1 "${RC_FILE}" | wc -c)" -eq 1 ]]
	[[ -z "$(tail -c 1 "${RC_FILE}")" ]]
}

@test "install_zangarmarsh:: preserves existing content and adds a newline first" {
	printf 'alias ll="ls -l"' >"${RC_FILE}"

	run install_zangarmarsh
	[[ "${status}" -eq 0 ]]

	local expected_file="${HOME}/expected.zshrc"
	printf 'alias ll="ls -l"\nsource "%s/zangarmarsh.sh"\n' "${ZANGARMARSH_ROOT}" >"${expected_file}"
	cmp -s "${expected_file}" "${RC_FILE}"
	[[ "$(wc -l <"${RC_FILE}")" -eq 2 ]]
}

@test "install_zangarmarsh:: is idempotent on a second run" {
	install_zangarmarsh >/dev/null

	run install_zangarmarsh
	[[ "${status}" -eq 0 ]]
	grep -q "Already installed" <<<"${output}"
	[[ "$(grep -Fcx "$(source_line_text)" "${RC_FILE}")" -eq 1 ]]
}

@test "install_zangarmarsh:: dry-run reports the change without writing" {
	DRY_RUN=true

	run install_zangarmarsh
	[[ "${status}" -eq 0 ]]
	grep -q "Would append" <<<"${output}"
	[[ ! -e "${RC_FILE}" ]]
}

@test "install_zangarmarsh:: writes through a symlinked RC_FILE" {
	local real_rc="${HOME}/real-zshrc"
	printf 'alias ll="ls -l"\n' >"${real_rc}"
	ln -s "${real_rc}" "${RC_FILE}"

	run install_zangarmarsh
	[[ "${status}" -eq 0 ]]
	[[ -L "${RC_FILE}" ]]
	grep -Fqx 'alias ll="ls -l"' "${real_rc}"
	grep -Fqx "$(source_line_text)" "${real_rc}"
}

@test "install_zangarmarsh:: fails when RC_FILE is not writable" {
	mkdir -p "${RC_FILE}"

	run install_zangarmarsh
	[[ "${status}" -eq 1 ]]
	grep -q "failed to append" <<<"${output}"
}

########################################################
# uninstall_zangarmarsh
########################################################
@test "uninstall_zangarmarsh:: reports not installed when RC_FILE is missing" {
	run uninstall_zangarmarsh
	[[ "${status}" -eq 0 ]]
	grep -q "Not installed" <<<"${output}"
}

@test "uninstall_zangarmarsh:: removes only the Zangarmarsh line" {
	printf 'alias ll="ls -l"\n%s' "$(write_source_line)" >"${RC_FILE}"

	run uninstall_zangarmarsh
	[[ "${status}" -eq 0 ]]

	grep -Fqx 'alias ll="ls -l"' "${RC_FILE}"
	! grep -Fqx "$(source_line_text)" "${RC_FILE}"
}

@test "uninstall_zangarmarsh:: preserves a symlinked RC_FILE" {
	local real_rc="${HOME}/real-zshrc"
	printf 'alias ll="ls -l"\n%s' "$(write_source_line)" >"${real_rc}"
	ln -s "${real_rc}" "${RC_FILE}"

	run uninstall_zangarmarsh
	[[ "${status}" -eq 0 ]]
	[[ -L "${RC_FILE}" ]]
	grep -Fqx 'alias ll="ls -l"' "${real_rc}"
	! grep -Fq "zangarmarsh.sh" "${real_rc}"
}

@test "uninstall_zangarmarsh:: dry-run reports the change without writing" {
	write_source_line >"${RC_FILE}"
	DRY_RUN=true

	run uninstall_zangarmarsh
	[[ "${status}" -eq 0 ]]
	grep -q "Would remove" <<<"${output}"
	grep -Fqx "$(source_line_text)" "${RC_FILE}"
}

@test "uninstall_zangarmarsh:: leaves a stale source line from another root" {
	printf 'source "/other/root/zangarmarsh.sh"\n' >"${RC_FILE}"

	run uninstall_zangarmarsh
	[[ "${status}" -eq 0 ]]
	grep -q "Not installed" <<<"${output}"
	grep -Fqx 'source "/other/root/zangarmarsh.sh"' "${RC_FILE}"
}

########################################################
# install_cursor_plugin, uninstall_cursor_plugin
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
	[[ ! -e "$(quest_log_plugin_dir)" ]]
}

@test "install_cursor_plugin:: installs the plugin manifest under HOME" {
	run install_cursor_plugin
	[[ "${status}" -eq 0 ]]
	[[ -f "$(quest_log_plugin_dir)/.cursor-plugin/plugin.json" ]]
}

@test "uninstall_cursor_plugin:: reports not installed when the directory is absent" {
	run uninstall_cursor_plugin
	[[ "${status}" -eq 0 ]]
	grep -q "not installed" <<<"${output}"
}

@test "uninstall_cursor_plugin:: removes an installed plugin directory" {
	install_cursor_plugin >/dev/null

	run uninstall_cursor_plugin
	[[ "${status}" -eq 0 ]]
	[[ ! -e "$(quest_log_plugin_dir)" ]]
}

@test "uninstall_cursor_plugin:: dry-run makes no changes" {
	install_cursor_plugin >/dev/null
	DRY_RUN=true

	run uninstall_cursor_plugin
	[[ "${status}" -eq 0 ]]
	grep -q "would remove" <<<"${output}"
	[[ -e "$(quest_log_plugin_dir)" ]]
}

########################################################
# main, end to end via the CLI
########################################################
@test "main:: install then uninstall via the CLI leaves no trace" {
	run "${SCRIPT}"
	[[ "${status}" -eq 0 ]]
	[[ -f "${TEST_HOME}/.zshrc" ]]
	[[ -f "${TEST_HOME}/.bashrc" ]]
	[[ -f "${TEST_HOME}/.cursor/plugins/local/quest-log/.cursor-plugin/plugin.json" ]]
	grep -Fqx "source \"${ZANGARMARSH_ROOT}/zangarmarsh.sh\"" "${TEST_HOME}/.zshrc"
	grep -Fqx "source \"${ZANGARMARSH_ROOT}/zangarmarsh.sh\"" "${TEST_HOME}/.bashrc"
	[[ ! -e "${TEST_HOME}/.aliases" ]]

	run "${SCRIPT}" --uninstall
	[[ "${status}" -eq 0 ]]
	! grep -Fq "zangarmarsh.sh" "${TEST_HOME}/.zshrc"
	! grep -Fq "zangarmarsh.sh" "${TEST_HOME}/.bashrc"
	[[ ! -e "${TEST_HOME}/.cursor/plugins/local/quest-log" ]]
}

@test "main:: --zsh installs only into ~/.zshrc" {
	run "${SCRIPT}" --zsh
	[[ "${status}" -eq 0 ]]
	grep -Fqx "source \"${ZANGARMARSH_ROOT}/zangarmarsh.sh\"" "${TEST_HOME}/.zshrc"
	[[ ! -e "${TEST_HOME}/.bashrc" ]]
}

@test "main:: --bash installs only into ~/.bashrc" {
	run "${SCRIPT}" --bash
	[[ "${status}" -eq 0 ]]
	grep -Fqx "source \"${ZANGARMARSH_ROOT}/zangarmarsh.sh\"" "${TEST_HOME}/.bashrc"
	[[ ! -e "${TEST_HOME}/.zshrc" ]]
}

@test "main:: --dry-run makes no changes" {
	run "${SCRIPT}" --dry-run
	[[ "${status}" -eq 0 ]]
	[[ ! -e "${TEST_HOME}/.zshrc" ]]
	[[ ! -e "${TEST_HOME}/.bashrc" ]]
	[[ ! -e "${TEST_HOME}/.cursor/plugins/local/quest-log" ]]
}

@test "main:: --dry-run --uninstall makes no changes" {
	"${SCRIPT}" >/dev/null

	run "${SCRIPT}" --dry-run --uninstall
	[[ "${status}" -eq 0 ]]
	grep -Fq "zangarmarsh.sh" "${TEST_HOME}/.zshrc"
	grep -Fq "zangarmarsh.sh" "${TEST_HOME}/.bashrc"
	[[ -e "${TEST_HOME}/.cursor/plugins/local/quest-log" ]]
}

@test "main:: rolls back the plugin when rc install fails" {
	mkdir -p "${HOME}/.zshrc"

	run main --zsh
	[[ "${status}" -eq 1 ]]
	[[ ! -e "$(quest_log_plugin_dir)" ]]
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

@test "main:: returns nonzero when uninstall_cursor_plugin fails" {
	"${SCRIPT}" >/dev/null

	uninstall_quest_plugin() {
		printf 'uninstall_quest_plugin:: forced failure\n' >&2
		return 1
	}

	run main --uninstall
	[[ "${status}" -eq 1 ]]
	grep -q "forced failure" <<<"${output}"
	! grep -Fq "zangarmarsh.sh" "${HOME}/.zshrc"
	! grep -Fq "zangarmarsh.sh" "${HOME}/.bashrc"
}
