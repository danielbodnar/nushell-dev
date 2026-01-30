#!/usr/bin/env nu
# syntax-check.nu - Enhanced nu-check wrapper with structured error parsing
#
# Wraps nu-check with enhanced error parsing and structured output.
# Provides detailed, actionable feedback for syntax errors and CLI guideline violations.
#
# Usage:
#   nu syntax-check.nu <file>              # Check single file
#   nu syntax-check.nu <file> --verbose    # Detailed output
#   nu syntax-check.nu <file> --json       # JSON output
#   nu syntax-check.nu <file> --fix        # Suggest fixes
#
# Output: Table of {severity, line, column, message, suggestion, rule}
#
# Author: Daniel Bodnar
# Created: 2026-01-29

# Severity levels for issue categorization
const SEVERITY_ERROR = "error"
const SEVERITY_WARNING = "warning"
const SEVERITY_INFO = "info"
const SEVERITY_HINT = "hint"

# Error categories for grouping
const CATEGORY_SYNTAX = "syntax"
const CATEGORY_TYPE = "type"
const CATEGORY_REFERENCE = "reference"
const CATEGORY_GUIDELINE = "guideline"
const CATEGORY_STYLE = "style"

# Create a standardized error record
# Returns: record with all error fields populated
def make-error [
    severity: string     # Error severity (error, warning, info, hint)
    line: any            # Line number (int or null)
    column: any          # Column number (int or null)
    message: string      # Human-readable error message
    suggestion: string   # How to fix the error
    rule: string         # Rule identifier for filtering
    category: string     # Error category for grouping
] {
    {
        severity: $severity
        line: $line
        column: $column
        message: $message
        suggestion: $suggestion
        rule: $rule
        category: $category
    }
}

# Check if nu-check is available
# Returns: bool indicating availability
def nu-check-available [] {
    (which nu-check | is-not-empty)
}

# Run syntax validation with nu --commands
# Returns: record with exit_code, stdout, stderr
def run-nu-check [file: path] {
    # Use nu --commands with source for syntax validation
    do { ^nu --commands $"source '($file)'" } | complete
}

# Run nu --ide-check for additional diagnostics
# Returns: record with exit_code, stdout, stderr
def run-ide-check [file: path] {
    # ide-check outputs JSON diagnostics line by line
    do { ^nu --ide-check 10000 $file } | complete
}

# Parse nu-check debug output into structured error records
# Returns: list<record> of parsed errors
def parse-nu-check-errors [output: string, file: path] {
    let lines = $output | lines | where { |l| ($l | str trim | str length) > 0 }

    mut errors = []
    mut current_message = ""
    mut current_line: int = 0
    mut current_column: int = 0
    mut current_suggestion = ""
    mut in_error_block = false

    for line in $lines {
        let trimmed = $line | str trim

        # Skip pure box-drawing lines
        if ($trimmed =~ '^[╭╮╯╰│─┬┴├┤┼]+$') {
            continue
        }

        # Detect error/warning markers
        if ($trimmed | str contains "Error:") or ($trimmed =~ '^[×✗x]\s') or ($trimmed | str starts-with "error") {
            # Save previous error if exists
            if $in_error_block and ($current_message | str length) > 0 {
                $errors = ($errors | append (make-error
                    $SEVERITY_ERROR
                    $current_line
                    $current_column
                    $current_message
                    (if ($current_suggestion | is-empty) { "Fix the syntax error" } else { $current_suggestion })
                    "syntax_error"
                    $CATEGORY_SYNTAX
                ))
            }

            # Start new error
            $in_error_block = true
            $current_message = $trimmed
                | str replace -r '^.*?[×✗x]\s*' ''
                | str replace -r '^Error:\s*' ''
                | str replace -r '^error\[.*?\]:\s*' ''
                | str trim
            $current_line = 0
            $current_column = 0
            $current_suggestion = ""
        }

        # Parse line:column information from various formats
        # Format 1: "  15 │ code here"
        let line_col_match1 = $trimmed | parse -r '^\s*(\d+)\s*[│|]' | get -o 0
        if $line_col_match1 != null {
            $current_line = ($line_col_match1 | get capture0 | into int)
        }

        # Format 2: "file.nu:15:3: error message"
        let line_col_match2 = $trimmed | parse -r ':(\d+):(\d+):' | get -o 0
        if $line_col_match2 != null {
            $current_line = ($line_col_match2 | get capture0 | into int)
            $current_column = ($line_col_match2 | get capture1 | into int)
        }

        # Format 3: "at line 15, column 3"
        let line_col_match3 = $trimmed | parse -r 'line\s+(\d+)(?:,\s*column\s+(\d+))?' | get -o 0
        if $line_col_match3 != null {
            $current_line = ($line_col_match3 | get capture0 | into int)
            let col = $line_col_match3 | get -o capture1
            if $col != null {
                $current_column = ($col | into int)
            }
        }

        # Parse help/hint suggestions
        if ($trimmed | str starts-with "help:") or ($trimmed | str starts-with "hint:") {
            $current_suggestion = $trimmed
                | str replace -r '^(?:help|hint):\s*' ''
                | str trim
        }

        # Parse "did you mean" suggestions
        if ($trimmed | str contains "did you mean") {
            let suggestion = $trimmed | str replace -r '.*did you mean[:\s]*' '' | str trim
            $current_suggestion = $"Did you mean: ($suggestion)"
        }

        # Parse expected/found type errors
        if ($trimmed | str contains "expected") and ($trimmed | str contains "found") {
            if $in_error_block and ($current_message | is-empty) {
                $current_message = $trimmed
            }
        }
    }

    # Don't forget the last error
    if $in_error_block and ($current_message | str length) > 0 {
        $errors = ($errors | append (make-error
            $SEVERITY_ERROR
            $current_line
            $current_column
            $current_message
            (if ($current_suggestion | is-empty) { "Fix the syntax error" } else { $current_suggestion })
            "syntax_error"
            $CATEGORY_SYNTAX
        ))
    }

    # If no errors parsed but output indicates failure, create generic error
    if ($errors | is-empty) and ($output | str length) > 0 {
        let snippet = $output | str substring 0..300 | str replace "\n" " " | str trim
        $errors = [(make-error
            $SEVERITY_ERROR
            0
            0
            $"Syntax validation failed: ($snippet)"
            "Review the file for syntax errors"
            "syntax_error"
            $CATEGORY_SYNTAX
        )]
    }

    $errors
}

