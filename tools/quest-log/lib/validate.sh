#!/usr/bin/env bash
#
# Rule validation helpers for quest-log
#

# Validate rule content
#
# Inputs:
# - $1, name, the name of the rule
# - $2, file_content, the content of the rule file
# - $3, globs, optional array of glob patterns for file matching
# - $4, description, the description of the rule
# - $5, cursor_always_apply, whether the rule should always apply
#
# Returns:
# - 0 if validation passes
# - 1 if validation fails
# - Sets STATS_WARNINGS and STATS_ERRORS accordingly
validate_rule() {
	local name="$1"
	local file_content="$2"
	local globs="$3"
	local description="$4"
	local cursor_always_apply="$5"

	# Validate rule length (500 line limit per Cursor best practices)
	local validation_failed=false
	local line_count
	line_count=$(echo "${file_content}" | wc -l | tr -d ' ')
	if ((line_count > 500)); then
		echo "validate_rule:: Error: Rule '${name}' exceeds 500 lines (${line_count} lines)" >&2
		echo "validate_rule:: Suggestion: Split into multiple rules or use rule composition" >&2
		STATS_ERRORS=$((STATS_ERRORS + 1))
		validation_failed=true
	elif ((line_count > 400)); then
		echo "validate_rule:: Rule '${name}' is approaching the 500 line limit (${line_count} lines)" >&2
		echo "validate_rule:: Consider splitting into multiple rules" >&2
		STATS_WARNINGS=$((STATS_WARNINGS + 1))
	fi

	# Validate description is meaningful when using intelligent application
	if [[ "${cursor_always_apply}" == "false" ]]; then
		local glob_count
		glob_count=$(echo "${globs}" | jq 'length' 2>/dev/null || echo "0")
		if [[ "${glob_count}" == "0" ]]; then
			# Using intelligent application - description should be descriptive
			local desc_length
			desc_length=$(echo -n "${description}" | wc -c | tr -d ' ')
			if ((desc_length < 20)); then
				echo "validate_rule:: Rule '${name}' has a short description (${desc_length} chars) but uses intelligent application" >&2
				echo "validate_rule:: Suggestion: Provide a more descriptive description for better AI matching" >&2
				STATS_WARNINGS=$((STATS_WARNINGS + 1))
			fi
		fi
	fi

	# Validate glob patterns (basic syntax check)
	if [[ -n "${globs}" ]] && [[ "${globs}" != "[]" ]]; then
		local glob_array
		if ! glob_array=$(echo "${globs}" | jq -r '.[]' 2>/dev/null); then
			echo "validate_rule:: Error: Rule '${name}' has invalid globs JSON format" >&2
			STATS_ERRORS=$((STATS_ERRORS + 1))
			validation_failed=true
		else
			# Basic glob pattern validation
			while IFS= read -r glob_pattern; do
				if [[ -z "${glob_pattern}" ]]; then
					continue
				fi
				# Check for common glob pattern issues
				if [[ "${glob_pattern}" =~ ^[[:space:]]+ ]] || [[ "${glob_pattern}" =~ [[:space:]]+$ ]]; then
					echo "validate_rule:: Rule '${name}' has glob pattern with leading/trailing whitespace: '${glob_pattern}'" >&2
					STATS_WARNINGS=$((STATS_WARNINGS + 1))
				fi
			done <<<"${glob_array}"
		fi
	fi

	# Validate description is not empty
	if [[ -z "${description}" ]] || [[ "${description}" == "null" ]]; then
		echo "validate_rule:: Error: Rule '${name}' has empty description" >&2
		STATS_ERRORS=$((STATS_ERRORS + 1))
		validation_failed=true
	fi

	# Track total lines
	STATS_TOTAL_LINES=$((STATS_TOTAL_LINES + line_count))

	if [[ "${validation_failed}" == "true" ]]; then
		return 1
	fi

	return 0
}
