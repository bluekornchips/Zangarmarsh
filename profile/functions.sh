#!/usr/bin/env bash

# Load NVM from ${HOME}/.nvm.
#
# Inputs:
# - None
#
# Side Effects:
# - Sets and exports NVM_DIR to ${HOME}/.nvm, sources nvm.sh and optional bash_completion
#
# Returns:
# - 0 on success
# - 1 if NVM script not found or source fails
_nvm_load() {
	NVM_DIR="${HOME}/.nvm"
	export NVM_DIR
	local nvm_script="${NVM_DIR}/nvm.sh"

	if [[ ! -s "${nvm_script}" ]]; then
		echo "_nvm_load:: NVM not found at ${nvm_script}" >&2
		echo "_nvm_load:: Install NVM from: https://github.com/nvm-sh/nvm" >&2
		return 1
	fi

	if ! source "${nvm_script}" 2>/dev/null; then
		echo "_nvm_load:: Failed to source NVM script" >&2
		return 1
	fi

	if [[ -s "${NVM_DIR}/bash_completion" ]]; then
		\. "${NVM_DIR}/bash_completion" 2>/dev/null || true
	fi

	return 0
}

# Install Python dependencies from pyproject.toml
#
# Inputs:
# - None (reads from current directory)
#
# Side Effects:
# - Requires uv when pyproject.toml is present
# - Runs uv sync when pyproject.toml is present
#
# Returns:
# - 0 if dependencies installed or no pyproject.toml found
# - 1 if installation fails
_penv_install_dependencies() {
	if [[ ! -f "pyproject.toml" ]]; then
		echo "_penv_install_dependencies:: No pyproject.toml found"
		return 0
	fi

	if ! command -v uv >/dev/null 2>&1; then
		echo "_penv_install_dependencies:: uv is required for pyproject.toml" >&2
		return 1
	fi

	echo "Found pyproject.toml. Installing with uv."
	if [[ -f "uv.lock" ]]; then
		if uv sync --active --locked; then
			return 0
		fi
	elif uv sync --active; then
		return 0
	fi

	echo "_penv_install_dependencies:: Dependency installation failed" >&2

	return 1
}

# Refuse to source a missing or symlinked activate script
#
# Inputs:
# - $1 activate_path, path to the venv activate script
# - $2 caller_name, prefix for error messages
#
# Returns:
# - 0 when activate_path is a regular file
# - 1 when the path is a symlink or not a regular file
_penv_refuse_bad_activate() {
	local activate_path="$1"
	local caller_name="$2"

	if [[ -L "${activate_path}" || ! -f "${activate_path}" ]]; then
		echo "${caller_name}:: refusing to source ${activate_path}" >&2
		return 1
	fi

	return 0
}

# Create a .venv with the requested interpreter and activate it
#
# Inputs:
# - $1 python_version, interpreter command
# - $2 env_name, virtualenv directory name
#
# Side Effects:
# - Creates env_name and sources its activate script
#
# Returns:
# - 0 on success
# - 1 when venv creation or activation fails
_penv_create_and_activate() {
	local python_version="$1"
	local env_name="$2"

	echo "Creating virtual environment with ${python_version}: ${env_name}"
	if ! "${python_version}" -m venv "${env_name}" 2>/dev/null; then
		cat <<EOF >&2
_penv_create_and_activate:: Failed to create virtual environment
_penv_create_and_activate:: Make sure ${python_version} has venv module installed
_penv_create_and_activate:: Install Python with a working venv module, then retry
EOF
		return 1
	fi

	_penv_refuse_bad_activate "${env_name}/bin/activate" "_penv_create_and_activate" || return 1

	if ! source "${env_name}/bin/activate" >/dev/null 2>&1; then
		echo "_penv_create_and_activate:: Failed to activate virtual environment" >&2
		return 1
	fi

	return 0
}

# Print a macOS-specific install hint when the host is macOS
#
# Reads environment:
# - PLATFORM_OS, set by apply_platform_env in zangarmarsh.sh
#
# Side Effects:
# - Writes a python.org hint to stderr on macOS
#
# Returns:
# - 0 always
_penv_macos_hint() {
	if [[ "${PLATFORM_OS:-}" == "macos" ]]; then
		echo "penv:: Try installing Python from https://www.python.org/downloads/" >&2
	fi

	return 0
}

