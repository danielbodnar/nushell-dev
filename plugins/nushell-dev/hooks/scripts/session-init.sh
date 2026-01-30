#!/bin/bash
# session-init.sh - Initialize Nushell development session
#
# This hook runs at session start to:
# - Detect Nushell version and available validation tools
# - Check for required tools (nu-lint, nufmt, etc.)
# - Set up environment variables
# - Report tool availability status

set -euo pipefail

# Colors for output (used in report)
GREEN="✓"
RED="✗"

# ============================================================================
# Tool Detection Functions
# ============================================================================

# Get Nushell version
get_nu_version() {
    if command -v nu &> /dev/null; then
        nu --version 2>/dev/null || echo "unknown"
    else
        echo ""
    fi
}

# Check if nu-check is available (built into nu)
check_nu_check() {
    if command -v nu &> /dev/null; then
        # nu-check is built-in since v0.60+
        nu -c "nu-check --help" &>/dev/null && echo "true" || echo "false"
    else
        echo "false"
    fi
}

# Check if nu --ide-check is supported
check_ide_check() {
    if command -v nu &> /dev/null; then
        nu --ide-check --help &>/dev/null 2>&1 && echo "true" || echo "false"
    else
        echo "false"
    fi
}

# Check if nu-lint is available
check_nu_lint() {
    command -v nu-lint &> /dev/null && echo "true" || echo "false"
}

# Check if nufmt is available
check_nufmt() {
    command -v nufmt &> /dev/null && echo "true" || echo "false"
}

# Check if nu --mcp is supported (MCP server mode)
check_mcp() {
    if command -v nu &> /dev/null; then
        # Check if --mcp flag exists in help output
        nu --help 2>/dev/null | grep -q "\-\-mcp" && echo "true" || echo "false"
    else
        echo "false"
    fi
}

# Check if nu --lsp is supported (Language Server mode)
check_lsp() {
    if command -v nu &> /dev/null; then
        # Check if --lsp flag exists in help output
        nu --help 2>/dev/null | grep -q "\-\-lsp" && echo "true" || echo "false"
    else
        echo "false"
    fi
}

# Check for polars plugin
check_polars() {
    if command -v nu &> /dev/null; then
        nu -c 'plugin list | where name == "polars" | length' 2>/dev/null | grep -q "1" && echo "true" || echo "false"
    else
        echo "false"
    fi
}

# ============================================================================
# Configuration Loading
# ============================================================================

# Default hook mode
HOOK_MODE="strict"
CONFIG_FILE="$HOME/.claude/nushell-dev.hooks.json"

# Load config if exists
if [[ -f "$CONFIG_FILE" ]]; then
    # Try to extract hook_mode using basic tools (jq if available, fallback to grep)
    if command -v jq &> /dev/null; then
        mode=$(jq -r '.hook_mode // "strict"' "$CONFIG_FILE" 2>/dev/null || echo "strict")
        HOOK_MODE="$mode"
    else
        # Fallback: simple grep extraction
        mode=$(grep -o '"hook_mode"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/' || echo "strict")
        [[ -n "$mode" ]] && HOOK_MODE="$mode"
    fi
fi

# ============================================================================
# Run Detection
# ============================================================================

# Detect all tools
NU_VERSION=$(get_nu_version)
NU_CHECK_AVAILABLE=$(check_nu_check)
IDE_CHECK_AVAILABLE=$(check_ide_check)
NU_LINT_AVAILABLE=$(check_nu_lint)
NUFMT_AVAILABLE=$(check_nufmt)
MCP_AVAILABLE=$(check_mcp)
LSP_AVAILABLE=$(check_lsp)
POLARS_AVAILABLE=$(check_polars)

# ============================================================================
# Build Report
# ============================================================================

