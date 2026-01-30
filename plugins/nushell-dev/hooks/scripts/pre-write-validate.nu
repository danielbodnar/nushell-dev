#!/usr/bin/env nu
# pre-write-validate.nu - PreToolUse validation for Nushell code
#
# Validates proposed Nushell code BEFORE it's written to disk.
# Enforces CLI guidelines: type annotations, documentation, valid syntax.
#
# Input: JSON via stdin with tool_input.file_path and tool_input.content
# Output: JSON {"action": "approve"} or {"action": "deny", "message": "..."}
#
# Exit codes:
#   0 - Approved (valid code or non-.nu file)
#   2 - Denied (validation failures with actionable feedback)
#
# Author: Daniel Bodnar
# Created: 2026-01-29

# Severity levels for categorizing issues
const SEVERITY_CRITICAL = "critical"
const SEVERITY_REQUIRED = "required"
const SEVERITY_WARNING = "warning"

# Parse JSON input string
# Returns: record with file_path and content
def parse-input [raw: string] {
    if ($raw | is-empty) {
        return { file_path: "", content: "" }
    }

    try {
        let parsed = $raw | from json
        let tool_input = $parsed | get -o tool_input | default {}
        {
            file_path: ($tool_input | get -o file_path | default "")
            content: ($tool_input | get -o content | default "")
        }
    } catch {
        { file_path: "", content: "" }
    }
}

# Output approve response as JSON
def approve [] {
    { action: "approve" } | to json | print
    exit 0
}

# Output deny response with reason and exit
def deny [reason: string] {
    {
        action: "deny"
        message: $reason
    } | to json | print
    exit 2
}

# Check syntax using nu --commands
# Returns: record with valid (bool) and errors (list<string>)
def check-syntax [content: string] {
    # Write content to temp file for checking
    let temp_file = $"/tmp/nu-validate-($nu.pid)-($content | hash md5 | str substring 0..8).nu"

    try {
        $content | save --force $temp_file
    } catch {
        return { valid: false, errors: ["Failed to write temporary file for validation"] }
    }

    # Use nu --commands to validate syntax
    let result = do { ^nu --commands $"source '($temp_file)'" } | complete

    # Cleanup temp file
    try { rm --force $temp_file } catch { }

    if $result.exit_code == 0 {
        return { valid: true, errors: [] }
    }

    # Parse error output for actionable messages
    let error_output = $"($result.stderr | default '')\n($result.stdout | default '')" | str trim
    let errors = parse-syntax-errors $error_output

    { valid: false, errors: $errors }
}

# Parse syntax error output into actionable messages
def parse-syntax-errors [output: string] {
    let lines = $output | lines | where { |l| $l | str trim | str length | $in > 0 }

    mut errors = []
    mut current_error = ""
    mut current_line = null

    for line in $lines {
        let trimmed = $line | str trim

        # Skip diagnostic box drawing
        if ($trimmed =~ '^[╭╮╯╰│─]+$') {
            continue
        }

        # Extract line numbers from patterns like "15 |" or ":15:"
        let line_match = $trimmed | parse -r '(?:^|:)(\d+)(?:\s*[│|]|:)' | get -o 0
        if $line_match != null {
            $current_line = ($line_match | get capture0 | into int)
        }

        # Capture error messages (lines with error indicators)
        if ($trimmed | str contains "Error:") or ($trimmed | str starts-with "x") or ($trimmed | str starts-with "×") {
            let msg = $trimmed
                | str replace -r '^.*[×✗x]\\s*' ''
                | str replace -r '^Error:\\s*' ''
                | str trim

            if ($msg | str length) > 0 {
                let location = if $current_line != null { $"Line ($current_line): " } else { "" }
                $errors = ($errors | append $"($location)($msg)")
            }
        }

        # Capture help/hint messages
        if ($trimmed | str starts-with "help:") or ($trimmed | str starts-with "hint:") {
            let suggestion = $trimmed
                | str replace -r '^(?:help|hint):\\s*' ''
                | str trim
            if ($suggestion | str length) > 0 and ($errors | is-not-empty) {
                let last_idx = ($errors | length) - 1
                let last_error = $errors | get $last_idx
                $errors = ($errors | drop 1 | append $"($last_error) (Hint: ($suggestion))")
            }
        }
    }

    # If no structured errors found, use raw output
    if ($errors | is-empty) and ($output | str length) > 0 {
        $errors = [$"Syntax error: ($output | str substring 0..200)"]
    }

    $errors
}

