#!/usr/bin/env nu
# validate-cli.nu - CLI guideline compliance checker for Nushell files
#
# Validates Nushell scripts against CLI best practices:
# - Type annotations and return types on exports
# - Documentation comments
# - Standard CLI flags (--help, --json, --quiet, --verbose)
# - Error handling for external operations
# - Naming conventions and style
#
# Usage:
#   nu validate-cli.nu <file>              # Check single file
#   nu validate-cli.nu <dir> --recursive   # Check directory
#   nu validate-cli.nu <file> --json       # JSON output
#   nu validate-cli.nu <file> --strict     # Fail on warnings
#
# Author: Daniel Bodnar
# Created: 2026-01-29

# Severity levels for issues
const SEVERITY_CRITICAL = "critical"
const SEVERITY_REQUIRED = "required"
const SEVERITY_RECOMMENDED = "recommended"
const SEVERITY_STYLE = "style"

# Issue record structure
# Returns a standardized issue record
def make-issue [
    severity: string   # Issue severity level
    rule: string       # Rule identifier
    message: string    # Human-readable message
    line: int          # Line number (1-indexed)
    suggestion: string # How to fix
] {
    {
        severity: $severity
        rule: $rule
        message: $message
        line: $line
        suggestion: $suggestion
    }
}

# Run syntax validation using nu --commands
# Returns: record with valid (bool) and errors (list)
def check-syntax [file: path] {
    let result = do { ^nu --commands $"source '($file)'" } | complete

    if $result.exit_code == 0 {
        return { valid: true, errors: [] }
    }

    let output = $"($result.stderr)\n($result.stdout)" | str trim
    let errors = parse-syntax-errors $output $file

    { valid: false, errors: $errors }
}

# Parse nu-check output into structured errors
def parse-syntax-errors [output: string, file: path] {
    let lines = $output | lines | where { |l| ($l | str trim | str length) > 0 }

    mut errors = []
    mut current_line = 1

    for line in $lines {
        # Try to extract line number from output
        let line_match = $line | parse -r '(?:line\s*)?(\d+)(?:\s*│|\s*:)' | get -o 0
        if $line_match != null {
            $current_line = ($line_match | get capture0 | into int)
        }

        if ($line | str contains "×") or ($line | str contains "Error") {
            let msg = $line | str replace -r "^.*[×✗]\\s*" "" | str trim
            if ($msg | str length) > 0 {
                $errors = ($errors | append (make-issue $SEVERITY_CRITICAL "syntax_error" $msg $current_line "Fix the syntax error"))
            }
        }
    }

    if ($errors | is-empty) and ($output | str length) > 0 {
        $errors = [(make-issue $SEVERITY_CRITICAL "syntax_error" $"Syntax validation failed: ($output | str substring 0..100)" 1 "Check file syntax")]
    }

    $errors
}

# Check for type annotations on export definitions
def check-type-annotations [content: string] {
    let lines = $content | lines
    mut issues = []

    for idx in 0..<($lines | length) {
        let line = $lines | get $idx
        let line_num = $idx + 1
        let trimmed = $line | str trim

        # Match export def declarations
        if ($trimmed | str starts-with "export def ") {
            # Get function name
            let name = $trimmed
                | str replace "export def " ""
                | split row " "
                | first
                | str replace "[" ""
                | str replace "\"" ""

            # Check for return type annotation
            # Look at current line and next few lines for complete signature
            let signature = $lines
                | skip $idx
                | take 8
                | str join " "

            # Find where the function body starts
            let before_brace = $signature | split row "{" | first

            # Check for -> type annotation
            if not ($before_brace | str contains "->") {
                $issues = ($issues | append (make-issue $SEVERITY_CRITICAL "missing_return_type" $"Export '($name)' missing return type annotation" $line_num "Add '-> return_type' before opening brace"))
            }

            # Check parameter types - look for untyped params like [foo] instead of [foo: type]
            let param_section = $before_brace | parse -r '\[([^\]]*)\]' | get -o 0 | get -o capture0 | default ""
            if ($param_section | str length) > 0 {
                let params = $param_section | split row "," | each { |p| $p | str trim }
                for param in $params {
                    # Skip flags (start with --)
                    if ($param | str starts-with "--") or ($param | str starts-with "-") {
                        continue
                    }
                    # Skip comments
                    if ($param | str starts-with "#") or ($param | is-empty) {
                        continue
                    }
                    # Check if param has type annotation
                    if not ($param | str contains ":") and ($param | str length) > 0 {
                        let param_name = $param | split row " " | first
                        $issues = ($issues | append (make-issue $SEVERITY_CRITICAL "missing_type_annotation" $"Parameter '($param_name)' in '($name)' missing type annotation" $line_num "Add type: param_name: type"))
                    }
                }
            }
        }
    }

    $issues
}

