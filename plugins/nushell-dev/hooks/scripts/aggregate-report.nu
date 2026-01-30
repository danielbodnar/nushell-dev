#!/usr/bin/env nu
# aggregate-report.nu - Combine validation results into a unified report
#
# This script aggregates results from all validation scripts (syntax check,
# linting, MCP evaluation) into a user-friendly formatted report.
#
# Usage:
#   Called by post-write-validate.nu or standalone:
#   nu aggregate-report.nu <results-json>
#
# Input: JSON array of validation results
# Returns: Aggregated report with categorized issues
#
# Author: Daniel Bodnar
# Created: 2025-01-29

# Severity rankings for sorting
const SEVERITY_ORDER = {
    critical: 1,
    error: 2,
    warning: 3,
    style: 4,
    info: 5
}

# Icons for different severities (using ASCII for compatibility)
const SEVERITY_ICONS = {
    critical: "X",
    error: "X",
    warning: "!",
    style: "~",
    info: "i"
}

# Main entry point - can be called with JSON string or as a pipeline stage
def main [
    results_json?: string    # JSON array of validation results (optional)
]: [string -> record, nothing -> record] {
    # Parse input - either from argument or piped stdin
    let input = if ($results_json | is-not-empty) {
        $results_json
    } else if ($in | is-not-empty) {
        $in
    } else {
        "[]"
    }

    let results = try {
        $input | from json
    } catch {
        []
    }

    aggregate $results
}

# Aggregate validation results into unified report
#
# Parameters:
#   results: list<record> - List of validation result records
#
# Each result record should have:
#   - source: string (validator name)
#   - errors: list<record> (list of issues)
#
# Each error record should have:
#   - line: int
#   - severity: string (critical, error, warning, style, info)
#   - message: string
#   - code: string (optional - error code)
#   - fix: string (optional - suggested fix)
#
# Returns: Aggregated report record
export def aggregate [results: list<record>]: nothing -> record {
    # Flatten all errors from all validators
    let all_issues = $results
        | each { |r|
            let source = $r.source? | default "unknown"
            let errors = $r.errors? | default []
            let warnings = $r.warnings? | default []

            # Combine errors and warnings, tagging with source
            ($errors | each { |e| $e | insert source $source })
            | append ($warnings | each { |w| $w | insert source $source })
        }
        | flatten

    # Deduplicate issues (same line + similar message)
    let deduped = deduplicate-issues $all_issues

    # Categorize by severity
    let critical = $deduped | where { ($in.severity? | default "") in ["critical", "error"] }
    let warnings = $deduped | where { ($in.severity? | default "") == "warning" }
    let style = $deduped | where { ($in.severity? | default "") in ["style", "info"] }

    # Sort each category by line number
    let critical_sorted = $critical | sort-by { $in.line? | default 0 }
    let warnings_sorted = $warnings | sort-by { $in.line? | default 0 }
    let style_sorted = $style | sort-by { $in.line? | default 0 }

    # Determine overall pass/fail
    let passed = ($critical_sorted | length) == 0

    # Generate summary
    let summary = generate-summary $critical_sorted $warnings_sorted $style_sorted

    # Generate formatted message
    let message = generate-message $critical_sorted $warnings_sorted $style_sorted $passed

    # Get file path from first result if available
    let file = $results | get -o 0 | get -o file | default "unknown"

    {
        passed: $passed,
        file: $file,
        summary: $summary,
        critical: $critical_sorted,
        warnings: $warnings_sorted,
        style: $style_sorted,
        total_issues: (($critical_sorted | length) + ($warnings_sorted | length) + ($style_sorted | length)),
        message: $message
    }
}

# Deduplicate issues by line number and similar message
def deduplicate-issues [issues: list<record>]: nothing -> list<record> {
    if ($issues | length) == 0 {
        return []
    }

    mut seen = {}
    mut unique = []

    for issue in $issues {
        let line = $issue.line? | default 0
        let msg_normalized = $issue.message? | default "" | str downcase | str trim

        # Create a key from line and normalized message prefix (first 50 chars)
        let msg_prefix = if ($msg_normalized | str length) > 50 {
            $msg_normalized | str substring 0..50
        } else {
            $msg_normalized
        }
        let key = $"($line):($msg_prefix)"

        if not ($key in $seen) {
            $seen = ($seen | insert $key true)
            $unique = ($unique | append $issue)
        }
    }

    $unique
}