# Parse nu --ide-check JSON output into structured errors
# Returns: list<record> of parsed diagnostics
def parse-ide-check-output [output: string] {
    mut errors = []

    let lines = $output | lines | where { |l| ($l | str trim | str length) > 0 }

    for line in $lines {
        let parsed = try {
            $line | from json
        } catch {
            null
        }

        if $parsed == null {
            continue
        }

        # IDE check returns various message types
        let msg_type = $parsed | get -o type | default ""

        if $msg_type == "diagnostic" {
            let severity = match ($parsed | get -o severity | default "error") {
                "error" => $SEVERITY_ERROR
                "warning" => $SEVERITY_WARNING
                "information" | "info" => $SEVERITY_INFO
                "hint" => $SEVERITY_HINT
                _ => $SEVERITY_WARNING
            }

            let span = $parsed | get -o span | default {}
            let start_line = $span | get -o start | default null

            $errors = ($errors | append (make-error
                $severity
                $start_line
                null
                ($parsed | get -o message | default "Unknown diagnostic")
                "Review the diagnostic and fix accordingly"
                "ide_diagnostic"
                $CATEGORY_SYNTAX
            ))
        }
    }

    $errors
}

# Check for CLI guideline violations in file content
# Returns: list<record> of guideline violations
def check-cli-guidelines [file: path] {
    let content = open $file | into string
    let lines = $content | lines

    mut issues = []

    # Track documentation for exports
    mut last_comment_line = -10

    for idx in 0..<($lines | length) {
        let line = $lines | get $idx
        let line_num = $idx + 1
        let trimmed = $line | str trim

        # Track comment lines
        if ($trimmed | str starts-with "#") and not ($trimmed | str starts-with "#!") {
            $last_comment_line = $idx
        }

        # Check export def declarations
        if ($trimmed | str starts-with "export def ") {
            let name = $trimmed
                | str replace "export def " ""
                | split row " "
                | first
                | str replace "[" ""
                | str replace "\"" ""

            # Get complete signature
            let signature = $lines | skip $idx | take 10 | str join " "
            let before_brace = $signature | split row "{" | first

            # Check missing return type
            if not ($before_brace | str contains "->") {
                $issues = ($issues | append (make-error
                    $SEVERITY_ERROR
                    $line_num
                    1
                    $"Export function '($name)' missing return type annotation"
                    "Add '-> return_type' before opening brace (e.g., -> string, -> list<record>, -> nothing)"
                    "missing_return_type"
                    $CATEGORY_GUIDELINE
                ))
            }

            # Check missing documentation (must be within 3 lines)
            if ($idx - $last_comment_line) > 3 {
                $issues = ($issues | append (make-error
                    $SEVERITY_WARNING
                    $line_num
                    1
                    $"Export function '($name)' missing documentation comment"
                    "Add a # comment above the function describing its purpose"
                    "missing_documentation"
                    $CATEGORY_GUIDELINE
                ))
            }

            # Check parameter types
            let param_match = $before_brace | parse -r '\[([^\]]*)\]' | get -o 0
            if $param_match != null {
                let params = $param_match | get capture0 | split row "," | each { |p| $p | str trim }
                for param in $params {
                    # Skip flags, empty, comments, rest params
                    if ($param | str starts-with "--") or ($param | str starts-with "-") or ($param | is-empty) or ($param | str starts-with "#") or ($param | str starts-with "...") {
                        continue
                    }

                    if not ($param | str contains ":") {
                        let param_name = $param | split row " " | first | str replace "$" ""
                        $issues = ($issues | append (make-error
                            $SEVERITY_ERROR
                            $line_num
                            1
                            $"Parameter '($param_name)' in '($name)' missing type annotation"
                            $"Add type annotation: ($param_name): <type>"
                            "missing_param_type"
                            $CATEGORY_GUIDELINE
                        ))
                    }
                }
            }
        }

        # Check def main for --help flag
        if ($trimmed | str starts-with "def main") {
            let signature = $lines | skip $idx | take 10 | str join " "
            let before_brace = $signature | split row "{" | first

            if not ($before_brace | str contains "--help") and not ($before_brace | str contains "-h") {
                $issues = ($issues | append (make-error
                    $SEVERITY_WARNING
                    $line_num
                    1
                    "Main command should include --help flag"
                    "Add '--help (-h)' parameter for CLI discoverability"
                    "missing_help_flag"
                    $CATEGORY_GUIDELINE
                ))
            }
        }

        # Check for hardcoded secrets
        let secret_patterns = ["api_key", "apikey", "secret_key", "password", "token", "bearer", "private_key"]
        for pattern in $secret_patterns {
            if ($trimmed | str downcase | str contains $pattern) {
                if ($trimmed | str contains "=") and not ($trimmed | str contains "$env") {
                    if ($trimmed | str contains '"') or ($trimmed | str contains "'") {
                        $issues = ($issues | append (make-error
                            $SEVERITY_WARNING
                            $line_num
                            1
                            $"Possible hardcoded secret detected (($pattern))"
                            "Use environment variables: $env.VAR_NAME"
                            "hardcoded_secret"
                            $CATEGORY_GUIDELINE
                        ))
                        break
                    }
                }
            }
        }

        # Check line length (style)
        let line_len = $line | str length
        if $line_len > 120 {
            $issues = ($issues | append (make-error
                $SEVERITY_INFO
                $line_num
                121
                $"Line exceeds 120 characters (($line_len))"
                "Break into multiple lines for readability"
                "line_too_long"
                $CATEGORY_STYLE
            ))
        }
    }

    $issues
}

