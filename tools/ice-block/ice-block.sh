#!/usr/bin/env bash
#
# ice_block.sh
#
# Copies a predefined list of files and directories to a target directory.
# Uses cp -a (archive mode) which preserves permissions, timestamps, and symlinks.
#

# Configuration
# Get hostname for target directory
HOSTNAME_VALUE="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo "default")"
TARGET_DIR="${HOME}/.ice-block/${HOSTNAME_VALUE}"
TARGET_DIR="${TARGET_DIR%/}"

SOURCES=(
	"${HOME}/.aliases"
	"${HOME}/.bashrc"
	"${HOME}/.zshrc"
	"${HOME}/.zsh_history"
	"${HOME}/.gitconfig"
	"${HOME}/.ssh"
)

# Ensure the target directory exists
#
# Side Effects:
# - Creates TARGET_DIR if it does not exist
#
# Returns:
# - 0 on success
# - 1 on failure
ensure_target_dir() {
	if [[ ! -d "${TARGET_DIR}" ]]; then
		echo "Creating target directory: ${TARGET_DIR}"
		if ! mkdir -p "${TARGET_DIR}"; then
			echo "ensure_target_dir:: Failed to create ${TARGET_DIR}" >&2
			return 1
		fi
	fi

	return 0
}

# Copy a source file or directory to the target directory
#
# Inputs:
# - $1: Source path to copy
#
# Side Effects:
# - Copies files or directories to TARGET_DIR
#
# Returns:
# - 0 on success
# - 1 on failure
copy_source() {
	local src
	local dest
	local resolved_src

	src="$1"

	if [[ -z "${src}" ]]; then
		echo "copy_source:: Source path is required" >&2
		return 1
	fi

	resolved_src="${src/#\~/${HOME}}"
	resolved_src="$(realpath -m "${resolved_src}")"

	if [[ ! -e "${resolved_src}" ]]; then
		echo "Skipping missing path: ${resolved_src}"
		return 0
	fi

	dest="${TARGET_DIR}/$(basename "${resolved_src}")"
	echo "Copying ${resolved_src} -> ${dest}"

	# Use -a to preserve permissions, timestamps, and symlinks.
	# Use -f to force overwrite by unlinking destination if it's not writable.
	# Use -T to treat the destination as a file/directory itself, avoiding nesting.
	if ! cp -afT "${resolved_src}" "${dest}"; then
		echo "copy_source:: Failed to copy ${resolved_src} to ${dest}" >&2
		return 1
	fi

	return 0
}

# Main entry point
main() {
	local src

	if ! ensure_target_dir; then
		return 1
	fi

	for src in "${SOURCES[@]}"; do
		if ! copy_source "${src}"; then
			echo "main:: Failed to copy source: ${src}" >&2
			return 1
		fi
	done

	echo "All done! Backup is in ${TARGET_DIR}"

	return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	set -eo pipefail
	umask 077

	main "$@"
	exit $?
fi
