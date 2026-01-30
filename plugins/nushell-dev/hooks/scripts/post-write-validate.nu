#!/usr/bin/env nu
# post-write-validate.nu - Comprehensive post-write validation
#
# Orchestrates all validation tools and aggregates results.
# This is the main entry point for PostToolUse hooks.
#
# Input: JSON via stdin with tool_input.file_path or tool_result.file_path
# Output: Exit 0 (pass) or Exit 2 with systemMessage JSON (fail)
#
# Author: Daniel Bodnar
# Created: 2025-01-29

use aggregate-report.nu [aggregate, make-result, make-error]

# Get the plugin root directory
def get-plugin-root []: nothing -> string {
    $env.CLAUDE_PLUGIN_ROOT? | default (
        $env.FILE_PWD | path dirname | path dirname
    )
}

# Run syntax-check.nu and transform output
def run-syntax-check [file: path]: nothing -> record {
    let plugin_root = get-plugin-root
    let script = $"($plugin_root)/hooks/scripts/syntax-check.nu"

    if not ($script | path exists) {
        return (make-result "syntax-check" [] [] --file ($file | into string))
    }

    let result = try {
        ^nu $script $file | from json
    } catch {
        return (make-result "syntax-check" [] [] --file ($file | into string))
    }

    # Transform to aggregate-report format
    let all_issues = $result.errors? | default [] | each { |e|
        make-error ($e.line? | default 0) ($e.message? | default "Unknown error") --severity (
            if ($e.type? | default "") == "syntax_error" { "critical" } else { "warning" }
        ) --fix ($e.suggestion? | default "")
    }

    let errors = $all_issues | where severity in ["critical", "error"]
    let warnings = $all_issues | where severity not-in ["critical", "error"]

    make-result "syntax-check" $errors $warnings --file ($file | into string)
}

# Run lint-check.nu and transform output
def run-lint-check [file: path]: nothing -> record {
    let plugin_root = get-plugin-root
    let script = $"($plugin_root)/hooks/scripts/lint-check.nu"

    if not ($script | path exists) {
        return (make-result "lint-check" [] [] --file ($file | into string))
    }

    let result = try {
        ^nu $script $file | from json
    } catch {
        return (make-result "lint-check" [] [] --file ($file | into string))
    }

    # Transform to aggregate-report format
    let issues = $result.issues? | default [] | each { |i|
        make-error ($i.line? | default 0) ($i.message? | default "Unknown issue") --severity ($i.severity? | default "warning") --fix ($i.suggestion? | default "")
    }

    let errors = $issues | where severity in ["error", "critical"]
    let warnings = $issues | where severity not-in ["error", "critical"]

    make-result "lint-check" $errors $warnings --file ($file | into string)
}

# Run format-check.nu and transform output
def run-format-check [file: path]: nothing -> record {
    let plugin_root = get-plugin-root
    let script = $"($plugin_root)/hooks/scripts/format-check.nu"

    if not ($script | path exists) {
        return (make-result "format-check" [] [] --file ($file | into string))
    }

    let result = try {
        ^nu $script $file | from json
    } catch {
        return (make-result "format-check" [] [] --file ($file | into string))
    }

    # If not available or already formatted, no issues
    if ($result.available? | default true) == false {
        return (make-result "format-check" [] [] --file ($file | into string))
    }

    if ($result.formatted? | default true) {
        return (make-result "format-check" [] [] --file ($file | into string))
    }

    # File needs formatting - create a style warning
    let suggestions = $result.suggestions? | default ["Run 'nufmt <file>' to auto-format"]
    let warnings = [
        (make-error 0 "File is not properly formatted" --severity "style" --fix ($suggestions | str join "; "))
    ]

    make-result "format-check" [] $warnings --file ($file | into string)
}

# Run ide-check.nu and transform output
def run-ide-check [file: path]: nothing -> record {
    let plugin_root = get-plugin-root
    let script = $"($plugin_root)/hooks/scripts/ide-check.nu"

    if not ($script | path exists) {
        return (make-result "ide-check" [] [] --file ($file | into string))
    }

    let result = try {
        ^nu $script $file | from json
    } catch {
        return (make-result "ide-check" [] [] --file ($file | into string))
    }

    # If not available, return empty
    if ($result.available? | default true) == false {
        return (make-result "ide-check" [] [] --file ($file | into string))
    }

    # Transform diagnostics to aggregate-report format
    let diagnostics = $result.diagnostics? | default []
    let issues = $diagnostics | where severity != "hint" | each { |d|
        let line_num = if ($d.location? | default null) != null {
            $d.location.line? | default 0
        } else if ($d.span? | default null) != null {
            0  # Span-based, no line number
        } else {
            0
        }

        make-error $line_num ($d.message? | default "IDE diagnostic") --severity ($d.severity? | default "warning")
    }

    let errors = $issues | where severity == "error"
    let warnings = $issues | where severity != "error"

    make-result "ide-check" $errors $warnings --file ($file | into string)
}

# Format the validation report for Claude
def format-validation-report [file: path, report: record]: nothing -> string {
    let filename = $file | path basename

    mut msg = $"Nushell Validation Issues: ($filename)\n"

    if ($report.critical | length) > 0 {
        $msg = $msg + "\nCRITICAL ERRORS (blocking):\n"
        for issue in $report.critical {
            let line_info = if ($issue.line? | default 0) > 0 { $"Line ($issue.line): " } else { "" }
            $msg = $msg + $"  ($line_info)($issue.message)\n"
            if ($issue.fix? | default "") != "" {
                $msg = $msg + $"    Fix: ($issue.fix)\n"
            }
        }
    }

    if ($report.warnings | length) > 0 {
        $msg = $msg + "\nWARNINGS:\n"
        for issue in $report.warnings {
            let line_info = if ($issue.line? | default 0) > 0 { $"Line ($issue.line): " } else { "" }
            $msg = $msg + $"  ($line_info)($issue.message)\n"
        }
    }

    if ($report.style | length) > 0 {
        $msg = $msg + "\nSTYLE ISSUES:\n"
        for issue in $report.style {
            $msg = $msg + $"  ($issue.message)\n"
        }
    }

    $msg = $msg + $"\nSummary: ($report.summary)\n"
    $msg = $msg + $"\nRun '/nushell-dev:cli-check ($file) --fix' to auto-fix issues."

    $msg
}

# Main entry point
def main [] {
    # Read JSON input from stdin
    let input = $in | from json

    # Extract file path (support both tool_input and tool_result)
    let file_path = $input.tool_input?.file_path? | default ($input.tool_result?.file_path? | default "")

    # Only process .nu files
    if not ($file_path | str ends-with ".nu") {
        exit 0
    }

    # Verify file exists
    if not ($file_path | path exists) {
        exit 0
    }

    # Run all validators in parallel and collect results
    let results = ["syntax" "lint" "format" "ide"]
        | par-each { |validator|
            match $validator {
                "syntax" => { run-syntax-check $file_path }
                "lint" => { run-lint-check $file_path }
                "format" => { run-format-check $file_path }
                "ide" => { run-ide-check $file_path }
                _ => { make-result $validator [] [] --file $file_path }
            }
        }

    # Aggregate all results
    let report = aggregate $results

    # If all passed, exit cleanly
    if $report.passed {
        exit 0
    }

    # Format and output the error message
    let msg = format-validation-report $file_path $report

    # Output for Claude Code (escape quotes for JSON)
    let escaped_msg = $msg | str replace -a '"' '\"' | str replace -a "\n" "\\n"
    print $'{"systemMessage": "($escaped_msg)"}'

    # Exit with code 2 to signal feedback to Claude
    exit 2
}
