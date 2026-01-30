#!/usr/bin/env nu
# lint-check.nu - nu-lint integration for CLI guidelines enforcement
#
# Runs nu-lint if available, returns structured lint results.
# Gracefully degrades to fallback linting if nu-lint is not installed.
#
# Usage:
#   nu lint-check.nu <file-path> [--verbose]
#
# Examples:
#   nu lint-check.nu script.nu
#   nu lint-check.nu script.nu --verbose
#
# Returns:
#   Table of records with format: {severity, rule, line, message, fixable}
#
# Author: Daniel Bodnar
# Created: 2026-01-29

# Rule definitions for CLI guidelines
const LINT_RULES = {
    LINT-UNUSED: { description: "Unused variable or import", fixable: true }
    LINT-DEPRECATED: { description: "Deprecated command usage", fixable: true }
    LINT-STYLE: { description: "Style violation", fixable: true }
    LINT-TYPE: { description: "Type mismatch or issue", fixable: false }
    LINT-PERF: { description: "Performance concern", fixable: true }
    LINT-TODO: { description: "TODO/FIXME comment found", fixable: false }
    LINT-LINE: { description: "Line length exceeded", fixable: true }
    LINT-SYNTAX: { description: "Syntax issue", fixable: false }
    LINT-GENERAL: { description: "General lint issue", fixable: false }
    TOOL-MISSING: { description: "Linting tool not available", fixable: false }
    FILE-ERROR: { description: "File access error", fixable: false }
}

# Keywords for categorizing lint messages into rules
const CATEGORY_KEYWORDS = {
    LINT-UNUSED: ["unused", "never used", "dead code", "unreachable"]
    LINT-DEPRECATED: ["deprecated", "obsolete", "removed", "legacy"]
    LINT-STYLE: ["style", "naming", "convention", "whitespace", "indent"]
    LINT-TYPE: ["type", "mismatch", "expected", "incompatible"]
    LINT-PERF: ["performance", "slow", "inefficient", "optimize"]
}

# Deprecated commands to check in fallback mode
const DEPRECATED_COMMANDS = [
    "build-string"
    "str find-replace"
    "nth"
    "pivot"
    "fetch"
    "post"
    "to-md"
    "to-html"
]

# Categorize a lint message into a rule based on keywords
def categorize-message [message: string]: string -> string {
    let msg_lower = ($message | str downcase)

    for rule in ($CATEGORY_KEYWORDS | columns) {
        let keywords = ($CATEGORY_KEYWORDS | get $rule)
        for keyword in $keywords {
            if ($msg_lower | str contains $keyword) {
                return $rule
            }
        }
    }

    "LINT-GENERAL"
}

# Determine severity from message content
def determine-severity [message: string]: string -> string {
    let msg_lower = ($message | str downcase)

    if ($msg_lower | str contains "error") {
        "error"
    } else if ($msg_lower | str contains "warning") or ($msg_lower | str contains "warn") {
        "warning"
    } else if ($msg_lower | str contains "info") or ($msg_lower | str contains "note") {
        "info"
    } else {
        "warning"
    }
}

# Check if a rule is fixable
def is-fixable [rule: string]: string -> bool {
    $LINT_RULES | get -o $rule | get -o fixable | default false
}

# Parse nu-lint output into structured records
def parse-nu-lint-output [output: string]: string -> table {
    let lines = ($output | lines | where {|l| ($l | str trim | str length) > 0 })

    mut issues = []

    for line in $lines {
        # Skip box drawing characters used in pretty output
        if ($line =~ '^\s*[─│╭╮╯╰├┤┬┴┼]') {
            continue
        }

        # Pattern 1: file:line:col: message
        let pattern1 = ($line | parse -r '^(.+?):(\d+):(\d+):\s*(.+)$')
        if ($pattern1 | length) > 0 {
            let p = ($pattern1 | first)
            let message = ($p | get capture3 | str trim)
            let rule = (categorize-message $message)

            $issues = ($issues | append {
                severity: (determine-severity $message)
                rule: $rule
                line: ($p | get capture1 | into int)
                message: $message
                fixable: (is-fixable $rule)
            })
            continue
        }

        # Pattern 2: warning/error: message at line X
        let pattern2 = ($line | parse -r '(?i)(warning|error):\s*(.+?)\s+(?:at\s+)?(?:line\s+)?(\d+)')
        if ($pattern2 | length) > 0 {
            let p = ($pattern2 | first)
            let message = ($p | get capture1 | str trim)
            let rule = (categorize-message $message)

            $issues = ($issues | append {
                severity: ($p | get capture0 | str downcase)
                rule: $rule
                line: ($p | get capture2 | into int)
                message: $message
                fixable: (is-fixable $rule)
            })
            continue
        }

        # Pattern 3: [severity] message (line X)
        let pattern3 = ($line | parse -r '\[(warning|error|info)\]\s*(.+?)\s*\(line\s*(\d+)\)')
        if ($pattern3 | length) > 0 {
            let p = ($pattern3 | first)
            let message = ($p | get capture1 | str trim)
            let rule = (categorize-message $message)

            $issues = ($issues | append {
                severity: ($p | get capture0 | str downcase)
                rule: $rule
                line: ($p | get capture2 | into int)
                message: $message
                fixable: (is-fixable $rule)
            })
            continue
        }

        # Generic lint message without location
        if ($line =~ '(?i)(warning|error|issue|lint)') {
            let rule = (categorize-message $line)
            $issues = ($issues | append {
                severity: (determine-severity $line)
                rule: $rule
                line: 0
                message: ($line | str trim)
                fixable: (is-fixable $rule)
            })
        }
    }

    $issues
}

