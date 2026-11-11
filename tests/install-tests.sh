#!/usr/bin/env bats
#
# Tests for profile/install.sh: the marked rc block and the quest-log plugin
#

# Load the repo fixtures and resolve the installer path for every test
#
# Side Effects:
# - Sets GIT_ROOT and exports SCRIPT
#
# Returns:
# - 0 on success
# - 1 when the git root or fixtures cannot be loaded
setup_file() {
	GIT_ROOT="$(git rev-parse --show-toplevel)" || return 1
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1

	SCRIPT="${ZANGARMARSH_ROOT}/profile/install.sh"
	export SCRIPT

	return 0
}

# Isolate HOME per test and load the installer and quest-log functions
#
# Side Effects:
# - Creates TEST_HOME and points HOME and RC_FILE at it
# - Sets BASH_RC to the bash rc path for the current platform
#
# Returns:
# - 0 on success
# - 1 when the bash rc path cannot be resolved
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
	BASH_RC="$(bash_rc_path)" || return 1

	return 0
}

# Remove the per-test HOME directory
#
# Side Effects:
# - Deletes TEST_HOME
#
# Returns:
# - 0 always
teardown() {
	rm -rf "${TEST_HOME}"

	return 0
}

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

@test "validate_install_env:: fails when HOME is empty" {
	HOME="" run validate_install_env
	[[ "${status}" -eq 1 ]]
	grep -q "HOME is required" <<<"${output}"
}

@test "_rc_block:: emits the marked block without a trailing newline" {
	local expected
	expected="$(printf '%s\nsource %q\n%s' "${RC_BLOCK_START}" "${ZANGARMARSH_ROOT}/zangarmarsh.sh" "${RC_BLOCK_END}")"

	run _rc_block
	[[ "${status}" -eq 0 ]]
	[[ "${output}" == "${expected}" ]]
	[[ "$(printf '%s\n' "$(_rc_block)" | wc -c)" -eq $((${#output} + 1)) ]]
}

@test "_rc_block:: quotes a root that contains shell metacharacters" {
	local marker="${TEST_HOME}/pwned"
	local weird_root="${TEST_HOME}/a\"b; touch ${marker}; echo \""
	local block
	block="$(ZANGARMARSH_ROOT="${weird_root}" _rc_block)"

	run bash -c "${block}"
	[[ "${status}" -ne 0 ]]
	[[ ! -e "${marker}" ]]
}

@test "bash_rc_path:: resolves ~/.bashrc on Linux" {
	# Stub the platform id so bash_rc_path takes the Linux branch
	#
	# Outputs:
	# - linux-amd64 on stdout
	#
	# Returns:
	# - 0 always
	_detect_platform() {
		echo "linux-amd64"
		return 0
	}

	run bash_rc_path
	[[ "${status}" -eq 0 ]]
	[[ "${output}" == "${HOME}/.bashrc" ]]
}

@test "bash_rc_path:: resolves ~/.bash_profile on macOS" {
	# Stub the platform id so bash_rc_path takes the macOS branch
	#
	# Outputs:
	# - darwin-arm64 on stdout
	#
	# Returns:
	# - 0 always
	_detect_platform() {
		echo "darwin-arm64"
		return 0
	}

	run bash_rc_path
	[[ "${status}" -eq 0 ]]
	[[ "${output}" == "${HOME}/.bash_profile" ]]
}

@test "install_zangarmarsh:: creates RC_FILE with the marked block" {
	run install_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]
	grep -q "Installing into" <<<"${output}"

	printf '%s\n' "$(_rc_block)" >"${HOME}/expected.zshrc"
	cmp -s "${HOME}/expected.zshrc" "${RC_FILE}"
}

@test "install_zangarmarsh:: preserves existing content and adds a newline first" {
	printf 'alias ll="ls -l"' >"${RC_FILE}"

	run install_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]

	printf 'alias ll="ls -l"\n%s\n' "$(_rc_block)" >"${HOME}/expected.zshrc"
	cmp -s "${HOME}/expected.zshrc" "${RC_FILE}"
}

@test "install_zangarmarsh:: is idempotent on a second run" {
	if ! install_zangarmarsh "${RC_FILE}" >/dev/null; then
		return 1
	fi

	run install_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]
	grep -q "Already installed" <<<"${output}"
	[[ "$(grep -Fcx "${RC_BLOCK_START}" "${RC_FILE}")" -eq 1 ]]
}

@test "install_zangarmarsh:: replaces a stale block in place and keeps other lines" {
	{
		printf 'alias ll="ls -l"\n'
		printf '%s\n' "${RC_BLOCK_START}"
		printf 'source "/old/root/zangarmarsh.sh"\n'
		printf '%s\n' "${RC_BLOCK_END}"
		printf 'export EDITOR=vi\n'
	} >"${RC_FILE}"

	run install_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]

	printf 'alias ll="ls -l"\n%s\nexport EDITOR=vi\n' "$(_rc_block)" >"${HOME}/expected.zshrc"
	cmp -s "${HOME}/expected.zshrc" "${RC_FILE}"
}

@test "install_zangarmarsh:: rejects a block start without an end marker" {
	printf 'alias ll="ls -l"\n%s\nsource "/old/root/zangarmarsh.sh"\n' "${RC_BLOCK_START}" >"${RC_FILE}"
	cp "${RC_FILE}" "${HOME}/before.zshrc"

	run install_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 1 ]]
	grep -q "unmatched Zangarmarsh markers" <<<"${output}"
	cmp -s "${HOME}/before.zshrc" "${RC_FILE}"
}

