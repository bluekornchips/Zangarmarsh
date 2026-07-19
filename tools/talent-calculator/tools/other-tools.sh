#!/usr/bin/env bash
#
# Other Tools Installation
# Installs development tools via curl, scripts, and pipx
#

# Install a tool using curl
#
# Inputs:
# - $1, tool_name, name of the tool being installed
# - $2, url, URL to download from
# - $3, output_file, optional filename to save as
#
# Side Effects:
# - Downloads file from URL
# - In dry-run mode, shows what would be downloaded
#
# Returns:
# - 0 on success
# - 1 on failure
install_with_curl() {
	local tool_name="$1"
	local url="$2"
	local output_file="${3:-}"

	if [[ -z "${tool_name}" ]]; then
		echo "install_with_curl:: tool_name is required" >&2
		return 1
	fi

	if [[ -z "${url}" ]]; then
		echo "install_with_curl:: url is required" >&2
		return 1
	fi

	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "install_with_curl:: Would download ${tool_name} from: ${url}"
		return 0
	fi

	echo "install_with_curl:: Downloading ${tool_name}"
	if [[ -n "${output_file}" ]]; then
		if ! curl -fsSL -o "${output_file}" "${url}"; then
			echo "install_with_curl:: Failed to download ${tool_name}" >&2
			return 1
		fi
	else
		if ! curl -fsSL "${url}"; then
			echo "install_with_curl:: Failed to download ${tool_name}" >&2
			return 1
		fi
	fi

	return 0
}

# Install aws-sso-util
#
# https://github.com/benkehoe/aws-sso-util#installation
#
# Side Effects:
# - Installs aws-sso-util via pipx when pipx is available
#
# Returns:
# - 0 on success
# - 1 on failure
install_aws_sso_util() {
	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "install_aws_sso_util:: Would install aws-sso-util with pipx"
		return 0
	fi

	if ! command -v pipx >/dev/null 2>&1; then
		echo "install_aws_sso_util:: pipx is required" >&2
		echo "install_aws_sso_util:: Install pipx with your OS package manager, then re-run" >&2
		return 1
	fi

	echo "install_aws_sso_util:: Installing aws-sso-util"
	pipx ensurepath
	pipx install aws-sso-util

	return 0
}

# Install Bun
#
# https://bun.sh/docs/installation
#
# Side Effects:
# - Downloads and runs Bun install script
#
# Returns:
# - 0 on success
# - 1 on failure
install_bun() {
	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "install_bun:: Would run Bun install script"
		return 0
	fi

	echo "install_bun:: Installing Bun"
	curl -fsSL https://bun.sh/install | bash

	return 0
}

# Install Helm
#
# https://helm.sh/docs/intro/install/
#
# Side Effects:
# - Downloads and runs Helm install script
#
# Returns:
# - 0 on success
# - 1 on failure
install_helm() {
	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "install_helm:: Would download and run Helm install script"
		return 0
	fi

	echo "install_helm:: Installing Helm"
	curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
	chmod 700 get_helm.sh
	./get_helm.sh
	rm -f get_helm.sh

	return 0
}

# Install all script-managed tools
#
# This function installs tools that ship with curl or pipx installers.
# Core and extra tools are checked separately by the parent script.
# It expects check_is_installed from the parent script.
#
# Returns:
# - 0 always
install_other_tools() {
	local other_tools=(
		"aws-sso-util:install_aws_sso_util"
		"bun:install_bun"
		"helm:install_helm"
	)
	local entry
	local tool_name
	local install_fn

	for entry in "${other_tools[@]}"; do
		tool_name="${entry%%:*}"
		install_fn="${entry#*:}"

		if [[ "${TALENT_MODE}" == "respec" ]]; then
			echo "install_other_tools:: Reset requested for ${tool_name}"
		fi

		if [[ "${TALENT_MODE}" != "respec" ]] && check_is_installed "${tool_name}"; then
			echo "install_other_tools:: ${tool_name} is already installed"
		else
			echo "install_other_tools:: Installing: ${tool_name}"
			if ! "${install_fn}"; then
				echo "install_other_tools:: Failed to install ${tool_name}" >&2
			fi
		fi
	done

	return 0
}