# Generate summary string
def generate-summary [critical: list, warnings: list, style: list]: nothing -> string {
    let c = $critical | length
    let w = $warnings | length
    let s = $style | length

    mut parts = []

    if $c > 0 {
        let label = if $c == 1 { "error" } else { "errors" }
        $parts = ($parts | append $"($c) ($label)")
    }

    if $w > 0 {
        let label = if $w == 1 { "warning" } else { "warnings" }
        $parts = ($parts | append $"($w) ($label)")
    }

    if $s > 0 {
        let label = if $s == 1 { "style issue" } else { "style issues" }
        $parts = ($parts | append $"($s) ($label)")
    }

    if ($parts | length) == 0 {
        "No issues found"
    } else {
        $parts | str join ", "
    }
}

# Generate formatted message for display
def generate-message [critical: list, warnings: list, style: list, passed: bool]: nothing -> string {
    mut lines = []

    # Header
    if $passed {
        $lines = ($lines | append "[OK] Validation Passed")
        $lines = ($lines | append "")
    } else {
        $lines = ($lines | append "[X] Validation Failed")
        $lines = ($lines | append "")
    }

    # Critical errors section
    if ($critical | length) > 0 {
        $lines = ($lines | append $"CRITICAL ERRORS \(($critical | length)\):")

        for issue in $critical {
            $lines = ($lines | append (format-issue $issue "  "))
        }

        $lines = ($lines | append "")
    }

    # Warnings section
    if ($warnings | length) > 0 {
        $lines = ($lines | append $"WARNINGS \(($warnings | length)\):")

        for issue in $warnings {
            $lines = ($lines | append (format-issue $issue "  "))
        }

        $lines = ($lines | append "")
    }

    # Style issues section
    if ($style | length) > 0 {
        $lines = ($lines | append $"STYLE \(($style | length)\):")

        for issue in $style {
            $lines = ($lines | append (format-issue $issue "  "))
        }

        $lines = ($lines | append "")
    }

    # Summary footer
    $lines = ($lines | append $"Summary: (generate-summary $critical $warnings $style)")

    # Auto-fix suggestion if there are fixable issues
    let critical_fixable = ($critical | where { ($in.fix? | is-not-empty) } | length) > 0
    let warning_fixable = ($warnings | where { ($in.fix? | is-not-empty) } | length) > 0
    let has_fixable = $critical_fixable or $warning_fixable

    if $has_fixable {
        $lines = ($lines | append "Run '/nushell-dev:cli-check <file> --fix' for auto-fixes.")
    }

    $lines | str join "\n"
}

# Format a single issue for display
def format-issue [issue: record, indent: string]: nothing -> string {
    let line_num = $issue.line? | default 0
    let message = $issue.message? | default "Unknown issue"
    let code = $issue.code? | default ""
    let fix = $issue.fix? | default ""
    let context = $issue.context? | default ""
    let source = $issue.source? | default ""

    mut lines = []

    # Main issue line
    let code_suffix = if ($code | is-not-empty) { $" [($code)]" } else { "" }
    let source_suffix = if ($source | is-not-empty) { $" \(($source)\)" } else { "" }

    $lines = ($lines | append $"($indent)Line ($line_num): ($message)($code_suffix)($source_suffix)")

    # Context (code snippet)
    if ($context | is-not-empty) {
        $lines = ($lines | append $"($indent)    -> ($context)")
    }

    # Fix suggestion
    if ($fix | is-not-empty) {
        $lines = ($lines | append $"($indent)    [Fix]: ($fix)")
    }

    $lines | str join "\n"
}

# Helper: Check if value is not empty (handles nulls gracefully)
def is-not-empty []: any -> bool {
    let val = $in
    if ($val == null) {
        false
    } else if ($val | describe) == "string" {
        ($val | str trim | str length) > 0
    } else if ($val | describe) =~ "list" {
        ($val | length) > 0
    } else {
        true
    }
}

# Export additional utilities for use by other scripts

# Create an error record with consistent structure
export def make-error [
    line: int,
    message: string,
    --severity: string = "error",
    --code: string = "",
    --fix: string = "",
    --context: string = ""
]: nothing -> record {
    {
        line: $line,
        message: $message,
        severity: $severity,
        code: $code,
        fix: $fix,
        context: $context
    }
}

# Create a validation result record
export def make-result [
    source: string,
    errors: list<record> = [],
    warnings: list<record> = [],
    --file: string = ""
]: nothing -> record {
    {
        source: $source,
        file: $file,
        errors: $errors,
        warnings: $warnings
    }
}

# Quick check: did validation pass?
export def did-pass [report: record]: nothing -> bool {
    $report.passed? | default false
}

# Get all issues sorted by line
export def all-issues [report: record]: nothing -> list<record> {
    let all = ($report.critical? | default [])
        | append ($report.warnings? | default [])
        | append ($report.style? | default [])

    $all | sort-by { $in.line? | default 0 }
}