@test "install_zangarmarsh:: leaves eager NVM lines in the bash rc file" {
	cat >"${BASH_RC}" <<EOF
alias ll="ls -l"
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \\. "\$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "\$NVM_DIR/bash_completion" ] && \\. "\$NVM_DIR/bash_completion"  # This loads nvm bash_completion
EOF

	run install_zangarmarsh "${BASH_RC}"
	[[ "${status}" -eq 0 ]]
	grep -Fqx "export NVM_DIR=\"\$HOME/.nvm\"" "${BASH_RC}"
	grep -Fq 'nvm.sh' "${BASH_RC}"
	grep -Fqx "${RC_BLOCK_START}" "${BASH_RC}"
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
	grep -Fqx "${RC_BLOCK_START}" "${real_rc}"
}

@test "install_zangarmarsh:: fails when RC_FILE is a directory" {
	mkdir -p "${RC_FILE}"

	run install_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 1 ]]
	grep -q "rc path is a directory" <<<"${output}"
}

@test "uninstall_zangarmarsh:: reports not installed when RC_FILE is missing" {
	run uninstall_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]
	grep -q "Not installed" <<<"${output}"
}

@test "uninstall_zangarmarsh:: removes only the marked block" {
	{
		printf 'alias ll="ls -l"\n'
		printf '%s\n' "$(_rc_block)"
	} >"${RC_FILE}"

	run uninstall_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]
	grep -q "Removing from" <<<"${output}"
	[[ "$(cat "${RC_FILE}")" == 'alias ll="ls -l"' ]]
}

@test "uninstall_zangarmarsh:: removes every marked block" {
	{
		printf '%s\n' "$(_rc_block)"
		printf 'alias ll="ls -l"\n'
		printf '%s\n' "$(_rc_block)"
	} >"${RC_FILE}"

	run uninstall_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]
	[[ "$(cat "${RC_FILE}")" == 'alias ll="ls -l"' ]]
}