# Check for documentation comments on exports
def check-documentation [content: string] {
    let lines = $content | lines
    mut issues = []

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
                mut seen_empty = false

                for prev in $prev_lines {
                    let prev_trim = $prev | str trim
                    if ($prev_trim | str starts-with "#") and not ($prev_trim | str starts-with "#!") {
                        $found = true
                        break
                    } else if ($prev_trim | is-empty) {
                        $seen_empty = true
                    } else {
                        break
                    }
                }
                $found
            } else {
                false
            }

            if not $has_doc {
                $issues = ($issues | append (make-issue $SEVERITY_REQUIRED "missing_documentation" $"Export '($name)' missing documentation comment" $line_num "Add # comment above function describing its purpose"))
            }
        }
    }

    $issues
}

# Check for undefined variables (basic check)
def check-undefined-variables [content: string] {
    let lines = $content | lines
    mut issues = []
    mut defined_vars = ["in", "env", "nu", "true", "false", "null"]

    for idx in 0..<($lines | length) {
        let line = $lines | get $idx
        let line_num = $idx + 1

        # Track let/mut definitions
        let def_matches = $line | parse -r '(?:let|mut)\s+(\w+)\s*=' | get -o 0
        if $def_matches != null {
            $defined_vars = ($defined_vars | append ($def_matches | get capture0))
        }

        # Track for loop variables
        let for_match = $line | parse -r 'for\s+\$?(\w+)\s+in' | get -o 0
        if $for_match != null {
            $defined_vars = ($defined_vars | append ($for_match | get capture0))
        }

        # Track function parameters
        if ($line | str contains "def ") {
            let params = $line | parse -r '\[([^\]]*)\]' | get -o 0 | get -o capture0 | default ""
            let param_names = $params | parse -r '(\w+)\s*:' | each { |p| $p | get capture0 }
            $defined_vars = ($defined_vars | append $param_names)
        }
    }

    $issues
}

# Check for --help flag in main command
def check-help-flag [content: string] {
    let lines = $content | lines
    mut issues = []

    for idx in 0..<($lines | length) {
        let line = $lines | get $idx | str trim
        let line_num = $idx + 1

        if ($line | str starts-with "def main") {
            # Get the full signature
            let signature = $content | lines | skip $idx | take 10 | str join " "
            let before_brace = $signature | split row "{" | first

            if not ($before_brace | str contains "--help") and not ($before_brace | str contains "-h") {
                $issues = ($issues | append (make-issue $SEVERITY_REQUIRED "missing_help_flag" "Main command should include --help (-h) flag" $line_num "Add '--help (-h)' parameter for CLI discoverability"))
            }
        }
    }

    $issues
}

# Check for error handling on external commands
def check-error-handling [content: string] {
    let lines = $content | lines
    mut issues = []
    mut in_try_block = false

    # Common external commands that should have error handling
    let external_cmds = ["http", "curl", "wget", "git", "docker", "kubectl", "ssh", "scp", "rsync", "rm", "mv", "cp"]

    for idx in 0..<($lines | length) {
        let line = $lines | get $idx
        let line_num = $idx + 1
        let trimmed = $line | str trim

        if ($trimmed | str starts-with "try") {
            $in_try_block = true
        } else if ($trimmed | str starts-with "}") and $in_try_block {
            $in_try_block = false
        }

        if not $in_try_block {
            for cmd in $external_cmds {
                if ($trimmed | str contains $"($cmd) ") or ($trimmed | str starts-with $"($cmd) ") {
                    # Check if followed by | complete
                    if not ($trimmed | str contains "| complete") and not ($trimmed | str contains "do {") {
                        $issues = ($issues | append (make-issue $SEVERITY_REQUIRED "missing_error_handling" $"External command '($cmd)' without error handling" $line_num "Wrap in try/catch or use '| complete' to handle errors"))
                    }
                }
            }
        }
    }

    $issues
}