# Perform fallback linting when nu-lint is not available
def fallback-lint [file_path: path]: path -> table {
    let content = try {
        open $file_path | into string
    } catch {
        return [{
            severity: "error"
            rule: "FILE-ERROR"
            line: 0
            message: $"Cannot read file: ($file_path)"
            fixable: false
        }]
    }

    let lines = ($content | lines)
    mut issues = []

    for idx in 0..<($lines | length) {
        let line = ($lines | get $idx)
        let line_num = $idx + 1

        # Check: Trailing whitespace
        if ($line =~ '\s+$') {
            $issues = ($issues | append {
                severity: "warning"
                rule: "LINT-STYLE"
                line: $line_num
                message: "Trailing whitespace detected"
                fixable: true
            })
        }

        # Check: TODO/FIXME comments
        let todo_match = ($line | parse -r '(?i)#\s*(TODO|FIXME|XXX|HACK):?\s*(.*)')
        if ($todo_match | length) > 0 {
            let kind = ($todo_match | first | get capture0 | str upcase)
            let desc = ($todo_match | first | get capture1 | str trim)
            $issues = ($issues | append {
                severity: "info"
                rule: "LINT-TODO"
                line: $line_num
                message: $"($kind) comment: ($desc)"
                fixable: false
            })
        }

        # Check: Deprecated commands
        for cmd in $DEPRECATED_COMMANDS {
            if ($line | str contains $cmd) {
                $issues = ($issues | append {
                    severity: "warning"
                    rule: "LINT-DEPRECATED"
                    line: $line_num
                    message: $"Deprecated command: '($cmd)' - check Nushell version compatibility"
                    fixable: true
                })
            }
        }

        # Check: Line length > 120 characters
        let line_len = ($line | str length)
        if $line_len > 120 {
            $issues = ($issues | append {
                severity: "warning"
                rule: "LINT-LINE"
                line: $line_num
                message: $"Line exceeds 120 characters: ($line_len) chars"
                fixable: true
            })
        }

        # Check: Double semicolons (common copy-paste error)
        if ($line =~ ';;') {
            $issues = ($issues | append {
                severity: "warning"
                rule: "LINT-SYNTAX"
                line: $line_num
                message: "Double semicolon found (possible copy-paste error)"
                fixable: true
            })
        }

        # Check: Inconsistent indentation (mixed tabs and spaces)
        if ($line =~ '^\t+ ') or ($line =~ '^ +\t') {
            $issues = ($issues | append {
                severity: "warning"
                rule: "LINT-STYLE"
                line: $line_num
                message: "Mixed tabs and spaces in indentation"
                fixable: true
            })
        }

        # Check: Multiple consecutive blank lines (basic check)
        if $idx > 0 and ($line | str trim | is-empty) {
            let prev_line = ($lines | get ($idx - 1))
            if ($prev_line | str trim | is-empty) and $idx > 1 {
                let prev_prev = ($lines | get ($idx - 2))
                if ($prev_prev | str trim | is-empty) {
                    $issues = ($issues | append {
                        severity: "info"
                        rule: "LINT-STYLE"
                        line: $line_num
                        message: "Multiple consecutive blank lines"
                        fixable: true
                    })
                }
            }
        }
    }

    $issues
}

# Check if nu-lint is available
def nu-lint-available []: nothing -> bool {
    let result = (do { ^which nu-lint } | complete)
    $result.exit_code == 0 and ($result.stdout | str trim | str length) > 0
}

# Main entry point
def main [
    file: path              # Path to the Nushell file to lint
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

    # Check for nu-lint availability
    let has_nu_lint = (nu-lint-available)

    if $verbose {
        print $"[lint-check] Tool: (if $has_nu_lint { 'nu-lint' } else { 'fallback' })"
        print $"[lint-check] File: ($file_expanded)"
    }

    if $has_nu_lint {
        # Run nu-lint
        let lint_result = (do { ^nu-lint check $file_expanded } | complete)

        # Combine stdout and stderr for parsing
        let stdout = ($lint_result.stdout | default "")
        let stderr = ($lint_result.stderr | default "")
        let combined = $"($stdout)\n($stderr)" | str trim

        if ($combined | str length) == 0 {
            # No output means clean
            return []
        }

        # Parse nu-lint output
        let issues = (parse-nu-lint-output $combined)

        if $verbose and (($issues | length) == 0) {
            print "[lint-check] nu-lint ran but produced no parseable issues"
        }

        $issues
    } else {
        # nu-lint not installed - use fallback linting
        if $verbose {
            print "[lint-check] nu-lint not found, using fallback linting"
        }

        # Return tool missing notice plus fallback results
        let fallback_issues = (fallback-lint $file_expanded)

        # Prepend info about missing tool
        [{
            severity: "info"
            rule: "TOOL-MISSING"
            line: 0
            message: "nu-lint not installed - using basic fallback linting (install: cargo install nu-lint)"
            fixable: false
        }] | append $fallback_issues
    }
}
