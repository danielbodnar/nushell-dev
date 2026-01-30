#!/usr/bin/env nu
# format-check.nu - nufmt integration for CLI guidelines enforcement
#
# Checks code formatting with nufmt.
# Supports auto-fix mode.
#
# Usage:
#   nu format-check.nu <file-path> [--fix] [--verbose]
#
# Examples:
#   nu format-check.nu script.nu
#   nu format-check.nu script.nu --fix
#   nu format-check.nu script.nu --verbose
#
# Returns:
#   Table of records with format: {severity, rule, line, message, fixable}
#
# Author: Daniel Bodnar
# Created: 2026-01-29

# Rule definitions for format checks
const FORMAT_RULES = {
    STY-FORMAT: { description: "File has formatting issues", fixable: true }
    STY-INDENT: { description: "Indentation issue", fixable: true }
    STY-SPACING: { description: "Spacing issue", fixable: true }
    STY-TABS: { description: "Tab character usage", fixable: true }
    STY-TRAILING: { description: "Trailing whitespace", fixable: true }
    TOOL-MISSING: { description: "Formatting tool not available", fixable: false }
    FILE-ERROR: { description: "File access error", fixable: false }
}

# Check if nufmt is available and get version info
def nufmt-available []: nothing -> record {
    let which_result = (which nufmt | get 0?.path? | default null)

    if $which_result == null {
        return {
            available: false
            path: null
            version: null
        }
    }

    # Try to get version
    let version = try {
        let ver_output = (do { ^nufmt --version } | complete)
        if $ver_output.exit_code == 0 {
            $ver_output.stdout | str trim | split row " " | last | default "unknown"
        } else {
            "unknown"
        }
    } catch {
        "unknown"
    }

    {
        available: true
        path: $which_result
        version: $version
    }
}

# Analyze diff output to identify specific formatting issues
def analyze-diff [diff: string]: string -> table {
    if ($diff | str length) == 0 {
        return []
    }

    let diff_lines = ($diff | lines)
    mut issues = []
    mut current_line = 0

    for line in $diff_lines {
        # Track line numbers from diff headers
        let hunk_match = ($line | parse -r '^@@ -\d+(?:,\d+)? \+(\d+)')
        if ($hunk_match | length) > 0 {
            $current_line = ($hunk_match | first | get capture0 | into int)
            continue
        }

        # Analyze removed lines (lines that will change)
        if ($line | str starts-with "-") and not ($line | str starts-with "---") {
            let content = ($line | str substring 1..)

            # Check for tabs
            if ($content | str contains "\t") {
                $issues = ($issues | append {
                    severity: "warning"
                    rule: "STY-TABS"
                    line: $current_line
                    message: "Tab character should be converted to spaces"
                    fixable: true
                })
            }

            # Check for trailing whitespace
            if ($content =~ '\s+$') {
                $issues = ($issues | append {
                    severity: "warning"
                    rule: "STY-TRAILING"
                    line: $current_line
                    message: "Trailing whitespace detected"
                    fixable: true
                })
            }

            # Check for inconsistent indentation
            if ($content =~ '^\t+ ') or ($content =~ '^ +\t') {
                $issues = ($issues | append {
                    severity: "warning"
                    rule: "STY-INDENT"
                    line: $current_line
                    message: "Mixed tabs and spaces in indentation"
                    fixable: true
                })
            }

            # Check for spacing issues around operators
            if ($content =~ '[^\s]=(?!=)') or ($content =~ '(?<!=)=[^\s>=]') {
                $issues = ($issues | append {
                    severity: "info"
                    rule: "STY-SPACING"
                    line: $current_line
                    message: "Spacing around assignment operator"
                    fixable: true
                })
            }

            $current_line = $current_line + 1
        } else if ($line | str starts-with "+") and not ($line | str starts-with "+++") {
            # Added lines don't increment current_line counter
        } else if not ($line | str starts-with "@@") and not ($line | str starts-with "---") and not ($line | str starts-with "+++") {
            # Context line
            $current_line = $current_line + 1
        }
    }

    # Deduplicate issues by line and rule
    $issues | uniq-by line rule
}

