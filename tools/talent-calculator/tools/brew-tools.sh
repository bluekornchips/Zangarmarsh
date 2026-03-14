#!/usr/bin/env bash
#
# Brew Tools Installation
# Installs development tools via Homebrew
#

# Install a package using Homebrew
#
# Inputs:
# - $1, package_name, the package to install
# - $2+, args, additional arguments for brew install
#
# Side Effects:
# - Installs package via brew
# - In dry-run mode, shows what would be installed
#
# Returns:
# - 0 on success
# - 1 on failure
install_with_brew() {
	local package_name="$1"
	shift
	local args=("$@")

	if [[ -z "${package_name}" ]]; then
		echo "install_with_brew:: package_name is required" >&2
		return 1
	fi

	if [[ "${DRY_RUN}" == "true" ]]; then
		if [[ ${#args[@]} -gt 0 ]]; then
			echo "install_with_brew:: Would install: brew install ${package_name} ${args[*]}"
		else
			echo "install_with_brew:: Would install: brew install ${package_name}"
		fi
		return 0
	fi

	echo "install_with_brew:: Installing ${package_name}"
	local install_output
	install_output=$(brew install "${package_name}" "${args[@]}" 2>&1)
	local install_status=$?

	# Check if package was installed, consider it a partial success even if linking failed
	local package_installed=false
	if brew list "${package_name}" >/dev/null 2>&1; then
		package_installed=true
	fi

	# Check if linking failed, package installed but not linked
	# This can happen when there are symlink conflicts
	if echo "${install_output}" | grep -q "brew link.*did not complete successfully\|Could not symlink"; then
		echo "install_with_brew:: Link conflict detected, attempting to overwrite"
		if ! brew link --overwrite "${package_name}" 2>/dev/null; then
			echo "install_with_brew:: Failed to link ${package_name}, but package is installed" >&2
			if [[ "${package_installed}" == "true" ]]; then
				return 0
			fi
		else
			echo "install_with_brew:: Successfully linked ${package_name} with overwrite"
			return 0
		fi
	fi

	if [[ ${install_status} -ne 0 ]]; then
		echo "install_with_brew:: Failed to install ${package_name}" >&2
		return 1
	fi

	return 0
}

# Uninstall a package via brew for reset
#
# Inputs:
# - $1, package_name, package to uninstall
#
# Side Effects:
# - Removes package via brew uninstall
# - In dry-run mode, shows what would be uninstalled
#
# Returns:
# - 0 always, removal is best-effort
uninstall_with_brew() {
	local package_name="$1"

	if [[ -z "${package_name}" ]]; then
		return 0
	fi

	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "uninstall_with_brew:: Would uninstall ${package_name}"
		return 0
	fi

	echo "uninstall_with_brew:: Removing ${package_name}"
	brew uninstall "${package_name}" 2>/dev/null || true

	return 0
}

# Install a tool via brew with check and optional reset
#
# Inputs:
# - $1, cmd_name, command name to check
# - --package, package_name, brew package name, defaults to cmd_name
#
# Returns:
# - 0 always
install_brew_package() {
	local cmd_name=""
	local package_name=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--package)
			package_name="$2"
			shift 2
			;;
		*)
			if [[ -z "${cmd_name}" ]]; then
				cmd_name="$1"
			fi
			shift
			;;
		esac
	done

	if [[ -z "${cmd_name}" ]]; then
		echo "install_brew_package:: cmd_name is required" >&2
		return 0
	fi

	if [[ -z "${package_name}" ]]; then
		package_name="${cmd_name}"
	fi

	if [[ "${TALENT_MODE}" == "respec" ]]; then
		echo "install_brew_package:: Reset requested for ${cmd_name}"
		uninstall_with_brew "${package_name}"
	fi

	# Special case: tfenv conflicts with terraform symlink
	if [[ "${package_name}" == "tfenv" ]] && [[ "${DRY_RUN}" != "true" ]]; then
		if brew list "terraform" >/dev/null 2>&1; then
			echo "install_brew_package:: Unlinking conflicting terraform package"
			brew unlink "terraform" 2>/dev/null || true
		fi
	fi

	if check_is_installed "${cmd_name}"; then
		echo "install_brew_package:: ${cmd_name} is already installed"
		return 0
	fi

	echo "install_brew_package:: Installing: ${cmd_name}"
	if ! install_with_brew "${package_name}"; then
		echo "install_brew_package:: Failed to install ${cmd_name}" >&2
	fi

	return 0
}