# Run git worktree from the git root
#
# Encapsulates git worktree so it always runs relative to the repository root,
# regardless of the current working directory. When the first argument is not
# add or remove, creates a sibling worktree with a branch of the same name.
#
# Inputs:
# - $1: required new branch and folder name, or add or remove
# - $2: optional base branch for shortcut creation
# - $@: arguments passed to git worktree when using add or remove
#
# Side Effects:
# - Invokes git worktree in the repository root
# - Creates a sibling worktree when using the shortcut form
#
# Returns:
# - 0 on success
# - 1 if not in a git repository or git worktree fails
gw() {
	local git_root
	git_root="$(git rev-parse --show-toplevel 2>/dev/null)"
	if [[ -z "${git_root}" ]]; then
		echo "gw:: not in a git repository" >&2
		return 1
	fi

	case "${1:-}" in
	add | remove)
		git -C "${git_root}" worktree "$@"
		return $?
		;;
	esac

	if [[ -z "${1:-}" ]]; then
		echo "gw:: name is required unless using add or remove" >&2
		return 1
	fi

	if (($# > 2)); then
		echo "gw:: shortcut accepts at most two arguments: name and base branch" >&2
		return 1
	fi

	local worktree_name="${1}"
	local base_branch="${2:-}"

	if [[ "${worktree_name}" == -* || "${worktree_name}" == *"/"* || "${worktree_name}" == *".."* ]]; then
		echo "gw:: name must not contain a slash or .., and must not start with a dash" >&2
		return 1
	fi

	if [[ -z "${base_branch}" ]]; then
		base_branch="$(git -C "${git_root}" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"
	fi

	if [[ -z "${base_branch}" ]]; then
		base_branch="$(git -C "${git_root}" symbolic-ref --quiet --short HEAD 2>/dev/null)"
	fi

	if [[ -z "${base_branch}" ]]; then
		echo "gw:: unable to determine default base branch" >&2
		return 1
	fi

	local worktree_path="${git_root}/../${worktree_name}"

	git -C "${git_root}" worktree add -b "${worktree_name}" "${worktree_path}" "${base_branch}"

	return $?
}

# Create a Python virtual environment in the current directory
#
# Inputs:
# - [-d|--delete]: force recreate the environment
# - [python_version]: Python interpreter to use (default: python3)
#
# Side Effects:
# - Creates and activates .venv when creating or recreating
# - Replaces .venv when -d is passed or .venv/bin/python is missing
# - Restores the previous .venv if creating the new one fails
# - Installs dependencies from pyproject.toml with uv when creating or recreating .venv
# - Leaves an existing usable .venv alone when -d is absent; does not source activate
#
# Returns:
# - 0 on success
# - 1 on failure (bad args, missing Python, venv creation/activation failure)
penv() {
	local python_version="python3"
	local force_recreate=false
	while (($# > 0)); do
		case "$1" in
		-d | --delete)
			force_recreate=true
			shift
			;;
		-h | --help)
			cat <<EOF
Usage: penv [-d] [python_version]
Options:
	-d, --delete    Force recreate environment
	-h, --help      Show this help
Examples:
	penv                 # Create and activate .venv with default Python
	penv python3.11     # Use specific Python version
	penv -d              # Force recreate
EOF
			return 0
			;;
		python[0-9]*)
			if [[ ! "$1" =~ ^python[0-9]+([.][0-9]+)*$ ]]; then
				echo "penv:: Unknown option '${1}'" >&2
				echo "penv:: Use 'penv --help' for usage information" >&2
				return 1
			fi

			python_version="${1}"
			shift
			;;
		*)
			echo "penv:: Unknown option '${1}'" >&2
			echo "penv:: Use 'penv --help' for usage information" >&2
			return 1
			;;
		esac
	done

	if ! command -v "${python_version}" >/dev/null 2>&1; then
		echo "penv:: ${python_version} not found" >&2
		echo "penv:: Available Python versions:" >&2
		local python_count=0
		local python_candidate
		# Zsh treats unmatched globs as errors; limit that to this scope.
		if [[ -n "${ZSH_VERSION:-}" ]]; then
			setopt local_options null_glob
		fi

		for python_candidate in /usr/bin/python* /usr/local/bin/python* /opt/homebrew/bin/python*; do
			if [[ -e "${python_candidate}" && -x "${python_candidate}" ]]; then
				echo "${python_candidate}" >&2
				python_count=$((python_count + 1))
				((python_count >= 5)) && break
			fi
		done

		((python_count == 0)) && echo "penv:: No Python versions found in common paths" >&2
		_penv_macos_hint
		return 1
	fi

	echo "Using Python: ${python_version} ($(command -v "${python_version}"))"
	echo "Version: $("${python_version}" --version 2>/dev/null || echo "Version info unavailable")"

	local env_name=".venv"
	if [[ -d "${env_name}" && "${force_recreate}" != true && -x "${env_name}/bin/python" ]]; then
		echo "Virtual environment already exists: ${env_name}"
		return 0
	fi

	# The live environment stays under a unique name until its replacement exists.
	local old_env=""
	if [[ -e "${env_name}" ]]; then
		echo "Replacing existing virtual environment: ${env_name}"
		old_env="$(mktemp -u "${env_name}.old.XXXXXX")"
		mv "${env_name}" "${old_env}" || {
			echo "penv:: Failed to move existing environment" >&2
			return 1
		}
	fi

	if ! _penv_create_and_activate "${python_version}" "${env_name}"; then
		rm -rf "${env_name}"
		if [[ -n "${old_env}" ]] && ! mv "${old_env}" "${env_name}"; then
			echo "penv:: Previous environment kept at ${old_env}" >&2
		fi

		return 1
	fi

	if [[ -n "${old_env}" ]]; then
		rm -rf "${old_env}"
	fi

	_penv_install_dependencies || return 1

	cat <<EOF