# Run nufmt --check on a file
def run-format-check [file: path, verbose: bool] {
    let check_result = try {
        do { ^nufmt --check $file } | complete
    } catch {|err|
        return [{
            severity: "error"
            rule: "FILE-ERROR"
            line: 0
            message: $"Failed to run nufmt: ($err)"
            fixable: false
        }]
    }

    if $check_result.exit_code == 0 {
        # File is properly formatted
        return []
    }

    # File has formatting issues - get the diff for details
    let diff_result = try {
        do { ^nufmt --diff $file } | complete
    } catch {
        { stdout: "", stderr: "" }
    }

    let diff = ($diff_result.stdout | default "" | str trim)

    if $verbose and ($diff | str length) > 0 {
        print "[format-check] Diff output:"
        print $diff
    }

    # Analyze the diff to identify specific issues
    let specific_issues = (analyze-diff $diff)

    # If we found specific issues, return them
    if ($specific_issues | length) > 0 {
        return $specific_issues
    }

    # Otherwise return a general formatting issue
    let lines_changed = if ($diff | str length) > 0 {
        let additions = ($diff | lines | where {|l| $l | str starts-with "+"} | where {|l| not ($l | str starts-with "+++")} | length)
        let deletions = ($diff | lines | where {|l| $l | str starts-with "-"} | where {|l| not ($l | str starts-with "---")} | length)
        $"($additions + $deletions) lines would be modified"
    } else {
        "File needs reformatting"
    }

    [{
        severity: "warning"
        rule: "STY-FORMAT"
        line: 0
        message: $"($lines_changed). Run 'nufmt $file' to fix."
        fixable: true
    }]
}

# Run nufmt to auto-fix formatting issues
def run-format-fix [file: path, verbose: bool] {
    # First check if there are issues
    let before_issues = (run-format-check $file $verbose)

    if ($before_issues | length) == 0 {
        if $verbose {
            print "[format-check] File already properly formatted"
        }
        return []
    }

    # Run nufmt to fix
    let fix_result = try {
        do { ^nufmt $file } | complete
    } catch {|err|
        return [{
            severity: "error"
            rule: "FILE-ERROR"
            line: 0
            message: $"Failed to run nufmt: ($err)"
            fixable: false
        }]
    }

    if $fix_result.exit_code != 0 {
        let error_msg = ($fix_result.stderr | default "Unknown error" | str trim)
        return [{
            severity: "error"
            rule: "FILE-ERROR"
            line: 0
            message: $"nufmt failed: ($error_msg)"
            fixable: false
        }]
    }

    # Verify the fix worked
    let after_issues = (run-format-check $file false)

    if ($after_issues | length) > 0 {
        if $verbose {
            print "[format-check] Warning: Some issues remain after fix"
        }
        return $after_issues
    }

    if $verbose {
        print "[format-check] Formatting applied successfully"
    }

    # Return empty table - all issues fixed
    []
}

# Main entry point
def main [
    file: path              # Path to Nushell file to check
    --fix                   # Auto-fix formatting issues
    --verbose (-v)          # Show additional diagnostic information
]: nothing -> table {
    # Validate file exists
    if not ($file | path exists) {
        return [{
            severity: "error"
            rule: "FILE-ERROR"
            line: 0
            message: $"File not found: ($file)"
            fixable: false
        }]
    }

    # Validate file extension
    let ext = ($file | path parse | get extension | default "")
    if $ext != "nu" {
        return [{
            severity: "error"
            rule: "FILE-ERROR"
            line: 0
            message: "File must have .nu extension"
            fixable: false
        }]
    }

    let file_expanded = ($file | path expand)

    # Check if nufmt is available
    let nufmt_info = (nufmt-available)

    if $verbose {
        print $"[format-check] Tool: (if $nufmt_info.available { $'nufmt v($nufmt_info.version)' } else { 'not available' })"
        print $"[format-check] File: ($file_expanded)"
        print $"[format-check] Mode: (if $fix { 'fix' } else { 'check' })"
    }

    if not $nufmt_info.available {
        return [{
            severity: "info"
            rule: "TOOL-MISSING"
            line: 0
            message: "nufmt not installed, skipping format checks (install: cargo install nufmt)"
            fixable: false
        }]
    }

    # Run format check or fix
    if $fix {
        run-format-fix $file_expanded $verbose
    } else {
        run-format-check $file_expanded $verbose
    }
}
