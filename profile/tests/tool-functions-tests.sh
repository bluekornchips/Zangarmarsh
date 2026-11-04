#!/usr/bin/env bats
#
# Unit and integration tests for tool functions after sourcing zangarmarsh.sh
#

setup_file() {
	GIT_ROOT="$(git rev-parse --show-toplevel)" || return 1
	source "${GIT_ROOT}/tests/fixtures.sh" || return 1

	SCRIPT="${ZANGARMARSH_ROOT}/zangarmarsh.sh"
	export SCRIPT

	return 0
}

setup() {
	return 0
}

@test "tool_functions:: questlog is a function after bash source" {
	run bash --noprofile --norc -c "source '${SCRIPT}' && type questlog"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "questlog is a function"
}

@test "tool_functions:: trilliax is a function after bash source" {
	run bash --noprofile --norc -c "source '${SCRIPT}' && type trilliax"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "trilliax is a function"
}

@test "tool_functions:: auras is a function after bash source" {
	run bash --noprofile --norc -c "source '${SCRIPT}' && type auras"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "auras is a function"
}

@test "tool_functions:: bash source exports PLATFORM_OS" {
	run bash --noprofile --norc -c "source '${SCRIPT}' && printf 'PLATFORM_OS=%s\n' \"\${PLATFORM_OS}\""
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -Eq '^PLATFORM_OS=(macos|linux)$'
}

@test "drun:: is a function and not an alias after bash source" {
	run bash --noprofile --norc -c "
		source '${SCRIPT}' || exit 1
		type drun
		alias drun 2>/dev/null && exit 2
		exit 0
	"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "drun is a function"
}

@test "drun:: passes the image before bash" {
	local mock_bin
	mock_bin="$(mktemp -d "${BATS_TEST_TMPDIR}/drun-bin.XXXXXX")"
	cat >"${mock_bin}/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@"
EOF
	chmod +x "${mock_bin}/docker"

	run env PATH="${mock_bin}:${PATH}" bash --noprofile --norc -c "
		source '${SCRIPT}' || exit 1
		drun alpine:latest -c 'echo hi'
	"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -Fq -- '-it'
	echo "${output}" | grep -Fq -- '--rm'
	echo "${output}" | grep -Fq -- '--entrypoint'
	echo "${output}" | grep -Fq -- '/usr/bin/env'
	echo "${output}" | grep -Fq -- 'alpine:latest'
	# Image must come before the bash entry command.
	local prev=""
	local line=""
	local image_before_bash=0
	while IFS= read -r line; do
		if [[ "${prev}" == "alpine:latest" && "${line}" == "bash" ]]; then
			image_before_bash=1
			break
		fi
		prev="${line}"
	done <<<"${output}"
	[[ "${image_before_bash}" -eq 1 ]]
}

@test "drun:: requires an image argument" {
	run bash --noprofile --norc -c "source '${SCRIPT}' && drun"
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "drun:: image is required"
}

@test "tool_functions:: questlog --help works after bash and zsh source" {
	run bash --noprofile --norc -c "source '${SCRIPT}' && questlog --help"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "Install the quest-log Cursor plugin"

	command -v zsh >/dev/null 2>&1 || skip "zsh not available"

	run zsh -c "source '${SCRIPT}' && questlog --help"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -q "Install the quest-log Cursor plugin"
}

@test "_zangarmarsh_tool:: fails when ZANGARMARSH_ROOT is unset" {
	run bash --noprofile --norc -c "
		source '${SCRIPT}' || exit 1
		unset ZANGARMARSH_ROOT
		_zangarmarsh_tool tools/quest-log/quest-log.sh
	"
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "_zangarmarsh_tool:: ZANGARMARSH_ROOT is required"
}

@test "_zangarmarsh_tool:: fails when tool path is empty" {
	run bash --noprofile --norc -c "
		source '${SCRIPT}' || exit 1
		_zangarmarsh_tool
	"
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "_zangarmarsh_tool:: tool path is required"
}

@test "_zangarmarsh_tool:: fails when script is missing" {
	run bash --noprofile --norc -c "
		source '${SCRIPT}' || exit 1
		_zangarmarsh_tool tools/does-not-exist/missing.sh
	"
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "_zangarmarsh_tool:: tool not found or not executable"
}

@test "tfp:: writes plan under .terraform and fails without it" {
	local work
	work="$(mktemp -d "${BATS_TEST_TMPDIR}/tfp-work.XXXXXX")"
	local mock_bin
	mock_bin="$(mktemp -d "${BATS_TEST_TMPDIR}/tfp-bin.XXXXXX")"
	cat >"${mock_bin}/terraform" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@"
EOF
	chmod +x "${mock_bin}/terraform"

	run env PATH="${mock_bin}:${PATH}" bash --noprofile --norc -c "
		source '${SCRIPT}' || exit 1
		cd '${work}' || exit 1
		tfp
	"
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "tfp:: .terraform not found"

	mkdir -p "${work}/.terraform"
	run env PATH="${mock_bin}:${PATH}" bash --noprofile --norc -c "
		source '${SCRIPT}' || exit 1
		cd '${work}' || exit 1
		tfp
	"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -Fq -- 'plan'
	echo "${output}" | grep -Fq -- '-out'
	echo "${output}" | grep -Fq -- '.terraform/zangarmarsh.tfplan'
}

@test "tfa:: fails when plan file is absent" {
	local work
	work="$(mktemp -d "${BATS_TEST_TMPDIR}/tfa-work.XXXXXX")"
	mkdir -p "${work}/.terraform"
	local mock_bin
	mock_bin="$(mktemp -d "${BATS_TEST_TMPDIR}/tfa-bin.XXXXXX")"
	cat >"${mock_bin}/terraform" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@"
EOF
	chmod +x "${mock_bin}/terraform"

	run env PATH="${mock_bin}:${PATH}" bash --noprofile --norc -c "
		source '${SCRIPT}' || exit 1
		cd '${work}' || exit 1
		tfa
	"
	[[ "${status}" -eq 1 ]]
	echo "${output}" | grep -q "tfa:: plan not found"
}

@test "tfa:: applies .terraform/zangarmarsh.tfplan when present" {
	local work
	work="$(mktemp -d "${BATS_TEST_TMPDIR}/tfa-apply.XXXXXX")"
	mkdir -p "${work}/.terraform"
	: >"${work}/.terraform/zangarmarsh.tfplan"
	local mock_bin
	mock_bin="$(mktemp -d "${BATS_TEST_TMPDIR}/tfa-apply-bin.XXXXXX")"
	cat >"${mock_bin}/terraform" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@"
EOF
	chmod +x "${mock_bin}/terraform"

	run env PATH="${mock_bin}:${PATH}" bash --noprofile --norc -c "
		source '${SCRIPT}' || exit 1
		cd '${work}' || exit 1
		tfa
	"
	[[ "${status}" -eq 0 ]]
	echo "${output}" | grep -Fq -- 'apply'
	echo "${output}" | grep -Fq -- '.terraform/zangarmarsh.tfplan'
}