# Find export def declarations and check for type annotations
# Returns: list of violations with line numbers
def check-type-annotations [content: string] {
    let lines = $content | lines
    mut violations = []

    for idx in 0..<($lines | length) {
        let line = $lines | get $idx
        let line_num = $idx + 1
        let trimmed = $line | str trim

        # Match export def declarations
        if ($trimmed | str starts-with "export def ") {
            # Extract function name
            let name = $trimmed
                | str replace "export def " ""
                | split row " "
                | first
                | str replace "[" ""
                | str replace "\"" ""

            # Get complete signature (may span multiple lines)
            let signature = $lines
                | skip $idx
                | take 10
                | str join " "

            # Find where the function body starts
            let before_brace = $signature | split row "{" | first

            # Check for return type annotation (-> type)
            if not ($before_brace | str contains "->") {
                $violations = ($violations | append {
                    severity: $SEVERITY_CRITICAL
                    line: $line_num
                    rule: "missing_return_type"
                    message: $"Export function '($name)' missing return type annotation"
                    suggestion: "Add '-> return_type' before the opening brace (e.g., -> string, -> list<record>, -> nothing)"
                })
            }

            # Check parameter types
            let param_section = $before_brace | parse -r '\[([^\]]*)\]' | get -o 0 | get -o capture0 | default ""
            if ($param_section | str length) > 0 {
                let params = $param_section | split row "," | each { |p| $p | str trim }
                for param in $params {
                    # Skip flags (--flag), empty, comments
                    if ($param | str starts-with "--") or ($param | str starts-with "-") or ($param | is-empty) or ($param | str starts-with "#") {
                        continue
                    }
                    # Skip rest parameters (...rest)
                    if ($param | str starts-with "...") {
                        continue
                    }
                    # Check if param has type annotation (name: type)
                    if not ($param | str contains ":") {
                        let param_name = $param | split row " " | first | str replace "$" ""
                        $violations = ($violations | append {
                            severity: $SEVERITY_CRITICAL
                            line: $line_num
                            rule: "missing_param_type"
                            message: $"Parameter '($param_name)' in '($name)' missing type annotation"
                            suggestion: $"Add type annotation: ($param_name): <type> (e.g., string, int, path, list<string>)"
                        })
                    }
                }
            }
        }
    }

    $violations
}

# Check for documentation comments before export def
# Returns: list of violations with line numbers
def check-documentation [content: string] {
    let lines = $content | lines
    mut violations = []

    for idx in 0..<($lines | length) {
        let line = $lines | get $idx | str trim
        let line_num = $idx + 1

        if ($line | str starts-with "export def ") {
            let name = $line
                | str replace "export def " ""
                | split row " "
                | first
                | str replace "[" ""
                | str replace "\"" ""

            # Look backwards for documentation comment
            let has_doc = if $idx > 0 {
                let prev_lines = $lines | take $idx | reverse | take 10
                mut found = false

                for prev in $prev_lines {
                    let prev_trim = $prev | str trim
                    # Found a doc comment (# but not #!)
                    if ($prev_trim | str starts-with "#") and not ($prev_trim | str starts-with "#!") {
                        $found = true
                        break
                    }
                    # Empty line - continue looking
                    if ($prev_trim | is-empty) {
                        continue
                    }
                    # Non-empty, non-comment line - stop
                    break
                }
                $found
            } else {
                false
            }

            if not $has_doc {
                $violations = ($violations | append {
                    severity: $SEVERITY_REQUIRED
                    line: $line_num
                    rule: "missing_documentation"
                    message: $"Export function '($name)' missing documentation comment"
                    suggestion: "Add a # comment above the function describing its purpose"
                })
            }
        }
    }

    $violations
}

# Check for CLI violations (basic checks that don't require file on disk)
# Returns: list of violations
def check-cli-violations [content: string] {
    let lines = $content | lines
    mut violations = []

    # Track if we've seen a main function
    mut has_main = false
    mut main_line = 0
    mut main_has_help = false

    for idx in 0..<($lines | length) {
        let line = $lines | get $idx
        let line_num = $idx + 1
        let trimmed = $line | str trim

        # Check for main function
        if ($trimmed | str starts-with "def main") {
            $has_main = true
            $main_line = $line_num

            # Get full signature
            let signature = $lines | skip $idx | take 10 | str join " "
            let before_brace = $signature | split row "{" | first

            # Check for --help flag
            if ($before_brace | str contains "--help") or ($before_brace | str contains "-h") {
                $main_has_help = true
            }
        }

        # Check for hardcoded secrets (basic patterns)
        let secret_patterns = ["api_key", "apikey", "secret_key", "password", "token", "bearer"]
        for pattern in $secret_patterns {
            if ($trimmed | str downcase | str contains $pattern) {
                # Only flag if it looks like assignment with literal value
                if ($trimmed | str contains "=") and not ($trimmed | str contains "$env") {
                    if ($trimmed | str contains '"') or ($trimmed | str contains "'") {
                        $violations = ($violations | append {
                            severity: $SEVERITY_WARNING
                            line: $line_num
                            rule: "hardcoded_secret"
                            message: $"Possible hardcoded secret detected (($pattern))"
                            suggestion: "Use environment variables: $env.VAR_NAME"
                        })
                        break
                    }
                }
            }
        }

        # Check for common anti-patterns
        # Using | where with single item check (should use | any or | all)
        if ($trimmed =~ '\|\s*where\s+') and ($trimmed =~ '\|\s*length\s*==\s*1') {
            $violations = ($violations | append {
                severity: $SEVERITY_WARNING
                line: $line_num
                rule: "inefficient_pattern"
                message: "Consider using '| any { }' instead of '| where ... | length == 1'"
                suggestion: "Use '| any { <condition> }' for boolean checks"
            })
        }
    }

    # Check main function requirements
    if $has_main and not $main_has_help {
        $violations = ($violations | append {
            severity: $SEVERITY_REQUIRED
            line: $main_line
            rule: "missing_help_flag"
            message: "Main command should include --help flag for CLI discoverability"
            suggestion: "Add '--help (-h)' parameter to main function"
        })
    }

    $violations
}

