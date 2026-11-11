#!/usr/bin/env bash
#
# Atomic file writes, symlink updates, and owned-path checks
#

# Create a directory when DRY_RUN is not true
#
# Inputs:
# - $1 dir_path, directory to create
# - $2 label, prefix for error messages
#
# Reads environment:
# - DRY_RUN, when true skip creation and return 0
#
# Returns:
# - 0 on success or dry-run
# - 1 when mkdir fails
ensure_dir() {
	local dir_path="$1"
	local label="${2:-ensure_dir}"

	[[ "${DRY_RUN:-false}" == "true" ]] && return 0

	if [[ ! -d "${dir_path}" ]] && ! mkdir -p "${dir_path}"; then
		echo "${label}:: Failed to create directory: ${dir_path}" >&2
		return 1
	fi

	return 0
}

# Write content from a source file or stdin over dest when contents differ
#
# Inputs:
# - $1 dest, destination path
# - $2 source, optional source file; when empty, read content from stdin
# - $3 label, prefix for error messages
#
# Reads environment:
# - DRY_RUN, when true report without writing
#
# Side Effects:
# - Sets WRITE_ATOMIC_OUTCOME to unchanged, created, updated, or dry-run
# - Replaces dest via a same-directory temp file and mv -f when content differs
#
# Returns:
# - 0 on success, including dry-run and unchanged
# - 1 when the parent cannot be prepared or the write fails
write_atomic() {
	local dest="$1"
	local source="${2:-}"
	local label="${3:-write_atomic}"

	WRITE_ATOMIC_OUTCOME="error"

	local parent
	parent="$(dirname "${dest}")"

	local display_path="${dest}"
	local display_dir
	if display_dir="$(cd "${parent}" 2>/dev/null && pwd -P)"; then
		display_path="${display_dir}/$(basename "${dest}")"
	fi

	if [[ "${DRY_RUN:-false}" == "true" ]]; then
		echo "Would write: ${display_path}"
		WRITE_ATOMIC_OUTCOME="dry-run"
		return 0
	fi

	ensure_dir "${parent}" "${label}" || return 1

	local temp
	temp="$(mktemp "${parent}/.zangarmarsh.XXXXXX")" || {
		echo "${label}:: Failed to create temporary file for ${display_path}" >&2
		return 1
	}

	if ! chmod 0600 "${temp}"; then
		rm -f -- "${temp}"
		echo "${label}:: Failed to harden temporary file for ${display_path}" >&2
		return 1
	fi

	if [[ -n "${source}" ]]; then
		if ! cp "${source}" "${temp}"; then
			rm -f -- "${temp}"
			echo "${label}:: Failed to stage ${source} for ${display_path}" >&2
			return 1
		fi
	else
		if ! cat >"${temp}"; then
			rm -f -- "${temp}"
			echo "${label}:: Failed to stage content for ${display_path}" >&2
			return 1
		fi
	fi

	if [[ -f "${dest}" ]] && cmp -s "${temp}" "${dest}"; then
		rm -f -- "${temp}"
		echo "No changes: ${display_path}"
		WRITE_ATOMIC_OUTCOME="unchanged"
		return 0
	fi

	if [[ -f "${dest}" ]]; then
		local mode
		mode="$(stat -c '%a' "${dest}" 2>/dev/null || stat -f '%OLp' "${dest}" 2>/dev/null || true)"
		if [[ -n "${mode}" ]]; then
			chmod "${mode}" "${temp}" 2>/dev/null || true
		fi
	elif [[ -n "${source}" && -f "${source}" ]]; then
		local mode
		mode="$(stat -c '%a' "${source}" 2>/dev/null || stat -f '%OLp' "${source}" 2>/dev/null || true)"
		if [[ -n "${mode}" ]]; then
			chmod "${mode}" "${temp}" 2>/dev/null || true
		fi
	fi

	local existed=0
	[[ -e "${dest}" || -L "${dest}" ]] && existed=1

	if ! mv -f "${temp}" "${dest}"; then
		rm -f -- "${temp}"
		echo "${label}:: Failed to write ${display_path}" >&2
		return 1
	fi

	if [[ "${existed}" -eq 1 ]]; then
		echo "Updated: ${display_path}"
		WRITE_ATOMIC_OUTCOME="updated"
	else
		echo "Created: ${display_path}"
		WRITE_ATOMIC_OUTCOME="created"
	fi

	return 0
}