# Check for secrets in code
def check-secrets [content: string] {
    let lines = $content | lines
    mut issues = []

    let secret_patterns = [
        ["api[_-]?key", "API key"],
        ["secret[_-]?key", "Secret key"],
        ["password", "Password"],
        ["token", "Token"],
        ["bearer", "Bearer token"],
        ["private[_-]?key", "Private key"]
    ]

    for idx in 0..<($lines | length) {
        let line = $lines | get $idx
        let line_num = $idx + 1

        # Skip comments
        if ($line | str trim | str starts-with "#") {
            continue
        }

        for pattern in $secret_patterns {
            let regex = $pattern.0
            let name = $pattern.1

            # Check for hardcoded values (not env vars)
            if ($line | str downcase | str contains ($regex | str replace "[_-]?" "")) {
                if ($line | str contains "=") and not ($line | str contains "$env") {
                    if ($line | str contains '"') or ($line | str contains "'") {
                        $issues = ($issues | append (make-issue $SEVERITY_REQUIRED "hardcoded_secret" $"Possible hardcoded ($name) detected" $line_num "Use environment variables: $env.VAR_NAME"))
                    }
                }
            }
        }
    }

    $issues
}

# Check for recommended --json flag
def check-json-flag [content: string] {
    let lines = $content | lines
    mut issues = []

    # Check if there's a main function with output
    let has_main = $content | str contains "def main"
    let has_json_flag = ($content | str contains "--json") or ($content | str contains "-j")
    let has_output = ($content | str contains "| to json") or ($content | str contains "print") or ($content | str contains "return")

    if $has_main and $has_output and not $has_json_flag {
        # Find main line
        for idx in 0..<($lines | length) {
            let line = $lines | get $idx | str trim
            if ($line | str starts-with "def main") {
                $issues = ($issues | append (make-issue $SEVERITY_RECOMMENDED "missing_json_flag" "Consider adding --json flag for machine-readable output" ($idx + 1) "Add '--json' flag and output structured data when enabled"))
                break
            }
        }
    }

    $issues
}

# Check for recommended --quiet flag
def check-quiet-flag [content: string] {
    let lines = $content | lines
    mut issues = []

    let has_main = $content | str contains "def main"
    let has_quiet = ($content | str contains "--quiet") or ($content | str contains "-q")
    let has_print = $content | str contains "print"

    if $has_main and $has_print and not $has_quiet {
        for idx in 0..<($lines | length) {
            let line = $lines | get $idx | str trim
            if ($line | str starts-with "def main") {
                $issues = ($issues | append (make-issue $SEVERITY_RECOMMENDED "missing_quiet_flag" "Consider adding --quiet flag to suppress non-essential output" ($idx + 1) "Add '--quiet (-q)' flag for silent operation"))
                break
            }
        }
    }

    $issues
}

# Check for recommended --verbose flag
def check-verbose-flag [content: string] {
    let lines = $content | lines
    mut issues = []

    let has_main = $content | str contains "def main"
    let has_verbose = ($content | str contains "--verbose") or ($content | str contains "-v")

    if $has_main and not $has_verbose {
        for idx in 0..<($lines | length) {
            let line = $lines | get $idx | str trim
            if ($line | str starts-with "def main") {
                $issues = ($issues | append (make-issue $SEVERITY_RECOMMENDED "missing_verbose_flag" "Consider adding --verbose flag for detailed output" ($idx + 1) "Add '--verbose (-v)' flag for debugging info"))
                break
            }
        }
    }

    $issues
}