# Format violations into actionable error message
def format-violations [violations: list<record>, file_path: string] {
    let critical = $violations | where severity == $SEVERITY_CRITICAL
    let required = $violations | where severity == $SEVERITY_REQUIRED
    let warnings = $violations | where severity == $SEVERITY_WARNING

    mut msg = $"Nushell code validation failed for ($file_path | path basename):\n\n"

    if ($critical | is-not-empty) {
        $msg = $msg + "CRITICAL (blocking):\n"
        for v in $critical {
            $msg = $msg + $"  * Line ($v.line): ($v.message)\n"
            $msg = $msg + $"    Fix: ($v.suggestion)\n"
        }
        $msg = $msg + "\n"
    }

    if ($required | is-not-empty) {
        $msg = $msg + "REQUIRED:\n"
        for v in $required {
            $msg = $msg + $"  * Line ($v.line): ($v.message)\n"
            $msg = $msg + $"    Fix: ($v.suggestion)\n"
        }
        $msg = $msg + "\n"
    }

    if ($warnings | is-not-empty) {
        $msg = $msg + "WARNINGS:\n"
        for v in $warnings {
            $msg = $msg + $"  * Line ($v.line): ($v.message)\n"
            $msg = $msg + $"    Fix: ($v.suggestion)\n"
        }
        $msg = $msg + "\n"
    }

    # Add summary
    let total = $violations | length
    $msg = $msg + $"Total: ($critical | length) critical, ($required | length) required, ($warnings | length) warnings\n"

    # Add quick fix examples
    $msg = $msg + "\nQuick fixes:\n"
    $msg = $msg + "  - Return type: export def name [...] -> string {\n"
    $msg = $msg + "  - Param type:  export def name [arg: string] -> string {\n"
    $msg = $msg + "  - Documentation: # Description of what function does\n"
    $msg = $msg + "  - Help flag:   def main [--help (-h)] -> nothing {"

    $msg
}

# Main validation logic - receives raw input string
def run-validation [raw_input: string] {
    let input = parse-input $raw_input

    # Skip non-Nushell files
    if not ($input.file_path | str ends-with ".nu") {
        approve
    }

    # Skip empty content
    if ($input.content | is-empty) {
        approve
    }

    mut all_violations = []

    # 1. Check syntax validity (critical - blocks everything else)
    let syntax_result = check-syntax $input.content
    if not $syntax_result.valid {
        let error_msg = $"SYNTAX ERROR in ($input.file_path | path basename):\n\n"
            + ($syntax_result.errors | each { |e| $"  * ($e)" } | str join "\n")
            + "\n\nFix syntax errors before proceeding."
        deny $error_msg
    }

    # 2. Check type annotations on exports
    let type_violations = check-type-annotations $input.content
    $all_violations = ($all_violations | append $type_violations)

    # 3. Check documentation on exports
    let doc_violations = check-documentation $input.content
    $all_violations = ($all_violations | append $doc_violations)

    # 4. Check CLI violations
    let cli_violations = check-cli-violations $input.content
    $all_violations = ($all_violations | append $cli_violations)

    # Determine if we should block
    let critical_count = $all_violations | where severity == $SEVERITY_CRITICAL | length
    let required_count = $all_violations | where severity == $SEVERITY_REQUIRED | length

    # Block on critical violations; warn but allow on required/warnings
    if $critical_count > 0 {
        let error_msg = format-violations $all_violations $input.file_path
        deny $error_msg
    }

    # For required violations, we deny to enforce CLI guidelines
    if $required_count > 0 {
        let error_msg = format-violations $all_violations $input.file_path
        deny $error_msg
    }

    # All checks passed or only warnings
    approve
}

# Entry point - read from stdin and validate
def main [] {
    # Nothing to do here - called only when run as script
}

# Execute: read stdin and run validation
let stdin_input = (open --raw /dev/stdin | into string | str trim)
run-validation $stdin_input
