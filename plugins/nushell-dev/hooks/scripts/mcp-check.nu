#!/usr/bin/env nu
# mcp-check.nu - nu --mcp integration for runtime validation
#
# Uses Nushell's MCP server to evaluate code and catch runtime errors.
# This is optional and used for deeper validation.
#
# Usage:
#   nu mcp-check.nu <file-path>
#
# Returns:
#   Table of diagnostics with severity, rule, line, message, and fixable fields
#
# Author: Daniel Bodnar
# Created: 2026-01-29

def main [file: path]: nothing -> table {
    # Check if nu is available
    let nu_available = try {
        let result = (^nu --version | complete)
        $result.exit_code == 0
    } catch {
        false
    }

    if not $nu_available {
        return [{
            severity: "error"
            rule: "TOOL-MISSING"
            line: 0
            message: "Nushell (nu) is not available in PATH"
            fixable: false
        }]
    }

    # Validate file exists
    if not ($file | path exists) {
        return [{
            severity: "error"
            rule: "FILE-NOT-FOUND"
            line: 0
            message: $"File not found: ($file)"
            fixable: false
        }]
    }

    # For now, we'll do basic runtime validation
    # Full MCP integration requires more complex setup

    # Try to source the file and catch errors
    let result = do { ^nu -c $"source ($file)" } | complete

    if $result.exit_code == 0 {
        return []
    }

    # Parse error output to extract line number if possible
    let error_msg = $result.stderr | str trim

    # Try to extract line number from error message
    # Nushell errors often contain "Line X" or similar patterns
    let line_match = $error_msg | parse --regex '(?i)line[:\s]+(\d+)'
    let line_num = if ($line_match | length) > 0 {
        try {
            ($line_match | first).capture0 | into int
        } catch {
            0
        }
    } else {
        0
    }

    [{
        severity: "error"
        rule: "RUNTIME"
        line: $line_num
        message: $error_msg
        fixable: false
    }]
}
