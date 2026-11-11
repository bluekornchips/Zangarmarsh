#!/usr/bin/env bats
#
# Tests for apply_quest_log, run_quest_log, and the quest-log CLI
#

# Resolve the quest-log paths and load the repo fixtures for this file
#
# Side Effects:
# - Exports QUEST_LOG_ROOT, SCRIPT, and ZANGARMARSH_VSCODE_DIR
#
# Returns:
# - 0 on success
# - 1 when git or the repo fixtures cannot be loaded
setup_file() {
	GIT_ROOT="$(git rev-parse --show-toplevel)" || return 1
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1

	QUEST_LOG_ROOT="${ZANGARMARSH_ROOT}/tools/quest-log"
	SCRIPT="${QUEST_LOG_ROOT}/quest-log.sh"
	ZANGARMARSH_VSCODE_DIR="${ZANGARMARSH_ROOT}/tools/vscode"
	export QUEST_LOG_ROOT
	export SCRIPT
	export ZANGARMARSH_VSCODE_DIR

	return 0
}

# Load the quest-log fixtures and CLI libraries before each test
#
# Side Effects:
# - Creates a temporary HOME and sources quest-log.sh and apply.sh
#
# Returns:
# - 0 on success
setup() {
	source "$(dirname "${BATS_TEST_FILENAME}")/fixtures.sh"
	quest_log_test_setup
	return 0
}

# Remove the temporary directory created for one test
#
# Returns:
# - 0 always
teardown() {
	quest_log_test_teardown
	return 0
}

# Isolate HOME and source quest-log CLI and apply libraries for one test
#
# Side Effects:
# - Creates a temporary HOME via quest_log_test_home
# - Sources quest-log.sh and apply.sh
#
# Returns:
# - 0 on success
# - 1 when sourcing or directory change fails
quest_log_test_setup() {
	local return_dir="${PWD}"

	quest_log_test_home "quest-log-test"

	cd "${ZANGARMARSH_ROOT}" || return 1
	source_for_test "${SCRIPT}" || return 1
	source_for_test "${QUEST_LOG_ROOT}/lib/apply.sh" || return 1

	cd "${TEST_TEMP_DIR}" || {
		cd "${return_dir}" || true
		return 1
	}

	return 0
}

@test "integration:: run_quest_log overwrites Cursor user settings from template" {
	local settings_file
	settings_file="$(cursor_user_settings_path)"
	mkdir -p "$(dirname "${settings_file}")"
	printf '%s\n' '{
    "window.autoDetectColorScheme": true,
    "workbench.preferredDarkColorTheme": "Visual Studio Dark",
    "git.suggestSmartCommit": false
}' >"${settings_file}"

	run run_quest_log
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "Updated: .*settings.json"
	jq -e '.["workbench.colorTheme"] == "Default Dark+"' "${settings_file}"
	jq -e '.["editor.formatOnSave"] == true' "${settings_file}"
	jq -e 'has("git.suggestSmartCommit") | not' "${settings_file}"
}

@test "integration:: run_quest_log writes macOS Application Support settings path" {
	local mock_bin="${BATS_TEST_TMPDIR}/uname-mock-bin"
	mkdir -p "${mock_bin}"
	cat >"${mock_bin}/uname" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-s" ]]; then
	echo "Darwin"
	exit 0
fi
exec /usr/bin/uname "$@"
EOF
	chmod +x "${mock_bin}/uname"

	PATH="${mock_bin}:${PATH}" run run_quest_log
	[[ "${status}" -eq 0 ]]
	[[ -f "${HOME}/Library/Application Support/Cursor/User/settings.json" ]]
	jq -e '.["editor.formatOnSave"] == true' "${HOME}/Library/Application Support/Cursor/User/settings.json"
	[[ ! -e "${HOME}/.config/Cursor/User/settings.json" ]]
}

@test "run_quest_log:: fails when plugin source is missing" {
	PLUGIN_SOURCE_DIR="/tmp/does-not-exist-plugin" run run_quest_log
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "plugin source not found"
}

@test "run_quest_log:: displays help message" {
	run run_quest_log --help
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "Install the quest-log Cursor plugin"
	echo "${output}" | grep -q "\-\-help"
}

