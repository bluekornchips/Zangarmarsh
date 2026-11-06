#!/usr/bin/env bats
#
# Tests for print_summary, apply_quest_log, and run_quest_log
#

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

setup() {
	source "$(dirname "${BATS_TEST_FILENAME}")/fixtures.sh"
	quest_log_test_setup

	return 0
}

teardown() {
	quest_log_test_teardown
	return 0
}

quest_log_test_setup() {
	local return_dir="${PWD}"

	quest_log_test_home "quest-log-test"

	cd "${ZANGARMARSH_ROOT}" || return 1
	source_for_test "$SCRIPT" || return 1
	SCRIPT_DIR="${QUEST_LOG_ROOT}"
	export SCRIPT_DIR
	source_for_test "${ZANGARMARSH_ROOT}/tools/quest-log/lib/apply.sh" || return 1

	cd "${TEST_TEMP_DIR}" || {
		cd "${return_dir}" || true
		return 1
	}

	STATS_CREATED=0
	STATS_UPDATED=0
	STATS_UNCHANGED=0
	STATS_ERRORS=0
	PLUGIN_ACTION=""
	RULES_ACTION=""
	export STATS_CREATED STATS_UPDATED STATS_UNCHANGED STATS_ERRORS PLUGIN_ACTION RULES_ACTION

	return 0
}

########################################################
# print_summary
########################################################

@test 'print_summary:: displays summary with all statistics' {
	STATS_CREATED=2
	STATS_UPDATED=3
	STATS_UNCHANGED=1
	STATS_ERRORS=0
	PLUGIN_ACTION="install"
	RULES_ACTION="sync"

	run print_summary
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "quest-log summary"
	echo "$output" | grep -q "plugin: install"
	echo "$output" | grep -q "rules: sync"
	echo "$output" | grep -q "cursor created: 2"
	echo "$output" | grep -q "cursor updated: 3"
	echo "$output" | grep -q "cursor unchanged: 1"
	echo "$output" | grep -q "cursor total: 6"
}

@test 'print_summary:: returns error status when errors exist' {
	STATS_CREATED=1
	STATS_UPDATED=0
	STATS_UNCHANGED=0
	STATS_ERRORS=1

	run print_summary
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "cursor: 1 error(s)"
	echo "$output" | grep -q "print_summary:: cursor settings sync failed"
}

@test 'print_summary:: reports no cursor file sync when counters are zero' {
	STATS_CREATED=0
	STATS_UPDATED=0
	STATS_UNCHANGED=0
	STATS_ERRORS=0

	run print_summary
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "cursor: no files synced"
}

########################################################
# sync_cursor_user_settings / run_quest_log
########################################################

@test 'integration:: run_quest_log overwrites Cursor user settings from template' {
	local settings_file
	settings_file="$(cursor_user_settings_path)"
	mkdir -p "$(dirname "${settings_file}")"
	printf '%s\n' '{
    "window.autoDetectColorScheme": true,
    "workbench.preferredDarkColorTheme": "Visual Studio Dark",
    "git.suggestSmartCommit": false
}' >"${settings_file}"

	run run_quest_log
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "sync_cursor_user_settings:: writing"
	jq -e '.["workbench.colorTheme"] == "Default Dark+"' "${settings_file}"
	jq -e '.["editor.formatOnSave"] == true' "${settings_file}"
	jq -e 'has("git.suggestSmartCommit") | not' "${settings_file}"
}

@test 'integration:: run_quest_log writes macOS Application Support settings path' {
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
	[[ "$status" -eq 0 ]]
	[[ -f "${HOME}/Library/Application Support/Cursor/User/settings.json" ]]
	jq -e '.["editor.formatOnSave"] == true' "${HOME}/Library/Application Support/Cursor/User/settings.json"
	[[ ! -e "${HOME}/.config/Cursor/User/settings.json" ]]
	unset -f uname
}

@test 'run_quest_log:: fails when plugin source is missing' {
	# Prefix keeps the fixture PLUGIN_SOURCE_DIR intact for later tests.
	PLUGIN_SOURCE_DIR="/tmp/does-not-exist-plugin" run run_quest_log
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "plugin source not found"
}

@test 'run_quest_log:: displays help message' {
	run run_quest_log --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Install the quest-log Cursor plugin"
	echo "$output" | grep -q "\-\-help"
}

@test 'run_quest_log:: handles unknown options' {
	run run_quest_log --unknown-option
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_quest_log:: Unknown option"
}

@test 'run_quest_log:: rejects leftover directory arguments' {
	run run_quest_log /tmp/some-project
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_quest_log:: Unexpected argument"
}