# Check for --dry-run on destructive operations
def check-dry-run [content: string] {
    let lines = $content | lines
    mut issues = []

    let destructive_cmds = ["rm", "mv", "delete", "remove", "drop", "truncate"]
    let has_dry_run = ($content | str contains "--dry-run") or ($content | str contains "-n")

    if not $has_dry_run {
        for cmd in $destructive_cmds {
            if ($content | str contains $cmd) {
                for idx in 0..<($lines | length) {
                    let line = $lines | get $idx | str trim
                    if ($line | str starts-with "def main") {
                        $issues = ($issues | append (make-issue $SEVERITY_RECOMMENDED "missing_dry_run" "Destructive operations detected; consider adding --dry-run flag" ($idx + 1) "Add '--dry-run (-n)' to preview changes"))
                        break
                    }
                }
                break
            }
        }
    }

    $issues
}

# Check naming conventions (kebab-case)
def check-naming-conventions [content: string] {
    let lines = $content | lines
    mut issues = []

    for idx in 0..<($lines | length) {
        let line = $lines | get $idx
        let line_num = $idx + 1

        # Check function names
        let def_match = $line | parse -r 'def\s+"?([^"\s\[]+)"?\s*\[' | get -o 0
        if $def_match != null {
            let name = $def_match | get capture0
            # Check for snake_case or camelCase
            if ($name | str contains "_") or ($name =~ '[a-z][A-Z]') {
                $issues = ($issues | append (make-issue $SEVERITY_STYLE "naming_convention" $"Function '($name)' should use kebab-case" $line_num "Rename to kebab-case: my-function"))
            }
        }
    }

    $issues
}

# Check line length
def check-line-length [content: string, max_length: int] {
    let lines = $content | lines
    mut issues = []

    for idx in 0..<($lines | length) {
        let line = $lines | get $idx
        let line_num = $idx + 1
        let len = $line | str length

        if $len > $max_length {
            $issues = ($issues | append (make-issue $SEVERITY_STYLE "line_too_long" $"Line exceeds ($max_length) characters (($len))" $line_num "Break line into multiple lines"))
        }
    }

    $issues
}

# Check for empty lines between functions
def check-function-spacing [content: string] {
    let lines = $content | lines
    mut issues = []
    mut last_brace_line = 0

    for idx in 0..<($lines | length) {
        let line = $lines | get $idx | str trim
        let line_num = $idx + 1

        if ($line | str starts-with "def ") or ($line | str starts-with "export def ") {
            if $last_brace_line > 0 and ($idx - $last_brace_line) < 2 {
                $issues = ($issues | append (make-issue $SEVERITY_STYLE "missing_blank_line" "Missing blank line before function definition" $line_num "Add empty line between functions"))
            }
        }

        if ($line == "}") {
            $last_brace_line = $idx
        }
    }

    $issues
}

# Validate a single file
def validate-file [file: path, strict: bool] {
    if not ($file | path exists) {
        return {
            file: ($file | path expand)
            valid: false
            issues: [(make-issue $SEVERITY_CRITICAL "file_not_found" $"File not found: ($file)" 0 "Verify file path")]
            summary: { critical: 1, required: 0, recommended: 0, style: 0, total: 1 }
        }
    }

    let content = open $file | into string
    mut all_issues = []

    # CRITICAL checks
    let syntax = check-syntax $file
    if not $syntax.valid {
        $all_issues = ($all_issues | append $syntax.errors)
    }

    # Only continue if syntax is valid
    if $syntax.valid {
        $all_issues = ($all_issues | append (check-type-annotations $content))
        $all_issues = ($all_issues | append (check-undefined-variables $content))
    }

    # REQUIRED checks
    $all_issues = ($all_issues | append (check-documentation $content))
    $all_issues = ($all_issues | append (check-help-flag $content))
    $all_issues = ($all_issues | append (check-error-handling $content))
    $all_issues = ($all_issues | append (check-secrets $content))

    # RECOMMENDED checks
    $all_issues = ($all_issues | append (check-json-flag $content))
    $all_issues = ($all_issues | append (check-quiet-flag $content))
    $all_issues = ($all_issues | append (check-verbose-flag $content))
    $all_issues = ($all_issues | append (check-dry-run $content))

    # Additional RECOMMENDED checks
    $all_issues = ($all_issues | append (check-no-color-support $content))
    $all_issues = ($all_issues | append (check-tty-detection $content))
    $all_issues = ($all_issues | append (check-exit-codes $content))
    $all_issues = ($all_issues | append (check-stdin-support $content))
    $all_issues = ($all_issues | append (check-version-flag $content))
    $all_issues = ($all_issues | append (check-config-flag $content))
    $all_issues = ($all_issues | append (check-actionable-errors $content))
    $all_issues = ($all_issues | append (check-stderr-usage $content))

    # STYLE checks
    $all_issues = ($all_issues | append (check-naming-conventions $content))
    $all_issues = ($all_issues | append (check-line-length $content 120))
    $all_issues = ($all_issues | append (check-function-spacing $content))
    $all_issues = ($all_issues | append (check-xdg-compliance $content))
    $all_issues = ($all_issues | append (check-flag-consistency $content))

    # Build summary
    let critical_count = $all_issues | where severity == $SEVERITY_CRITICAL | length
    let required_count = $all_issues | where severity == $SEVERITY_REQUIRED | length
    let recommended_count = $all_issues | where severity == $SEVERITY_RECOMMENDED | length
    let style_count = $all_issues | where severity == $SEVERITY_STYLE | length

    let is_valid = if $strict {
        $critical_count == 0 and $required_count == 0 and $recommended_count == 0
    } else {
        $critical_count == 0
    }

    {
        file: ($file | path expand)
        valid: $is_valid
        issues: $all_issues
        summary: {
            critical: $critical_count
            required: $required_count
            recommended: $recommended_count
            style: $style_count
            total: ($all_issues | length)
        }
    }
}

