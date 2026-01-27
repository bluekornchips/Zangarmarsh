#!/usr/bin/env bash
#
# Other Tools Installation
# Installs development tools via non-brew methods (curl, scripts, etc.)
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

# Install Homebrew
#
# https://brew.sh/
#
# Side Effects:
# - Installs Homebrew
#
# Returns:
# - 0 on success
# - 1 on failure
install_brew() {
	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "install_brew:: Would install Homebrew"
		return 0
	fi

	echo "install_brew:: Installing Homebrew"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

	return 0
}

# Install aws-sso-util
#
# https://github.com/benkehoe/aws-sso-util#installation
#
# Side Effects:
# - Installs pipx and aws-sso-util
#
# Returns:
# - 0 on success
# - 1 on failure
install_aws_sso_util() {
	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "install_aws_sso_util:: Would install pipx and aws-sso-util"
		return 0
	fi

	echo "install_aws_sso_util:: Installing aws-sso-util"
	if ! install_with_brew "pipx"; then
		return 1
	fi

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

# Install Docker CLI and Colima container runtime
#
# https://github.com/abcxyz/colima
# https://docs.docker.com/engine/install/
#
# Colima provides a lightweight Docker runtime for macOS and Linux,
# replacing Docker Desktop. The Docker CLI connects to Colima's daemon.
# buildx is included with modern Docker CLI installations.
#
# Side Effects:
# - Installs docker CLI and colima via brew
# - Starts colima if not already running
#
# Returns:
# - 0 on success
# - 1 on failure
install_docker_colima() {
	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "install_docker_colima:: Would install docker and colima, then start colima"
		return 0
	fi

	echo "install_docker_colima:: Installing Docker CLI"
	if ! install_with_brew "docker"; then
		echo "install_docker_colima:: Failed to install docker" >&2
		return 1
	fi

	echo "install_docker_colima:: Installing Colima"
	if ! install_with_brew "colima"; then
		echo "install_docker_colima:: Failed to install colima" >&2
		return 1
	fi

	# Start colima if not already running
	if ! colima status >/dev/null 2>&1; then
		echo "install_docker_colima:: Starting Colima"
		if ! colima start; then
			echo "install_docker_colima:: Failed to start colima" >&2
			return 1
		fi
	else
		echo "install_docker_colima:: Colima is already running"
	fi

	return 0
}

# Install all other tools (non-brew)
#
# This function installs all tools that are not installed via Homebrew.
# Note: Core tools (brew, jq, bats-core, kubectl) are installed separately.
# It expects the helper functions (check_is_installed, uninstall_with_brew, etc.)
# to be available from the parent script.
#
# Returns:
# - 0 always
install_other_tools() {
	# https://github.com/benkehoe/aws-sso-util#installation
	if [[ "${TALENT_MODE}" == "respec" ]]; then
		echo "install_other_tools:: Reset requested for aws-sso-util"
		uninstall_with_brew "aws-sso-util"
	fi

	if check_is_installed "aws-sso-util"; then
		echo "install_other_tools:: aws-sso-util is already installed"
	else
		echo "install_other_tools:: Installing: aws-sso-util"
		if ! install_aws_sso_util; then
			echo "install_other_tools:: Failed to install aws-sso-util" >&2
		fi
	fi

	# https://bun.sh/docs/installation
	if [[ "${TALENT_MODE}" == "respec" ]]; then
		echo "install_other_tools:: Reset requested for bun"
		uninstall_with_brew "bun"
	fi

	if check_is_installed "bun"; then
		echo "install_other_tools:: bun is already installed"
	else
		echo "install_other_tools:: Installing: bun"
		if ! install_bun; then
			echo "install_other_tools:: Failed to install bun" >&2
		fi
	fi

	# https://helm.sh/docs/intro/install/
	if [[ "${TALENT_MODE}" == "respec" ]]; then
		echo "install_other_tools:: Reset requested for helm"
		uninstall_with_brew "helm"
	fi

	if check_is_installed "helm"; then
		echo "install_other_tools:: helm is already installed"
	else
		echo "install_other_tools:: Installing: helm"
		if ! install_helm; then
			echo "install_other_tools:: Failed to install helm" >&2
		fi
	fi

	# https://github.com/abcxyz/colima
	# https://docs.docker.com/engine/install/
	if [[ "${TALENT_MODE}" == "respec" ]]; then
		echo "install_other_tools:: Reset requested for docker/colima"
		uninstall_with_brew "docker"
		uninstall_with_brew "colima"
	fi

	if check_is_installed "docker" && colima status >/dev/null 2>&1; then
		echo "install_other_tools:: docker with colima is already installed and running"
	else
		echo "install_other_tools:: Installing: docker with colima"
		if ! install_docker_colima; then
			echo "install_other_tools:: Failed to install docker/colima" >&2
		fi
	fi

	return 0
}
