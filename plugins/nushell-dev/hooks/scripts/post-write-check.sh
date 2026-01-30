#!/bin/bash
# post-write-check.sh - Validate .nu files after write/edit operations
#
# This hook runs after Write/Edit tool use to check Nushell file quality.
# It validates syntax and provides feedback for any issues found.

set -euo pipefail

# Read hook input from stdin
input=$(cat)

# Extract tool result and file path
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
tool_input=$(echo "$input" | jq -r '.tool_input // {}')
file_path=$(echo "$tool_input" | jq -r '.file_path // ""')

# Only process .nu files
if [[ ! "$file_path" =~ \.nu$ ]]; then
    # Not a Nushell file, exit silently
    exit 0
fi

# Check if file exists (it should after write)
if [[ ! -f "$file_path" ]]; then
    exit 0
fi

# Run syntax check
check_output=""
check_status=0

# Use nu --commands source for syntax validation
if command -v nu &> /dev/null; then
    check_output=$(nu --commands "source '$file_path'" 2>&1) || check_status=$?
fi

# If syntax check failed, provide feedback
if [[ $check_status -ne 0 ]]; then
    # Output message for Claude (exit code 2 means feedback to Claude)
    cat << EOF >&2
{
  "systemMessage": "Nushell syntax validation found issues in $file_path:\n\n$check_output\n\nPlease fix these issues before proceeding."
}
EOF
    exit 2
fi

# Check passed - provide success feedback (optional, for verbose mode)
if [[ -n "${VERBOSE:-}" ]]; then
    echo "{\"systemMessage\": \"✅ Nushell syntax validation passed for $file_path\"}"
fi

exit 0