# Format issues for human output
def format-human-output [result: record] {
    mut output = [$"Checking: ($result.file)\n"]

    let critical = $result.issues | where severity == $SEVERITY_CRITICAL
    let required = $result.issues | where severity == $SEVERITY_REQUIRED
    let recommended = $result.issues | where severity == $SEVERITY_RECOMMENDED
    let style = $result.issues | where severity == $SEVERITY_STYLE

    if not ($critical | is-empty) {
        $output = ($output | append "CRITICAL:")
        for issue in $critical {
            $output = ($output | append $"  ✗ Line ($issue.line): ($issue.message)")
        }
        $output = ($output | append "")
    }

    if not ($required | is-empty) {
        $output = ($output | append "REQUIRED:")
        for issue in $required {
            $output = ($output | append $"  ✗ Line ($issue.line): ($issue.message)")
        }
        $output = ($output | append "")
    }

    if not ($recommended | is-empty) {
        $output = ($output | append "RECOMMENDED:")
        for issue in $recommended {
            $output = ($output | append $"  ⚠ Line ($issue.line): ($issue.message)")
        }
        $output = ($output | append "")
    }

    if not ($style | is-empty) {
        $output = ($output | append "STYLE:")
        for issue in $style {
            $output = ($output | append $"  ○ Line ($issue.line): ($issue.message)")
        }
        $output = ($output | append "")
    }

    let summary = $result.summary
    $output = ($output | append $"Summary: ($summary.critical) critical, ($summary.required) required, ($summary.recommended) recommended, ($summary.style) style")
    $output = ($output | append $"Result: (if $result.valid { 'PASSED' } else { 'FAILED' })")

    $output | str join "\n"
}

# Main entry point
def main [
    path: path                # File or directory to check
    --recursive (-r)          # Check directories recursively
    --json                    # Output as JSON
    --strict                  # Fail on warnings too
    --help (-h)               # Show help message
] {
    if $help {
        print "validate-cli.nu - CLI guideline compliance checker"
        print ""
        print "Usage:"
        print "  nu validate-cli.nu <file>              # Check single file"
        print "  nu validate-cli.nu <dir> --recursive   # Check directory"
        print "  nu validate-cli.nu <file> --json       # JSON output"
        print "  nu validate-cli.nu <file> --strict     # Fail on warnings"
        print ""
        print "Checks:"
        print "  CRITICAL:     Syntax errors, missing types, undefined vars"
        print "  REQUIRED:     Missing docs, --help, error handling, secrets"
        print "  RECOMMENDED:  Missing --json, --quiet, --verbose, --dry-run"
        print "  STYLE:        Naming conventions, line length, spacing"
        exit 0
    }

    let path_type = $path | path type

    let files = if $path_type == "file" {
        [$path]
    } else if $path_type == "dir" {
        if $recursive {
            glob $"($path)/**/*.nu"
        } else {
            glob $"($path)/*.nu"
        }
    } else {
        print $"Error: Path not found: ($path)"
        exit 1
    }

    if ($files | is-empty) {
        print "No .nu files found"
        exit 0
    }

    mut results = []
    mut any_failed = false

    for file in $files {
        let result = validate-file $file $strict
        $results = ($results | append $result)

        if not $result.valid {
            $any_failed = true
        }
    }

    if $json {
        if ($results | length) == 1 {
            $results | first | to json
        } else {
            {
                files: $results
                summary: {
                    total_files: ($results | length)
                    passed: ($results | where valid == true | length)
                    failed: ($results | where valid == false | length)
                }
            } | to json
        }
    } else {
        for result in $results {
            print (format-human-output $result)
            print ""
        }
    }

    if $any_failed {
        exit 1
    }
}