@test "run_quest_log:: handles unknown options" {
	run run_quest_log --unknown-option
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "run_quest_log:: Unknown option"
}

@test "run_quest_log:: rejects leftover directory arguments" {
	run run_quest_log /tmp/some-project
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "run_quest_log:: Unexpected argument"
}

@test "run_quest_log:: dry-run does not write plugin, rules, or Cursor settings" {
	run run_quest_log --dry-run
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "would replace"
	echo "${output}" | grep -q "Would write: .*zangarmarsh-always.mdc"
	echo "${output}" | grep -q "Would write: .*settings.json"
	[[ ! -e "${HOME}/.cursor" ]]
	[[ ! -e "$(cursor_user_settings_path)" ]]
}

@test "run_quest_log:: accepts the short dry-run flag" {
	run run_quest_log -r
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "would replace"
	[[ ! -e "${HOME}/.cursor" ]]
}

@test "integration:: run_quest_log installs plugin, rules, and overwrites host Cursor settings" {
	run run_quest_log
	[[ "${status}" -eq 0 ]]
	[[ -f "${TEST_PLUGIN_DIR}/rules/always.mdc" ]]
	[[ -f "${TEST_PLUGIN_DIR}/skills/blue-review/SKILL.md" ]]
	[[ -f "${TEST_PLUGIN_DIR}/.cursor-plugin/plugin.json" ]]
	[[ -f "${TEST_RULES_DIR}/zangarmarsh-always.mdc" ]]
	[[ ! -e "${TEST_RULES_DIR}/always.mdc" ]]
	cmp -s "${PLUGIN_SOURCE_DIR}/rules/always.mdc" "${TEST_RULES_DIR}/zangarmarsh-always.mdc"
	local settings_file
	settings_file="$(cursor_user_settings_path)"
	[[ -f "${settings_file}" ]]
	jq -e '.["editor.formatOnSave"] == true' "${settings_file}"
	jq -e --slurpfile t "${ZANGARMARSH_VSCODE_DIR}/settings.json" '. == $t[0]' "${settings_file}"
}

@test "integration:: run_quest_log reports each step and completion" {
	run run_quest_log
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "Created: .*zangarmarsh-always.mdc"
	echo "${output}" | grep -q "install_quest_plugin: complete"
	echo "${output}" | grep -q "quest-log: complete"
}

@test "integration:: run_quest_log reports no changes on a second identical run" {
	run run_quest_log
	[[ "${status}" -eq 0 ]]

	run run_quest_log
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "No changes:"
}

@test "run_quest_log:: rejects force flag" {
	run run_quest_log --force
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "run_quest_log:: Unknown option"
}

@test "run_quest_log:: rejects short force flag" {
	run run_quest_log -f
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "run_quest_log:: Unknown option"
}

@test "integration:: apply_quest_log leaves an existing plugin untouched when settings sync fails" {
	mkdir -p "${TEST_PLUGIN_DIR}/rules"
	echo "previous-plugin" >"${TEST_PLUGIN_DIR}/rules/always.mdc"

	# Stub the settings sync so apply reports a forced failure
	#
	# Side Effects:
	# - Writes a forced failure message to stderr
	#
	# Returns:
	# - 1 always
	sync_cursor_user_settings() {
		echo "sync_cursor_user_settings:: forced failure" >&2

		return 1
	}

	run apply_quest_log
	[[ "${status}" -eq 1 ]]
	grep -q "previous-plugin" "${TEST_PLUGIN_DIR}/rules/always.mdc"
	[[ ! -e "${TEST_RULES_DIR}" ]]
	[[ ! -e "$(cursor_user_settings_path)" ]]
}

@test "integration:: apply_quest_log keeps previous settings and skips rules when settings write fails" {
	local settings_file
	settings_file="$(cursor_user_settings_path)"
	mkdir -p "$(dirname "${settings_file}")"
	echo '{"previous":true}' >"${settings_file}"

	# Stub the atomic write so the settings write fails
	#
	# Returns:
	# - 1 always
	write_atomic() {
		return 1
	}

	run apply_quest_log
	[[ "${status}" -eq 1 ]]
	grep -q '"previous":true' "${settings_file}"
	[[ ! -e "${TEST_RULES_DIR}" ]]
	[[ ! -e "${TEST_PLUGIN_DIR}" ]]
}