@test "uninstall_zangarmarsh:: preserves a symlinked RC_FILE" {
	local real_rc="${HOME}/real-zshrc"
	printf 'alias ll="ls -l"\n%s\n' "$(_rc_block)" >"${real_rc}"
	ln -s "${real_rc}" "${RC_FILE}"

	run uninstall_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]
	[[ -L "${RC_FILE}" ]]
	grep -Fqx 'alias ll="ls -l"' "${real_rc}"
	matched=0
	grep -Fq "${RC_BLOCK_START}" "${real_rc}" && matched=1
	[[ "${matched}" -eq 0 ]]
}

@test "uninstall_zangarmarsh:: dry-run reports the change without writing" {
	printf '%s\n' "$(_rc_block)" >"${RC_FILE}"
	DRY_RUN=true

	run uninstall_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]
	grep -q "Would remove" <<<"${output}"
	grep -Fqx "${RC_BLOCK_START}" "${RC_FILE}"
}

@test "uninstall_zangarmarsh:: keeps unmarked source lines" {
	printf 'source "/other/root/zangarmarsh.sh"\n' >"${RC_FILE}"

	run uninstall_zangarmarsh "${RC_FILE}"
	[[ "${status}" -eq 0 ]]
	grep -q "Not installed" <<<"${output}"
	grep -Fqx 'source "/other/root/zangarmarsh.sh"' "${RC_FILE}"
}

@test "quest_log_plugin_dir:: resolves under HOME" {
	run quest_log_plugin_dir
	[[ "${status}" -eq 0 ]]
	[[ "${output}" == "${HOME}/.cursor/plugins/local/quest-log" ]]
}

@test "install_quest_log:: dry-run makes no changes" {
	DRY_RUN=true

	run install_quest_log
	[[ "${status}" -eq 0 ]]
	grep -q "would replace" <<<"${output}"
	grep -q "Would write" <<<"${output}"
	[[ ! -e "$(quest_log_plugin_dir)" ]]
	[[ ! -e "$(quest_log_rules_dir)" ]]
	[[ ! -e "$(cursor_user_settings_path)" ]]
}

@test "install_quest_log:: installs the plugin, prefixed rules, and settings under HOME" {
	run install_quest_log
	[[ "${status}" -eq 0 ]]
	[[ -f "$(quest_log_plugin_dir)/.cursor-plugin/plugin.json" ]]
	[[ -f "$(quest_log_rules_dir)/zangarmarsh-always.mdc" ]]
	[[ -f "$(cursor_user_settings_path)" ]]
	grep -q "DejaVu Sans Mono" "$(cursor_user_settings_path)"
}

@test "uninstall_quest_plugin:: reports not installed when the directory is absent" {
	run uninstall_quest_plugin
	[[ "${status}" -eq 0 ]]
	grep -q "not installed" <<<"${output}"
}

@test "uninstall_quest_plugin:: removes an installed plugin directory" {
	if ! install_quest_log >/dev/null; then
		return 1
	fi

	run uninstall_quest_plugin
	[[ "${status}" -eq 0 ]]
	[[ ! -e "$(quest_log_plugin_dir)" ]]
}

@test "uninstall_quest_plugin:: dry-run makes no changes" {
	if ! install_quest_log >/dev/null; then
		return 1
	fi
	DRY_RUN=true

	run uninstall_quest_plugin
	[[ "${status}" -eq 0 ]]
	grep -q "would remove" <<<"${output}"
	[[ -e "$(quest_log_plugin_dir)" ]]
}

@test "uninstall_quest_rules:: removes prefixed rules installed by install_quest_log" {
	if ! install_quest_log >/dev/null; then
		return 1
	fi

	run uninstall_quest_rules
	[[ "${status}" -eq 0 ]]
	[[ ! -f "$(quest_log_rules_dir)/zangarmarsh-always.mdc" ]]
}