# Format errors for human-readable output
# Returns: formatted string
def format-human-output [errors: list<record>, file: path, verbose: bool] {
    if ($errors | is-empty) {
        return $"(ansi green)OK(ansi reset) ($file | path basename) - No issues found"
    }

    let error_count = $errors | where severity == $SEVERITY_ERROR | length
    let warning_count = $errors | where severity == $SEVERITY_WARNING | length
    let info_count = $errors | where severity in [$SEVERITY_INFO, $SEVERITY_HINT] | length

    mut output = [$"(ansi bold)Checking:(ansi reset) ($file | path basename)\n"]

    # Group by category
    let by_category = $errors | group-by category

    for category in ($by_category | columns) {
        let cat_errors = $by_category | get $category

        let cat_label = match $category {
            "syntax" => "SYNTAX ERRORS"
            "type" => "TYPE ERRORS"
            "reference" => "REFERENCE ERRORS"
            "guideline" => "CLI GUIDELINE ISSUES"
            "style" => "STYLE ISSUES"
            _ => ($category | str upcase)
        }

        $output = ($output | append $"\n(ansi yellow)($cat_label):(ansi reset)")

        for err in $cat_errors {
            let severity_color = match $err.severity {
                "error" => "red"
                "warning" => "yellow"
                "info" => "cyan"
                "hint" => "blue"
                _ => "white"
            }

            let location = if $err.line > 0 {
                let col = if $err.column > 0 { $":($err.column)" } else { "" }
                $"Line ($err.line)($col)"
            } else {
                "Unknown location"
            }

            $output = ($output | append $"  (ansi $severity_color)[$($err.severity | str upcase)](ansi reset) ($location): ($err.message)")

            if $verbose and ($err.suggestion | str length) > 0 {
                $output = ($output | append $"    (ansi dim)Fix: ($err.suggestion)(ansi reset)")
            }
        }
    }

    # Summary
    $output = ($output | append "")
    $output = ($output | append $"(ansi bold)Summary:(ansi reset) ($error_count) errors, ($warning_count) warnings, ($info_count) info")

    let status = if $error_count > 0 {
        $"(ansi red)FAILED(ansi reset)"
    } else if $warning_count > 0 {
        $"(ansi yellow)PASSED WITH WARNINGS(ansi reset)"
    } else {
        $"(ansi green)PASSED(ansi reset)"
    }

    $output = ($output | append $"Status: ($status)")

    $output | str join "\n"
}