build_report() {
    local report=""
    report+="Nushell Development Environment Initialized\n"
    report+="\n"
    report+="Validation Tools:\n"

    # Nushell itself
    if [[ -n "$NU_VERSION" ]]; then
        report+="  $GREEN nu v$NU_VERSION\n"
    else
        report+="  $RED nu (not installed - required for Nushell development)\n"
    fi

    # nu-check (built-in)
    if [[ "$NU_CHECK_AVAILABLE" == "true" ]]; then
        report+="  $GREEN nu-check (built-in)\n"
    else
        report+="  $RED nu-check (not available)\n"
    fi

    # nu --ide-check
    if [[ "$IDE_CHECK_AVAILABLE" == "true" ]]; then
        report+="  $GREEN nu --ide-check (supported)\n"
    else
        report+="  $RED nu --ide-check (not supported in this version)\n"
    fi

    # nu-lint
    if [[ "$NU_LINT_AVAILABLE" == "true" ]]; then
        report+="  $GREEN nu-lint (installed)\n"
    else
        report+="  $RED nu-lint (not installed - run: cargo install nu-lint)\n"
    fi

    # nufmt
    if [[ "$NUFMT_AVAILABLE" == "true" ]]; then
        report+="  $GREEN nufmt (installed)\n"
    else
        report+="  $RED nufmt (not installed)\n"
    fi

    # nu --mcp
    if [[ "$MCP_AVAILABLE" == "true" ]]; then
        report+="  $GREEN nu --mcp (supported)\n"
    else
        report+="  $RED nu --mcp (not supported in this version)\n"
    fi

    # nu --lsp
    if [[ "$LSP_AVAILABLE" == "true" ]]; then
        report+="  $GREEN nu --lsp (supported)\n"
    else
        report+="  $RED nu --lsp (not supported in this version)\n"
    fi

    report+="\n"

    # Optional: Polars plugin
    if [[ "$POLARS_AVAILABLE" == "true" ]]; then
        report+="Plugins:\n"
        report+="  $GREEN polars (data processing)\n"
        report+="\n"
    fi

    # Hook mode
    report+="CLI Guidelines: ${HOOK_MODE^} enforcement enabled\n"

    echo -e "$report"
}

# ============================================================================
# Export Environment Variables
# ============================================================================

# Build environment export section for JSON
build_env_exports() {
    cat << ENVEOF
  "env": {
    "NUSHELL_VERSION": "$NU_VERSION",
    "NUSHELL_LINT_AVAILABLE": "$NU_LINT_AVAILABLE",
    "NUSHELL_FMT_AVAILABLE": "$NUFMT_AVAILABLE",
    "NUSHELL_IDE_CHECK_AVAILABLE": "$IDE_CHECK_AVAILABLE",
    "NUSHELL_MCP_AVAILABLE": "$MCP_AVAILABLE",
    "NUSHELL_LSP_AVAILABLE": "$LSP_AVAILABLE",
    "NUSHELL_HOOK_MODE": "$HOOK_MODE"
  },
ENVEOF
}

# ============================================================================
# Build System Message
# ============================================================================

# Create a concise system message for Claude
build_system_message() {
    local msg="Nushell v${NU_VERSION:-not found} | "

    # Count available tools
    local available=0
    local total=6

    [[ "$NU_CHECK_AVAILABLE" == "true" ]] && ((available++))
    [[ "$IDE_CHECK_AVAILABLE" == "true" ]] && ((available++))
    [[ "$NU_LINT_AVAILABLE" == "true" ]] && ((available++))
    [[ "$NUFMT_AVAILABLE" == "true" ]] && ((available++))
    [[ "$MCP_AVAILABLE" == "true" ]] && ((available++))
    [[ "$LSP_AVAILABLE" == "true" ]] && ((available++))

    msg+="Tools: $available/$total available | "
    msg+="Mode: $HOOK_MODE"

    if [[ "$POLARS_AVAILABLE" == "true" ]]; then
        msg+=" | Polars: yes"
    fi

    echo "$msg"
}

# ============================================================================
# Output JSON Response
# ============================================================================

REPORT=$(build_report)
SYSTEM_MSG=$(build_system_message)

# Escape the report for JSON (handle newlines and special chars)
REPORT_ESCAPED=$(echo "$REPORT" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' '|' | sed 's/|/\\n/g')

cat << EOF
{
$(build_env_exports)
  "systemMessage": "Nushell Development Environment: $SYSTEM_MSG",
  "displayMessage": "$REPORT_ESCAPED",
  "continue": true
}
EOF

exit 0