@test "integration:: install then uninstall removes the block, plugin, and rules" {
	run "${SCRIPT}"
	[[ "${status}" -eq 0 ]]
	grep -Fqx "${RC_BLOCK_START}" "${RC_FILE}"
	grep -Fqx "${RC_BLOCK_START}" "${BASH_RC}"
	[[ -f "$(quest_log_plugin_dir)/.cursor-plugin/plugin.json" ]]
	[[ -f "$(quest_log_rules_dir)/zangarmarsh-always.mdc" ]]
	[[ -f "$(cursor_user_settings_path)" ]]
	[[ -f "$(user_fonts_dir)/DejaVuSansMono.ttf" ]]

	run "${SCRIPT}" --uninstall
	[[ "${status}" -eq 0 ]]
	matched=0
	grep -Fq "zangarmarsh.sh" "${RC_FILE}" && matched=1
	[[ "${matched}" -eq 0 ]]
	matched=0
	grep -Fq "zangarmarsh.sh" "${BASH_RC}" && matched=1
	[[ "${matched}" -eq 0 ]]
	[[ ! -e "$(quest_log_plugin_dir)" ]]
	[[ ! -f "$(quest_log_rules_dir)/zangarmarsh-always.mdc" ]]
	[[ -f "$(cursor_user_settings_path)" ]]
	[[ -f "$(user_fonts_dir)/DejaVuSansMono.ttf" ]]
}

@test "integration:: --zsh installs only into ~/.zshrc" {
	run "${SCRIPT}" --zsh
	[[ "${status}" -eq 0 ]]
	grep -Fqx "${RC_BLOCK_START}" "${RC_FILE}"
	[[ ! -e "${BASH_RC}" ]]
}

@test "integration:: --bash installs only into the bash rc file" {
	run "${SCRIPT}" --bash
	[[ "${status}" -eq 0 ]]
	grep -Fqx "${RC_BLOCK_START}" "${BASH_RC}"
	[[ ! -e "${RC_FILE}" ]]
}

@test "integration:: --dry-run makes no changes" {
	run "${SCRIPT}" --dry-run
	[[ "${status}" -eq 0 ]]
	[[ ! -e "${RC_FILE}" ]]
	[[ ! -e "${BASH_RC}" ]]
	[[ ! -e "$(quest_log_plugin_dir)" ]]
	[[ ! -e "$(quest_log_rules_dir)" ]]
}

@test "integration:: --dry-run --uninstall makes no changes" {
	if ! "${SCRIPT}" >/dev/null; then
		return 1
	fi

	run "${SCRIPT}" --dry-run --uninstall
	[[ "${status}" -eq 0 ]]
	grep -Fq "zangarmarsh.sh" "${RC_FILE}"
	grep -Fq "zangarmarsh.sh" "${BASH_RC}"
	[[ -e "$(quest_log_plugin_dir)" ]]
	[[ -f "$(quest_log_rules_dir)/zangarmarsh-always.mdc" ]]
}

@test "integration:: leaves the plugin and rules in place when rc install fails" {
	mkdir -p "${RC_FILE}"

	run main --zsh
	[[ "${status}" -eq 1 ]]
	[[ -f "$(quest_log_plugin_dir)/.cursor-plugin/plugin.json" ]]
	[[ -f "$(quest_log_rules_dir)/zangarmarsh-always.mdc" ]]
}

@test "main:: returns nonzero when plugin install fails" {
	# Stub the plugin install so main reports a forced failure
	#
	# Side Effects:
	# - Writes a forced failure message to stderr
	#
	# Returns:
	# - 1 always
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

	# Stub the plugin uninstall so main reports a forced failure
	#
	# Side Effects:
	# - Writes a forced failure message to stderr
	#
	# Returns:
	# - 1 always
	uninstall_quest_plugin() {
		printf 'uninstall_quest_plugin:: forced failure\n' >&2

		return 1
	}

	run main --uninstall
	[[ "${status}" -eq 1 ]]
	grep -q "forced failure" <<<"${output}"
	matched=0
	grep -Fq "zangarmarsh.sh" "${RC_FILE}" && matched=1
	[[ "${matched}" -eq 0 ]]
}