@test "integration:: tracked plugin ships the declared rules and skills" {
	local tracked_plugin="${ZANGARMARSH_ROOT}/tools/quest-log/plugin"

	[[ -f "${tracked_plugin}/.cursor-plugin/plugin.json" ]]
	local rule
	for rule in always never shell bash zsh python lua javascript typescript; do
		[[ -f "${tracked_plugin}/rules/${rule}.mdc" ]]
	done

	local skill
	for skill in blue-author blue-penmanship blue-review-comments blue-review blue-review-bash blue-review-lua blue-review-python blue-review-typescript blue-python-setup blueberry; do
		[[ -f "${tracked_plugin}/skills/${skill}/SKILL.md" ]]
	done

	[[ ! -e "${tracked_plugin}/MCP.md" ]]
}

@test "integration:: tracked plugin install replaces a live tree with the declared assets" {
	local tracked_plugin="${ZANGARMARSH_ROOT}/tools/quest-log/plugin"

	mkdir -p "${TEST_PLUGIN_DIR}/skills/blue-retired" "${TEST_PLUGIN_DIR}/rules"
	echo "stale" >"${TEST_PLUGIN_DIR}/skills/blue-retired/SKILL.md"
	echo "stale" >"${TEST_PLUGIN_DIR}/rules/extra.mdc"

	run install_quest_plugin "${tracked_plugin}"
	[[ "${status}" -eq 0 ]]
	[[ -f "${TEST_PLUGIN_DIR}/rules/always.mdc" ]]
	[[ -f "${TEST_PLUGIN_DIR}/rules/bash.mdc" ]]
	[[ -f "${TEST_PLUGIN_DIR}/rules/zsh.mdc" ]]
	[[ -f "${TEST_PLUGIN_DIR}/skills/blue-author/SKILL.md" ]]
	[[ -f "${TEST_PLUGIN_DIR}/skills/blue-review/SKILL.md" ]]
	[[ -f "${TEST_PLUGIN_DIR}/.cursor-plugin/plugin.json" ]]
	[[ ! -e "${TEST_PLUGIN_DIR}/skills/blue-retired" ]]
	[[ ! -f "${TEST_PLUGIN_DIR}/rules/extra.mdc" ]]
}

@test "quest-log.sh:: --help works without a pre-set ZANGARMARSH_ROOT" {
	run env -u ZANGARMARSH_ROOT HOME="${HOME}" PATH="${PATH}" bash "${SCRIPT}" --help
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "Install the quest-log Cursor plugin"
}

@test "quest-log.sh:: --help works with a decoy ZANGARMARSH_ROOT" {
	run env ZANGARMARSH_ROOT="/nonexistent/zangarmarsh-root" HOME="${HOME}" PATH="${PATH}" \
		bash "${SCRIPT}" --help
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "Install the quest-log Cursor plugin"
}

@test "run_quest_log:: ignores an inherited ZANGARMARSH_ROOT from another checkout" {
	local other_root="${TEST_TEMP_DIR}/other-root"
	mkdir -p "${other_root}"
	printf '# decoy\n' >"${other_root}/zangarmarsh.sh"

	run env ZANGARMARSH_ROOT="${other_root}" HOME="${HOME}" PATH="${PATH}" \
		bash "${SCRIPT}" --dry-run
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -Fq "quest-log: complete"
}

@test "write_if_changed:: returns failure when the target directory is not writable" {
	local target_dir="${TEST_TEMP_DIR}/readonly-dir"
	local target="${target_dir}/settings.json"
	mkdir -p "${target_dir}"
	chmod a-w "${target_dir}"

	run write_if_changed "${target}" '{"ok":true}' "write_if_changed"
	local write_status="${status}"
	chmod u+w "${target_dir}"
	[[ "${write_status}" -eq 1 ]]
	echo "${output}" | grep -q "write_if_changed:: Failed to create staging file"
}
