#!/usr/bin/env nu
# ide-check.nu - nu --ide-check integration
#
# Provides IDE-style diagnostics for Nushell files.
# Uses Nushell's built-in IDE checking capabilities.
#
# Usage:
#   nu ide-check.nu <file-path>
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

    # Get file content for span calculation
    let content = open $file --raw
    let span_end = ($content | str length)

    # Run nu --ide-check
    # Format: nu --ide-check <span_end> file.nu
    let result = do { ^nu --ide-check $span_end $file } | complete

    if $result.exit_code != 0 {
        return [{
            severity: "error"
            rule: "IDE-CHECK"
            line: 0
            message: ($result.stderr | str trim)
            fixable: false
        }]
    }

    # Parse IDE output (JSON lines format)
    let output = $result.stdout | str trim

    if ($output | str length) == 0 {
        return []
    }

    # Each line is a separate JSON object
    # IDE check output types:
    # - "hint": type inference info (typename, position)
    # - "diagnostic"/"error"/"warning": actual issues (message, span/position)
    try {
        $output
            | lines
            | where {|l| ($l | str trim | str length) > 0}
            | each { |line|
                let diag = try {
                    $line | from json
                } catch {
                    null
                }

                if $diag == null {
                    null
                } else {
                    let diag_type = $diag | get type? | default "unknown"

                    # Skip "hint" types (type inference) - only report actual diagnostics
                    if $diag_type == "hint" {
                        null
                    } else {
                        # Extract line number from span or position
                        let pos = $diag | get span? | default ($diag | get position? | default null)
                        let line_num = if $pos != null {
                            # Calculate line number from byte offset
                            let span_start = $pos.start? | default 0
                            let prefix = $content | str substring 0..$span_start
                            ($prefix | lines | length)
                        } else {
                            0
                        }

                        # Determine severity from type or explicit severity field
                        let severity = $diag | get severity? | default (
                            match $diag_type {
                                "error" | "diagnostic" => "error"
                                "warning" => "warning"
                                _ => "warning"
                            }
                        )

                        {
                            severity: ($severity | str downcase)
                            rule: "IDE-DIAG"
                            line: $line_num
                            message: ($diag.message? | default ($diag.msg? | default $"($diag_type): unknown issue"))
                            fixable: false
                        }
                    }
                }
            }
            | where {|d| $d != null}
    } catch {
        []
    }
}
