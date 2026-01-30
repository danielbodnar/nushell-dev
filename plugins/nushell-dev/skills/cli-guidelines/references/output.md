# CLI Output Reference

> Based on [clig.dev](https://clig.dev) - Command Line Interface Guidelines

## Human-Readable Output by Default

When stdout is a terminal (TTY), output should be human-readable:

```nushell
# Detect if running in terminal
def is-tty [] -> bool {
    (term size | get columns) > 0
}

def list-items [] {
    let items = (get-data)

    if (is-tty) {
        # Pretty output for humans
        $items | table
    } else {
        # Machine-friendly for pipes
        $items | to json
    }
}
```

**Human-readable principles:**
- Format data as tables with alignment
- Use colors to highlight important information
- Truncate long values with ellipsis
- Add headers and context
- Show counts and summaries

---

## Machine-Readable Output (--json)

Provide `--json` flag for programmatic access:

```nushell
def my-command [
    --json   # Output as JSON
] -> any {
    let result = {
        status: "success"
        count: 42
        items: ["a", "b", "c"]
    }

    if $json {
        $result | to json
    } else {
        print $"Found ($result.count) items"
        $result.items | table
    }
}
```

**Machine output guidelines:**
- Use `--json` for JSON output (most common)
- Consider `--yaml`, `--toml`, `--csv` if appropriate
- Output to stdout, errors to stderr
- Include all relevant data, not just display fields
- Use consistent schema across versions
- Return proper exit codes

### Nushell Output Formats

```nushell
# JSON output
$data | to json

# JSON with formatting
$data | to json --indent 2

# YAML output
$data | to yaml

# TOML output
$data | to toml

# CSV output
$data | to csv

# TSV output
$data | to tsv

# Markdown table
$data | to md
```

---

## Plain Output (--plain)

Provide `--plain` for simple, unformatted output:

```nushell
def list-files [
    path: path = "."
    --plain        # One file per line, no formatting
] {
    let files = (ls $path | get name)

    if $plain {
        $files | str join "\n"
    } else {
        ls $path | table
    }
}
```

**Plain output use cases:**
- Feeding into other commands
- Parsing with simple tools (cut, awk)
- Scripts that expect line-by-line input
- Minimal environments without JSON support

---

## Success Output

Commands should acknowledge success briefly:

```nushell
def deploy [
    target: string
    --quiet (-q)
] {
    # Do deployment...

    if not $quiet {
        print $"Deployed to ($target) successfully."
    }
}
```

**Success output guidelines:**
- Confirm what happened
- Be brief (one line typically)
- Include relevant details (target, count, location)
- Respect `--quiet` flag
- Don't output nothing - silence is ambiguous

```nushell
# Good: acknowledges what happened
print "Created config.toml"
print "Installed 5 packages"
print "Deployed to production (v1.2.3)"

# Bad: too verbose for success
print "The operation completed successfully. Your file has been created at the specified location. Thank you for using this tool."

# Bad: silent (was it successful? did it do anything?)
# (no output)
```

---

## State Changes

Explain what changed in the system:

```nushell
def update-config [
    key: string
    value: string
    --verbose (-v)
] {
    let old_value = (get-config $key)
    set-config $key $value

    if $verbose {
        print $"Updated ($key): ($old_value) -> ($value)"
    } else {
        print $"Updated ($key)"
    }
}
```

**State change output:**
- Show before and after when relevant
- Summarize multiple changes
- Provide detail with `--verbose`
- Make it easy to verify the change worked

---

## Current State Visibility

Make it easy to see current configuration:

```nushell
def show-config [] {
    let config = (load-config)

    print "Current Configuration:"
    print $"  Database: ($config.database)"
    print $"  Log Level: ($config.log_level)"
    print $"  Cache: ($config.cache_enabled | if $in { 'enabled' } else { 'disabled' })"
}

# Or as structured output
def get-config [
    --json
] {
    let config = (load-config)

    if $json {
        $config | to json
    } else {
        $config | table
    }
}
```

---

## Suggesting Next Commands

Help users discover their next action:

```nushell
def init-project [
    name: string
] {
    mkdir $name
    # Create files...

    print $"Created project '($name)'"
    print ""
    print "Next steps:"
    print $"  cd ($name)"
    print "  npm install"
    print "  npm run dev"
}

def git-status-helper [] {
    let status = (git status --porcelain)

    if ($status | is-empty) {
        print "Working tree clean"
    } else {
        print $status
        print ""
        print "Suggested commands:"
        print "  git add -A        # Stage all changes"
        print "  git diff          # Review changes"
        print "  git stash         # Stash changes"
    }
}
```

**Next command suggestions:**
- Show after significant operations
- Be context-aware
- Include the full command (copy-paste ready)
- Keep to 2-4 suggestions max

---

## ASCII Art for Information Density

Use ASCII/Unicode for visual representations:

```nushell
def show-disk-usage [] {
    let usage = (df -h | lines | skip 1 | first)
    let percent = 75  # Example

    let bar_width = 30
    let filled = ($percent * $bar_width / 100 | math floor)
    let empty = $bar_width - $filled

    let bar = $"[('=' | str repeat $filled)(' ' | str repeat $empty)]"

    print $"Disk Usage: ($bar) ($percent)%"
}

# Output: Disk Usage: [======================        ] 75%
```

```nushell
# Progress indicator
def show-progress [current: int, total: int] {
    let percent = ($current * 100 / $total)
    let width = 40
    let filled = ($percent * $width / 100 | math floor)

    let bar = $"[('#' | str repeat $filled)('-' | str repeat ($width - $filled))]"
    print -n $"\r($bar) ($percent)% (($current)/($total))"
}
```

---

## Color Usage

Use color intentionally and meaningfully:

```nushell
# Nushell ansi codes
def success [msg: string] {
    print $"(ansi green)SUCCESS:(ansi reset) ($msg)"
}

def warning [msg: string] {
    print $"(ansi yellow)WARNING:(ansi reset) ($msg)"
}

def error-msg [msg: string] {
    print $"(ansi red)ERROR:(ansi reset) ($msg)"
}

def info [msg: string] {
    print $"(ansi blue)INFO:(ansi reset) ($msg)"
}
```

**Color meaning conventions:**
- **Red:** Errors, failures, destructive actions
- **Yellow:** Warnings, caution
- **Green:** Success, additions, safe
- **Blue:** Information, neutral highlights
- **Cyan:** Paths, URLs, identifiers
- **Magenta:** Special emphasis
- **Bold:** Headings, important values
- **Dim:** Secondary information, metadata

### Available Ansi Codes in Nushell

```nushell
# Colors
ansi red
ansi green
ansi blue
ansi yellow
ansi magenta
ansi cyan
ansi white
ansi black

# Modifiers
ansi bold
ansi dim
ansi italic
ansi underline
ansi blink
ansi reverse
ansi hidden
ansi strikethrough

# Reset
ansi reset

# Combine them
print $"(ansi bold)(ansi red)CRITICAL(ansi reset): Something went wrong"
```

---

## Disable Color Conditions

Respect user preferences and environment:

```nushell
def should-use-color [] -> bool {
    # Check NO_COLOR environment variable
    if "NO_COLOR" in $env {
        return false
    }

    # Check --no-color flag (handle in command)

    # Check TERM
    if ($env.TERM? | default "" ) == "dumb" {
        return false
    }

    # Check if stdout is a TTY
    if not (is-tty) {
        return false
    }

    true
}

def colored-print [msg: string, color: string] {
    if (should-use-color) {
        print $"(ansi ($color))($msg)(ansi reset)"
    } else {
        print $msg
    }
}
```

**Color disable triggers:**
- `NO_COLOR` environment variable is set
- `--no-color` flag is passed
- `TERM=dumb`
- stdout is not a TTY (piped output)
- `CLICOLOR=0` (some tools)

---

## No Animations in Non-TTY

Disable progress bars and animations when piped:

```nushell
def process-with-progress [items: list] {
    let total = ($items | length)
    let use_progress = (is-tty)

    $items | enumerate | each { |it|
        if $use_progress {
            # Show progress bar
            let pct = (($it.index + 1) * 100 / $total)
            print -n $"\rProcessing: ($pct)%"
        }

        # Do work
        process-item $it.item
    }

    if $use_progress {
        print ""  # Newline after progress
    }
}
```

**Animation guidelines:**
- Only animate when stdout is a TTY
- Clear animation before final output
- Provide non-animated fallback
- Consider `--progress` flag for explicit control

---

## Symbols and Emoji

Use symbols carefully and purposefully:

```nushell
# Status indicators
let success_mark = "OK"   # or "+" or "[OK]"
let error_mark = "FAIL"     # or "X" or "[FAIL]"
let warning_mark = "WARN"   # or "!" or "[WARN]"
let info_mark = "INFO"      # or "i" or "[INFO]"

# Or Unicode if terminal supports it
let success_mark = "\u{2713}"  # Check mark
let error_mark = "\u{2717}"    # X mark
let warning_mark = "\u{26A0}"  # Warning sign
let info_mark = "\u{2139}"     # Info symbol

# Use consistently
def check-item [name: string, ok: bool] {
    let mark = if $ok { $success_mark } else { $error_mark }
    print $"($mark) ($name)"
}
```

**Symbol/emoji guidelines:**
- Be consistent throughout your tool
- Provide ASCII fallbacks for restricted terminals
- Don't rely on emoji for meaning (add text too)
- Test across different terminal emulators
- Avoid excessive emoji - it looks unprofessional

---

## Using Pagers for Long Output

Pipe long output through a pager:

```nushell
def show-log [
    --no-pager    # Disable pager
] {
    let content = (open log.txt)
    let lines = ($content | lines | length)

    # Use pager for long output in TTY
    if not $no_pager and (is-tty) and $lines > 50 {
        $content | less  # or bat, or $env.PAGER
    } else {
        print $content
    }
}
```

**Pager guidelines:**
- Respect `$PAGER` environment variable
- Default to `less` if available
- Only use pager when output exceeds terminal height
- Provide `--no-pager` flag
- Don't use pager when piped (non-TTY)

---

## Stdout vs Stderr Routing

Route output correctly:

```nushell
# Main output goes to stdout (default in Nushell)
def process [] {
    let result = (compute)
    $result  # Returns to stdout
}

# Progress/status goes to stderr
def process-verbose [] {
    print -e "Starting processing..."   # stderr
    let result = (compute)
    print -e "Processing complete"      # stderr
    $result                             # stdout
}

# Errors always go to stderr
def might-fail [] {
    if (something-wrong) {
        print -e "Error: something went wrong"
        exit 1
    }
}
```

**Output routing rules:**
- **stdout:** Primary output (data, results)
- **stderr:** Progress, status messages, errors

```nushell
# print -e sends to stderr
print -e "This goes to stderr"

# Regular print/return goes to stdout
print "This goes to stdout"
$data  # Returns to stdout
```

---

## Table Customization

Nushell's table command is highly customizable:

```nushell
# Default table
$data | table

# Compact table
$data | table --collapse

# Expand nested data
$data | table --expand

# Limit width
$data | table --width 80

# Flatten for simple output
$data | flatten | table
```

### Custom Table Formatting

```nushell
# Select and rename columns
$data | select name size modified | rename Name Size Modified | table

# Add computed columns
$data | insert size_human { |row| $row.size | into filesize } | table

# Sort before display
$data | sort-by size --reverse | table
```

---

## Error Output Patterns

Structure error messages consistently:

```nushell
def report-error [
    msg: string
    --hint: string
    --code: int
] {
    print -e $"(ansi red)error(ansi reset): ($msg)"

    if ($hint | is-not-empty) {
        print -e $"(ansi blue)hint(ansi reset): ($hint)"
    }

    if ($code | is-not-empty) {
        exit $code
    }
}

# Usage
report-error "File not found: config.toml" --hint "Run 'init' to create configuration" --code 1
```

**Error message structure:**
1. Error label (error:)
2. Brief description of what went wrong
3. Specific details (filename, value, etc.)
4. Hint for resolution (if applicable)
5. Appropriate exit code

---

## Verbosity Levels

Implement consistent verbosity control:

```nushell
def my-command [
    --verbose (-v)     # More output
    --quiet (-q)       # Less output
    --debug (-d)       # Maximum output
] {
    # Determine verbosity level
    let verbosity = if $debug { 3 }
        else if $verbose { 2 }
        else if $quiet { 0 }
        else { 1 }  # default

    # Level 3: Debug (everything)
    if $verbosity >= 3 {
        print -e "DEBUG: Entering function with args..."
    }

    # Level 2: Verbose (detailed progress)
    if $verbosity >= 2 {
        print -e "Processing file 1 of 10..."
    }

    # Level 1: Normal (important info only)
    if $verbosity >= 1 {
        print "Completed successfully"
    }

    # Level 0: Quiet (errors only)
    # (no output for success)
}
```

**Verbosity levels:**
- **0 (--quiet):** Errors only
- **1 (default):** Normal operation messages
- **2 (--verbose):** Detailed progress
- **3 (--debug):** Everything, including internal state

---

## Summary

1. **Human-readable by default** in terminal, machine-readable when piped
2. **Provide --json** for programmatic access
3. **Acknowledge success** briefly (don't be silent)
4. **Explain state changes** - show what happened
5. **Suggest next commands** when helpful
6. **Use color meaningfully** with proper disable conditions
7. **Respect NO_COLOR** and TTY detection
8. **Route correctly:** stdout for data, stderr for messages
9. **Use pagers** for long output in interactive mode
10. **Implement verbosity levels** with -v, -q, -d flags