# Main entry point
# Returns: record with validation results or prints formatted output
def main [
    file: path              # Path to the Nushell file to validate
    --verbose (-v)          # Show detailed output with suggestions
    --json                  # Output as JSON
    --fix                   # Include fix suggestions in output
    --no-guidelines         # Skip CLI guideline checks
    --help (-h)             # Show help message
] {
    if $help {
        print "syntax-check.nu - Enhanced nu-check wrapper with structured output"
        print ""
        print "Usage:"
        print "  nu syntax-check.nu <file>              # Check single file"
        print "  nu syntax-check.nu <file> --verbose    # Detailed output"
        print "  nu syntax-check.nu <file> --json       # JSON output"
        print "  nu syntax-check.nu <file> --fix        # Include fix suggestions"
        print ""
        print "Output fields:"
        print "  severity   - error, warning, info, hint"
        print "  line       - Line number (1-indexed)"
        print "  column     - Column number (1-indexed)"
        print "  message    - Human-readable description"
        print "  suggestion - How to fix the issue"
        print "  rule       - Rule identifier"
        print "  category   - syntax, type, guideline, style"
        return null
    }

    # Verify file exists
    if not ($file | path exists) {
        let error = make-error $SEVERITY_ERROR null null $"File not found: ($file)" "Verify the file path is correct" "file_not_found" "reference"

        if $json {
            return {
                valid: false
                file: ($file | into string)
                errors: [$error]
                summary: { errors: 1, warnings: 0, info: 0, total: 1 }
            }
        }

        print $"(ansi red)Error:(ansi reset) File not found: ($file)"
        exit 1
    }

    let file_expanded = $file | path expand

    mut all_errors = []

    # Run nu-check for syntax validation
    let check_result = run-nu-check $file_expanded
    let syntax_valid = $check_result.exit_code == 0

    if not $syntax_valid {
        let combined = $"($check_result.stderr | default '')\n($check_result.stdout | default '')"
        let syntax_errors = parse-nu-check-errors $combined $file_expanded
        $all_errors = ($all_errors | append $syntax_errors)
    }

    # Run ide-check for additional diagnostics (even if syntax passed)
    let ide_result = run-ide-check $file_expanded
    if ($ide_result.stdout | str trim | str length) > 0 {
        let ide_errors = parse-ide-check-output $ide_result.stdout
        # Deduplicate by message
        for err in $ide_errors {
            let exists = $all_errors | any { |e| $e.message == $err.message }
            if not $exists {
                $all_errors = ($all_errors | append $err)
            }
        }
    }

    # Check CLI guidelines (only if syntax is valid)
    if $syntax_valid and not $no_guidelines {
        let guideline_errors = check-cli-guidelines $file_expanded
        $all_errors = ($all_errors | append $guideline_errors)
    }

    # Build summary
    let error_count = $all_errors | where severity == $SEVERITY_ERROR | length
    let warning_count = $all_errors | where severity == $SEVERITY_WARNING | length
    let info_count = $all_errors | where severity in [$SEVERITY_INFO, $SEVERITY_HINT] | length

    let is_valid = $syntax_valid and ($error_count == 0)

    # Output based on format
    if $json {
        let result = {
            valid: $is_valid
            syntax_valid: $syntax_valid
            file: $file_expanded
            tool: (if (nu-check-available) { "nu-check" } else { "nu --commands" })
            errors: $all_errors
            summary: {
                errors: $error_count
                warnings: $warning_count
                info: $info_count
                total: ($all_errors | length)
            }
        }
        return $result
    }

    # Human-readable output
    print (format-human-output $all_errors $file_expanded ($verbose or $fix))

    # Exit with appropriate code
    if not $is_valid {
        exit 1
    }

    null
}