# Create or replace a symlink with ln -sfn
#
# Inputs:
# - $1 link_path, symlink path to create
# - $2 target, symlink target
# - $3 label, prefix for error messages
#
# Reads environment:
# - DRY_RUN, when true report without linking
#
# Returns:
# - 0 on success or dry-run
# - 1 when the parent cannot be prepared or ln fails
link_atomic() {
	local link_path="$1"
	local target="$2"
	local label="${3:-link_atomic}"

	local parent
	parent="$(dirname "${link_path}")"

	if [[ "${DRY_RUN:-false}" == "true" ]]; then
		echo "Would link: ${link_path} -> ${target}"
		return 0
	fi

	ensure_dir "${parent}" "${label}" || return 1

	if [[ -L "${link_path}" ]]; then
		local current
		current="$(readlink "${link_path}" 2>/dev/null || true)"
		if [[ "${current}" == "${target}" ]]; then
			echo "No changes: ${link_path}"
			return 0
		fi
	fi

	if ! ln -sfn "${target}" "${link_path}"; then
		echo "${label}:: Failed to link ${link_path} -> ${target}" >&2
		return 1
	fi

	echo "Linked: ${link_path} -> ${target}"

	return 0
}

# Validate that a path is an absolute child of an allowed root
#
# Inputs:
# - $1 path, absolute path to check
# - $2 allowed_root, absolute directory the path must equal or sit under
# - $3 label, prefix for error messages
#
# Reads environment:
# - HOME, required when walking for symlink components
#
# Returns:
# - 0 when the path is absolute, has no traversal, no trailing slash, no symlink
#   component below HOME, and sits under allowed_root
# - 1 otherwise
owned_path() {
	local path="$1"
	local allowed_root="$2"
	local label="${3:-owned_path}"

	if [[ -z "${HOME:-}" ]]; then
		echo "${label}:: HOME is required" >&2
		return 1
	fi

	if [[ -z "${path}" || "${path}" != /* ]]; then
		echo "${label}:: absolute path is required" >&2
		return 1
	fi

	if [[ -z "${allowed_root}" || "${allowed_root}" != /* ]]; then
		echo "${label}:: absolute allowed root is required" >&2
		return 1
	fi

	if [[ "${path}" == */ ]]; then
		echo "${label}:: trailing slash is not allowed" >&2
		return 1
	fi

	case "${path}" in
	*"/../"* | *"/./"* | */.. | */.)
		echo "${label}:: path traversal is not allowed" >&2
		return 1
		;;
	esac

	case "${path}" in
	"${allowed_root}" | "${allowed_root}"/*) ;;
	*)
		echo "${label}:: path must be under ${allowed_root}" >&2
		return 1
		;;
	esac

	if [[ "${path}" != "${HOME}" && "${path}" != "${HOME}/"* ]]; then
		echo "${label}:: path must be below ${HOME}" >&2
		return 1
	fi

	local base="${HOME}"
	if [[ -d "${base}" || -L "${base}" ]]; then
		base="$(cd "${base}" && pwd -P)" || {
			echo "${label}:: cannot resolve HOME" >&2
			return 1
		}
	fi

	local rest="${path#"${HOME}"}"
	rest="${rest#/}"
	local cursor="${base}"
	local remaining="${rest}"
	local component

	while [[ -n "${remaining}" ]]; do
		component="${remaining%%/*}"
		if [[ "${remaining}" == */* ]]; then
			remaining="${remaining#*/}"
		else
			remaining=""
		fi

		if [[ -z "${component}" || "${component}" == "." || "${component}" == ".." ]]; then
			echo "${label}:: path traversal is not allowed" >&2
			return 1
		fi

		cursor="${cursor}/${component}"
		if [[ -L "${cursor}" ]]; then
			echo "${label}:: refusing symlink: ${cursor}" >&2
			return 1
		fi

		[[ -e "${cursor}" ]] || return 0
	done

	return 0
}
