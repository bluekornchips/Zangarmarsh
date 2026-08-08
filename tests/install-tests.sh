#!/usr/bin/env bats
#
# Tests for profile/install.sh: ~/.aliases sourcing and the quest-log Cursor plugin
#

GIT_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="${GIT_ROOT}/profile/install.sh"
[[ -f "${SCRIPT}" ]] || {
	echo "Script not found: ${SCRIPT}" >&2
	exit 1
}

export GIT_ROOT
export SCRIPT

# Isolate HOME per test, then source install.sh with its guard variables
# set the same way the direct-run entry block would set them.
setup() {
	local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"

	TEST_HOME="$(mktemp -d "${base}/install-test.XXXXXX")"
	HOME="${TEST_HOME}"
	ALIASES_FILE="${HOME}/.aliases"
	SCRIPT_ROOT="${GIT_ROOT}"
	DRY_RUN=false
	export HOME
	export ALIASES_FILE
	export SCRIPT_ROOT
	export DRY_RUN

	source "${SCRIPT}"
}

teardown() {
	rm -rf "${TEST_HOME}"
}

########################################################
# main, CLI option parsing
########################################################
@test "main:: --help exits 0 and prints usage" {
	run "${SCRIPT}" --help
	[[ "${status}" -eq 0 ]]
	grep -q "Usage:" <<<"${output}"
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
	[[ "${output}" == "source \"${SCRIPT_ROOT}/zangarmarsh.sh\"" ]]
	[[ "$(write_source_line | wc -c)" -eq $((${#output} + 1)) ]]
}

########################################################
# has_source_line
########################################################
@test "has_source_line:: returns 1 when ALIASES_FILE is missing" {
	run has_source_line
	[[ "${status}" -eq 1 ]]
}

@test "has_source_line:: returns 0 once the line is present" {
	write_source_line >"${ALIASES_FILE}"

	run has_source_line
	[[ "${status}" -eq 0 ]]
}

@test "has_source_line:: ignores a stale source line from another root" {
	printf 'source "/other/root/zangarmarsh.sh"\n' >"${ALIASES_FILE}"

	run has_source_line
	[[ "${status}" -eq 1 ]]
}

########################################################
# install_zangarmarsh
########################################################
@test "install_zangarmarsh:: creates ALIASES_FILE and appends the source line" {
	run install_zangarmarsh
	[[ "${status}" -eq 0 ]]

	[[ -f "${ALIASES_FILE}" ]]
	grep -Fqx "$(source_line_text)" "${ALIASES_FILE}"
	[[ "$(tail -c 1 "${ALIASES_FILE}" | wc -c)" -eq 1 ]]
	[[ -z "$(tail -c 1 "${ALIASES_FILE}")" ]]
}

@test "install_zangarmarsh:: preserves existing content and adds a newline first" {
	printf 'alias ll="ls -l"' >"${ALIASES_FILE}"

	run install_zangarmarsh
	[[ "${status}" -eq 0 ]]

	local expected_file="${HOME}/expected.aliases"
	printf 'alias ll="ls -l"\nsource "%s/zangarmarsh.sh"\n' "${SCRIPT_ROOT}" >"${expected_file}"
	cmp -s "${expected_file}" "${ALIASES_FILE}"
	[[ "$(wc -l <"${ALIASES_FILE}")" -eq 2 ]]
}

@test "install_zangarmarsh:: is idempotent on a second run" {
	install_zangarmarsh >/dev/null

	run install_zangarmarsh
	[[ "${status}" -eq 0 ]]
	grep -q "Already installed" <<<"${output}"
	[[ "$(grep -Fcx "$(source_line_text)" "${ALIASES_FILE}")" -eq 1 ]]
}

@test "install_zangarmarsh:: dry-run reports the change without writing" {
	DRY_RUN=true

	run install_zangarmarsh
	[[ "${status}" -eq 0 ]]
	grep -q "Would append" <<<"${output}"
	[[ ! -e "${ALIASES_FILE}" ]]
}

@test "install_zangarmarsh:: writes through a symlinked ALIASES_FILE" {
	local real_aliases="${HOME}/real-aliases"
	printf 'alias ll="ls -l"\n' >"${real_aliases}"
	ln -s "${real_aliases}" "${ALIASES_FILE}"

	run install_zangarmarsh
	[[ "${status}" -eq 0 ]]
	[[ -L "${ALIASES_FILE}" ]]
	grep -Fqx 'alias ll="ls -l"' "${real_aliases}"
	grep -Fqx "$(source_line_text)" "${real_aliases}"
}

@test "install_zangarmarsh:: fails when ALIASES_FILE is not writable" {
	mkdir -p "${ALIASES_FILE}"

	run install_zangarmarsh
	[[ "${status}" -eq 1 ]]
	grep -q "failed to append" <<<"${output}"
}

########################################################
# uninstall_zangarmarsh
########################################################
@test "uninstall_zangarmarsh:: reports not installed when ALIASES_FILE is missing" {
	run uninstall_zangarmarsh
	[[ "${status}" -eq 0 ]]
	grep -q "Not installed" <<<"${output}"
}

@test "uninstall_zangarmarsh:: removes only the Zangarmarsh line" {
	printf 'alias ll="ls -l"\n%s' "$(write_source_line)" >"${ALIASES_FILE}"

	run uninstall_zangarmarsh
	[[ "${status}" -eq 0 ]]

	grep -Fqx 'alias ll="ls -l"' "${ALIASES_FILE}"
	! grep -Fqx "$(source_line_text)" "${ALIASES_FILE}"
}

@test "uninstall_zangarmarsh:: preserves a symlinked ALIASES_FILE" {
	local real_aliases="${HOME}/real-aliases"
	printf 'alias ll="ls -l"\n%s' "$(write_source_line)" >"${real_aliases}"
	ln -s "${real_aliases}" "${ALIASES_FILE}"

	run uninstall_zangarmarsh
	[[ "${status}" -eq 0 ]]
	[[ -L "${ALIASES_FILE}" ]]
	grep -Fqx 'alias ll="ls -l"' "${real_aliases}"
	! grep -Fq "zangarmarsh.sh" "${real_aliases}"
}

@test "uninstall_zangarmarsh:: dry-run reports the change without writing" {
	write_source_line >"${ALIASES_FILE}"
	DRY_RUN=true

	run uninstall_zangarmarsh
	[[ "${status}" -eq 0 ]]
	grep -q "Would remove" <<<"${output}"
	grep -Fqx "$(source_line_text)" "${ALIASES_FILE}"
}

@test "uninstall_zangarmarsh:: leaves a stale source line from another root" {
	printf 'source "/other/root/zangarmarsh.sh"\n' >"${ALIASES_FILE}"

	run uninstall_zangarmarsh
	[[ "${status}" -eq 0 ]]
	grep -q "Not installed" <<<"${output}"
	grep -Fqx 'source "/other/root/zangarmarsh.sh"' "${ALIASES_FILE}"
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
	[[ -f "${TEST_HOME}/.aliases" ]]
	[[ -f "${TEST_HOME}/.cursor/plugins/local/quest-log/.cursor-plugin/plugin.json" ]]
	grep -Fqx "source \"${SCRIPT_ROOT}/zangarmarsh.sh\"" "${TEST_HOME}/.aliases"

	run "${SCRIPT}" --uninstall
	[[ "${status}" -eq 0 ]]
	! grep -Fq "zangarmarsh.sh" "${TEST_HOME}/.aliases"
	[[ ! -e "${TEST_HOME}/.cursor/plugins/local/quest-log" ]]
}

@test "main:: --dry-run makes no changes" {
	run "${SCRIPT}" --dry-run
	[[ "${status}" -eq 0 ]]
	[[ ! -e "${TEST_HOME}/.aliases" ]]
	[[ ! -e "${TEST_HOME}/.cursor/plugins/local/quest-log" ]]
}

@test "main:: --dry-run --uninstall makes no changes" {
	"${SCRIPT}" >/dev/null

	run "${SCRIPT}" --dry-run --uninstall
	[[ "${status}" -eq 0 ]]
	grep -Fq "zangarmarsh.sh" "${TEST_HOME}/.aliases"
	[[ -e "${TEST_HOME}/.cursor/plugins/local/quest-log" ]]
}

@test "main:: rolls back the plugin when aliases install fails" {
	mkdir -p "${ALIASES_FILE}"

	run main
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
	[[ ! -e "${ALIASES_FILE}" ]]
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
	! grep -Fq "zangarmarsh.sh" "${ALIASES_FILE}"
}