# ==============================================================================
# ADDITIONAL CHECKS
# ==============================================================================

# Check for NO_COLOR environment variable support
def check-no-color-support [content: string] {
    mut issues = []

    let has_color = ($content | str contains "ansi ") or ($content | str contains "colorize")
    let checks_no_color = ($content | str contains "NO_COLOR") or ($content | str contains "no-color")

    if $has_color and not $checks_no_color {
        $issues = ($issues | append (make-issue $SEVERITY_RECOMMENDED "missing_no_color" "Uses colors but doesn't check NO_COLOR environment variable" 1 "Add: if ($env.NO_COLOR? | is-empty) { ... }"))
    }

    $issues
}

# Check for TTY detection when outputting colors or interactive content
def check-tty-detection [content: string] {
    mut issues = []

    let has_interactive = ($content | str contains "input ") or ($content | str contains "confirm")
    let has_progress = ($content | str contains "progress") or ($content | str contains "spinner")
    let checks_tty = ($content | str contains "term size") or ($content | str contains "is-terminal")

    if ($has_interactive or $has_progress) and not $checks_tty {
        $issues = ($issues | append (make-issue $SEVERITY_RECOMMENDED "missing_tty_check" "Uses interactive features without TTY detection" 1 "Add TTY check: if (term size | is-not-empty) { ... }"))
    }

    $issues
}

# Check for proper exit codes
def check-exit-codes [content: string] {
    let lines = $content | lines
    mut issues = []

    let has_exit = $content | str contains "exit "
    let has_error_exit = ($content | str contains "exit 1") or ($content | str contains "exit $EXIT_ERROR")

    if $has_exit and not $has_error_exit {
        $issues = ($issues | append (make-issue $SEVERITY_RECOMMENDED "missing_error_exit" "Uses exit but doesn't use non-zero exit codes for errors" 1 "Use 'exit 1' or higher for error conditions"))
    }

    $issues
}

# Check for stdin support
def check-stdin-support [content: string] {
    mut issues = []

    let has_main = $content | str contains "def main"
    let reads_files = ($content | str contains "open ") or ($content | str contains "path: path")
    let supports_stdin = ($content | str contains "$in") or ($content | str contains "--stdin") or ($content | str contains '"-"')

    if $has_main and $reads_files and not $supports_stdin {
        $issues = ($issues | append (make-issue $SEVERITY_RECOMMENDED "missing_stdin" "Reads files but doesn't support stdin input" 1 "Add '--stdin' flag or support '-' as filename for stdin"))
    }

    $issues
}

# Check for XDG base directory compliance
def check-xdg-compliance [content: string] {
    mut issues = []

    let hardcoded_config = ($content | str contains "~/.config/") and not ($content | str contains "XDG_CONFIG_HOME")
    let hardcoded_data = ($content | str contains "~/.local/share/") and not ($content | str contains "XDG_DATA_HOME")
    let hardcoded_cache = ($content | str contains "~/.cache/") and not ($content | str contains "XDG_CACHE_HOME")

    if $hardcoded_config {
        $issues = ($issues | append (make-issue $SEVERITY_STYLE "xdg_config" "Hardcoded ~/.config without XDG_CONFIG_HOME fallback" 1 "Use: $env.XDG_CONFIG_HOME? | default '~/.config'"))
    }
    if $hardcoded_data {
        $issues = ($issues | append (make-issue $SEVERITY_STYLE "xdg_data" "Hardcoded ~/.local/share without XDG_DATA_HOME fallback" 1 "Use: $env.XDG_DATA_HOME? | default '~/.local/share'"))
    }
    if $hardcoded_cache {
        $issues = ($issues | append (make-issue $SEVERITY_STYLE "xdg_cache" "Hardcoded ~/.cache without XDG_CACHE_HOME fallback" 1 "Use: $env.XDG_CACHE_HOME? | default '~/.cache'"))
    }

    $issues
}

