#!/bin/bash
# session-init.sh - Initialize Nushell development session
#
# This hook runs at session start to:
# - Detect Nushell version
# - Check for required tools
# - Set up environment

set -euo pipefail

# Build system message
message=""

# Check for Nushell
if command -v nu &> /dev/null; then
    nu_version=$(nu --version 2>/dev/null || echo "unknown")
    message+="Nushell v$nu_version detected. "
else
    message+="⚠️ Nushell not found in PATH. "
fi

# Check for nu-check (linting)
if command -v nu-check &> /dev/null; then
    message+="nu-check available. "
fi

# Check for nu-lint
if command -v nu-lint &> /dev/null; then
    message+="nu-lint available. "
fi

# Check for polars plugin
if nu --commands 'plugin list | where name == "polars" | length' 2>/dev/null | grep -q "1"; then
    message+="Polars plugin loaded. "
fi

# Output session context
cat << EOF
{
  "systemMessage": "Nushell Development Environment: $message",
  "continue": true
}
EOF

exit 0