@test 'run_quest_log:: dry-run does not write plugin, rules, or Cursor settings' {
	run run_quest_log --dry-run
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "would replace"
	echo "$output" | grep -q "would sync"
	echo "$output" | grep -q "would overwrite"
	[[ ! -e "${QUEST_LOG_PLUGIN_DIR}" ]]
	[[ ! -e "${QUEST_LOG_RULES_DIR}" ]]
	[[ ! -e "$(cursor_user_settings_path)" ]]
}

@test 'run_quest_log:: accepts the short dry-run flag' {
	run run_quest_log -r
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "would replace"
	[[ ! -e "${QUEST_LOG_PLUGIN_DIR}" ]]
	[[ ! -e "${QUEST_LOG_RULES_DIR}" ]]
}

@test 'integration:: run_quest_log installs plugin, rules, and overwrites host Cursor settings' {
	run run_quest_log
	[[ "$status" -eq 0 ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/rules/always.mdc" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/skills/blue-review/SKILL.md" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/.cursor-plugin/plugin.json" ]]
	[[ -f "${QUEST_LOG_RULES_DIR}/always.mdc" ]]
	[[ -f "${QUEST_LOG_RULES_DIR}/.quest-log.manifest" ]]
	cmp -s "${PLUGIN_SOURCE_DIR}/rules/always.mdc" "${QUEST_LOG_RULES_DIR}/always.mdc"
	local settings_file
	settings_file="$(cursor_user_settings_path)"
	[[ -f "${settings_file}" ]]
	jq -e '.["editor.formatOnSave"] == true' "${settings_file}"
	jq -e --slurpfile t "${ZANGARMARSH_VSCODE_DIR}/settings.json" '. == $t[0]' "${settings_file}"
}

@test 'integration:: run_quest_log displays summary at end of execution' {
	run run_quest_log
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "quest-log summary"
	echo "$output" | grep -q "plugin: install"
	echo "$output" | grep -q "rules: sync"
	echo "$output" | grep -Eq 'cursor: no files synced|cursor total:'
}

@test 'integration:: run_quest_log reports no changes on a second identical run' {
	run run_quest_log
	[[ "$status" -eq 0 ]]

	run run_quest_log
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "No changes:"
}

@test 'run_quest_log:: rejects force flag' {
	run run_quest_log --force
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_quest_log:: Unknown option"
}

@test 'run_quest_log:: rejects short force flag' {
	run run_quest_log -f
	[[ "$status" -eq 1 ]]
	echo "$output" | grep -q "run_quest_log:: Unknown option"
}

@test 'apply_quest_log:: backup trap does not evaluate TMPDIR metacharacters' {
	local marker="${TEST_TEMP_DIR}/pwned"
	# Intentional injection payload: proves the RETURN trap quotes backup_root.
	# shellcheck disable=SC2089
	local tricky="${TEST_TEMP_DIR}/tmp-a\"; touch ${marker}; echo \""
	mkdir -p "${tricky}"

	sync_cursor_user_settings() {

		return 0
	}

	TMPDIR="${tricky}"
	# shellcheck disable=SC2090
	export TMPDIR

	run apply_quest_log --settings-only
	[[ "$status" -eq 0 ]]
	[[ ! -e "${marker}" ]]
}

@test 'apply_quest_log:: plugin-only skips Cursor settings and syncs rules' {
	run apply_quest_log --plugin-only
	[[ "$status" -eq 0 ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/.cursor-plugin/plugin.json" ]]
	[[ -f "${QUEST_LOG_RULES_DIR}/always.mdc" ]]
	[[ ! -e "$(cursor_user_settings_path)" ]]
}

@test 'apply_quest_log:: settings-only skips plugin and rules' {
	run apply_quest_log --settings-only
	[[ "$status" -eq 0 ]]
	[[ ! -e "${QUEST_LOG_PLUGIN_DIR}" ]]
	[[ ! -e "${QUEST_LOG_RULES_DIR}" ]]
	[[ -f "$(cursor_user_settings_path)" ]]
}

@test 'integration:: apply_quest_log leaves an existing plugin untouched when settings sync fails' {
	mkdir -p "${QUEST_LOG_PLUGIN_DIR}/rules"
	echo "previous-plugin" >"${QUEST_LOG_PLUGIN_DIR}/rules/always.mdc"

	sync_cursor_user_settings() {
		echo "sync_cursor_user_settings:: forced failure" >&2

		return 1
	}

	run apply_quest_log
	[[ "$status" -eq 1 ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/rules/always.mdc" ]]
	grep -q "previous-plugin" "${QUEST_LOG_PLUGIN_DIR}/rules/always.mdc"
	[[ ! -e "${QUEST_LOG_RULES_DIR}" ]]
	[[ ! -e "$(cursor_user_settings_path)" ]]
}

@test 'integration:: apply_quest_log restores previous settings when sync fails' {
	local settings_file
	settings_file="$(cursor_user_settings_path)"
	mkdir -p "$(dirname "${settings_file}")"
	echo '{"previous":true}' >"${settings_file}"

	sync_cursor_user_settings() {
		echo '{"partial":true}' >"$(cursor_user_settings_path)"
		echo "sync_cursor_user_settings:: forced failure" >&2

		return 1
	}

	run apply_quest_log --settings-only
	[[ "$status" -eq 1 ]]
	grep -q '"previous":true' "${settings_file}"
}

@test 'integration:: apply_quest_log skips plugin and rules install and clears partial settings when sync fails' {
	sync_cursor_user_settings() {
		echo '{"partial":true}' >"$(cursor_user_settings_path)"
		echo "sync_cursor_user_settings:: forced failure" >&2

		return 1
	}

	run apply_quest_log
	[[ "$status" -eq 1 ]]
	[[ ! -e "${QUEST_LOG_PLUGIN_DIR}" ]]
	[[ ! -e "${QUEST_LOG_RULES_DIR}" ]]
	[[ ! -e "$(cursor_user_settings_path)" ]]
}

@test '_quest_log_backup_settings:: copies an existing settings file' {
	local backup_root="${TEST_TEMP_DIR}/backup"
	local settings_file="${TEST_TEMP_DIR}/settings.json"
	mkdir -p "${backup_root}"
	echo '{}' >"${settings_file}"

	run _quest_log_backup_settings "${backup_root}" "${settings_file}"
	[[ "$status" -eq 0 ]]
	[[ -f "${backup_root}/settings.json" ]]
}

########################################################
# Tracked plugin coherence
########################################################
@test 'integration:: tracked plugin ships the declared rules and skills' {
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

@test 'integration:: tracked plugin install replaces a live tree with the declared assets' {
	local tracked_plugin="${ZANGARMARSH_ROOT}/tools/quest-log/plugin"

	mkdir -p "${QUEST_LOG_PLUGIN_DIR}/skills/blue-retired" "${QUEST_LOG_PLUGIN_DIR}/rules"
	echo "stale" >"${QUEST_LOG_PLUGIN_DIR}/skills/blue-retired/SKILL.md"
	echo "stale" >"${QUEST_LOG_PLUGIN_DIR}/rules/extra.mdc"

	run install_quest_plugin "${tracked_plugin}"
	[[ "$status" -eq 0 ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/rules/always.mdc" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/rules/bash.mdc" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/rules/zsh.mdc" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/skills/blue-author/SKILL.md" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/skills/blue-review/SKILL.md" ]]
	[[ -f "${QUEST_LOG_PLUGIN_DIR}/.cursor-plugin/plugin.json" ]]
	[[ ! -e "${QUEST_LOG_PLUGIN_DIR}/skills/blue-retired" ]]
	[[ ! -f "${QUEST_LOG_PLUGIN_DIR}/rules/extra.mdc" ]]
}

@test 'quest-log.sh:: --help works without a pre-set ZANGARMARSH_ROOT' {
	run env -u ZANGARMARSH_ROOT HOME="${HOME}" PATH="${PATH}" bash "${SCRIPT}" --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Install the quest-log Cursor plugin"
}

@test 'quest-log.sh:: --help works with a decoy ZANGARMARSH_ROOT' {
	run env ZANGARMARSH_ROOT="/nonexistent/zangarmarsh-root" HOME="${HOME}" PATH="${PATH}" \
		bash "${SCRIPT}" --help
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -q "Install the quest-log Cursor plugin"
}

@test 'run_quest_log:: ignores an inherited ZANGARMARSH_ROOT from another checkout' {
	local other_root="${TEST_TEMP_DIR}/other-root"
	mkdir -p "${other_root}"
	printf '# decoy\n' >"${other_root}/zangarmarsh.sh"

	run env ZANGARMARSH_ROOT="${other_root}" HOME="${HOME}" PATH="${PATH}" \
		bash "${SCRIPT}" --dry-run
	[[ "$status" -eq 0 ]]
	echo "$output" | grep -Fq "quest-log: complete"
}

@test 'write_if_changed:: returns failure when the target file is not writable' {
	local target="${TEST_TEMP_DIR}/readonly-settings.json"
	printf '{}\n' >"${target}"
	chmod a-w "${target}"

	run write_if_changed "${target}" '{"ok":true}' "write_if_changed"
	local write_status="${status}"
	chmod u+w "${target}"
	[[ "${write_status}" -eq 1 ]]
	echo "$output" | grep -q "Failed to write file"
}