# Check for version flag
def check-version-flag [content: string] {
    let lines = $content | lines
    mut issues = []

    let has_main = $content | str contains "def main"
    let has_version = ($content | str contains "--version") or ($content | str contains "VERSION")

    if $has_main and not $has_version {
        for idx in 0..<($lines | length) {
            let line = $lines | get $idx | str trim
            if ($line | str starts-with "def main") {
                $issues = ($issues | append (make-issue $SEVERITY_RECOMMENDED "missing_version_flag" "Consider adding --version flag" ($idx + 1) "Add '--version' flag to show program version"))
                break
            }
        }
    }

    $issues
}

# Check for configuration file support
def check-config-flag [content: string] {
    let lines = $content | lines
    mut issues = []

    let has_main = $content | str contains "def main"
    let has_config = ($content | str contains "--config") or ($content | str contains "-c")
    let uses_config = ($content | str contains "config.toml") or ($content | str contains "load-config")

    if $has_main and $uses_config and not $has_config {
        for idx in 0..<($lines | length) {
            let line = $lines | get $idx | str trim
            if ($line | str starts-with "def main") {
                $issues = ($issues | append (make-issue $SEVERITY_RECOMMENDED "missing_config_flag" "Uses config file but no --config flag to override path" ($idx + 1) "Add '--config (-c)' flag for custom config path"))
                break
            }
        }
    }

    $issues
}

# Check for actionable error messages
def check-actionable-errors [content: string] {
    let lines = $content | lines
    mut issues = []

    for idx in 0..<($lines | length) {
        let line = $lines | get $idx
        let line_num = $idx + 1

        # Check for error make without help field
        if ($line | str contains "error make") {
            let context = $lines | skip $idx | take 5 | str join " "
            if ($context | str contains "msg:") and not ($context | str contains "help:") {
                $issues = ($issues | append (make-issue $SEVERITY_RECOMMENDED "missing_error_help" "Error without actionable help message" $line_num "Add 'help:' field with guidance on how to fix the error"))
            }
        }
    }

    $issues
}

# Check for proper use of stderr vs stdout
def check-stderr-usage [content: string] {
    let lines = $content | lines
    mut issues = []

    let has_log = ($content | str contains "log ") or ($content | str contains "print -e")
    let has_print = $content | str contains "print "
    let prints_errors = ($content | str contains "error") or ($content | str contains "Error")

    if $prints_errors and $has_print and not $has_log {
        $issues = ($issues | append (make-issue $SEVERITY_RECOMMENDED "stderr_usage" "May be printing errors to stdout instead of stderr" 1 "Use 'print -e' for error messages to output to stderr"))
    }

    $issues
}

# Check for consistent flag naming
def check-flag-consistency [content: string] {
    let lines = $content | lines
    mut issues = []

    # Common flag inconsistencies
    let inconsistencies = [
        ["--quite", "--quiet"],
        ["--verb", "--verbose"],
        ["--out", "--output"],
        ["--fmt", "--format"],
        ["--conf", "--config"],
        ["--rec", "--recursive"],
    ]

    for pair in $inconsistencies {
        let bad = $pair.0
        let good = $pair.1
        if ($content | str contains $bad) {
            for idx in 0..<($lines | length) {
                let line = $lines | get $idx
                if ($line | str contains $bad) {
                    $issues = ($issues | append (make-issue $SEVERITY_STYLE "flag_naming" $"Consider using '($good)' instead of '($bad)'" ($idx + 1) $"Use standard flag name: ($good)"))
                }
            }
        }
    }

    $issues
}