========================================
Virtual environment setup complete!
Python version: $(python --version 2>/dev/null || echo "Version info unavailable")
Environment: ${PWD}/${env_name}
========================================

EOF

	return 0
}

# Run an interactive Docker container with bash as the entry command
#
# Inputs:
# - $1 image, Docker image name
# - $@ remaining args passed to bash inside the container
#
# Side Effects:
# - Invokes docker run when docker is available
#
# Returns:
# - Docker exit status
# - 1 when the image argument is missing or docker is unavailable
drun() {
	local image="${1:-}"

	if [[ -z "${image}" ]]; then
		echo "drun:: image is required" >&2
		echo "drun:: usage: drun IMAGE [bash args...]" >&2
		return 1
	fi

	if ! command -v docker >/dev/null 2>&1; then
		echo "drun:: docker is not installed" >&2
		return 1
	fi

	shift
	docker run -it --rm --entrypoint /usr/bin/env "${image}" bash "$@"

	return $?
}

# Run terraform plan and write .terraform/zangarmarsh.tfplan
#
# Inputs:
# - $@ forwarded to terraform plan
#
# Side Effects:
# - Writes .terraform/zangarmarsh.tfplan when terraform plan succeeds
#
# Returns:
# - Terraform exit status
# - 1 when terraform is missing or .terraform is not present
tfp() {
	local plan_path=".terraform/zangarmarsh.tfplan"

	if ! command -v terraform >/dev/null 2>&1; then
		echo "tfp:: terraform is not installed" >&2
		return 1
	fi

	if [[ ! -d ".terraform" ]]; then
		echo "tfp:: .terraform not found, run tfi first" >&2
		return 1
	fi

	terraform plan -out "${plan_path}" "$@"

	return $?
}

# Apply a terraform plan file, such as the one tfp writes
#
# Inputs:
# - $1 plan_path, plan file to apply
# - $@ after plan_path forwarded to terraform apply
#
# Returns:
# - Terraform exit status
# - 1 when the plan path is missing, terraform is missing, or the plan file is absent
tfa() {
	local plan_path="${1:-}"

	if [[ -z "${plan_path}" ]]; then
		echo "tfa:: plan path is required" >&2
		echo "tfa:: usage: tfa PLAN_PATH [terraform apply args...]" >&2
		return 1
	fi

	if ! command -v terraform >/dev/null 2>&1; then
		echo "tfa:: terraform is not installed" >&2
		return 1
	fi

	if [[ ! -f "${plan_path}" ]]; then
		echo "tfa:: plan not found: ${plan_path}, run tfp first" >&2
		return 1
	fi

	shift
	terraform apply "${plan_path}" "$@"

	return $?
}

if [[ "${ZANGARMARSH_LAZY_LOADING:-true}" == "true" ]] && [[ "${ZANGARMARSH_ENABLE_NVM:-true}" == "true" ]]; then
	# Lazy NVM shim that loads the real nvm on first call
	#
	# Inputs:
	# - $@ forwarded to the real nvm after load
	#
	# Side Effects:
	# - Unsets this shim and sources NVM via _nvm_load
	#
	# Returns:
	# - nvm exit status after load
	# - 1 when nvm is unavailable after load
	nvm() {
		unset -f nvm
		_nvm_load
		if command -v nvm >/dev/null 2>&1; then
			nvm "$@"
		else
			echo "nvm:: NVM command not available after loading" >&2
			return 1
		fi
	}
elif [[ "${ZANGARMARSH_ENABLE_NVM:-true}" == "true" ]]; then
	_nvm_load
fi
