# CLI Error Handling Reference

> Based on [clig.dev](https://clig.dev/) guidelines adapted for Nushell

---

## Philosophy: Errors as Documentation

Errors are not failures—they are **documentation opportunities**. When your CLI produces
an error, it's a chance to teach the user something and guide them toward success.

### The Conversational Approach

Think of error messages as a conversation with the user:

**Bad:** `EACCES: permission denied`
**Good:** `Can't write to file. Try running: chmod +w filename.txt`

**Bad:** `Error: ENOENT`
**Good:** `File not found: config.toml. Did you mean config.toml.example?`

**Bad:** `Invalid argument`
**Good:** `Expected a number for --timeout, but got 'abc'. Example: --timeout 30`

---

## Core Principles

### 1. Catch and Rewrite Errors

Never pass through raw system errors. Intercept them and translate to human language:

```nushell
# BAD: Raw error passthrough
def read-config [] {
    open $config_path  # Throws cryptic ENOENT
}

# GOOD: Caught and rewritten
def read-config [] {
    let config_path = $env.XDG_CONFIG_HOME?
        | default ($nu.home-path | path join ".config")
        | path join "myapp" "config.nuon"

    if not ($config_path | path exists) {
        error make {
            msg: "Configuration file not found"
            help: $"Expected config at: ($config_path)\nRun 'myapp init' to create one"
        }
    }

    try {
        open $config_path
    } catch { |err|
        error make {
            msg: "Failed to parse configuration"
            help: $"Check syntax in ($config_path)\nOriginal error: ($err.msg)"
        }
    }
}
```

### 2. Signal-to-Noise Ratio

Minimize irrelevant output. Users should see only what helps them:

```nushell
# BAD: Too much noise
def process-files [files: list<path>] {
    for file in $files {
        print $"Processing ($file)..."
        print $"Opening file..."
        print $"Reading contents..."
        print $"Parsing data..."
        print $"Writing output..."
        print $"Done with ($file)"
    }
}

# GOOD: Quiet by default, verbose when needed
def process-files [
    files: list<path>
    --verbose (-v)  # Show detailed progress
] {
    for file in $files {
        if $verbose { print $"Processing ($file)..." }

        # Do the work silently
        let result = process-single $file

        # Only report errors or final summary
    }

    print $"Processed ($files | length) files"
}
```

### 3. Put Important Information Last

The last line is what users see in their terminal. Make it count:

```nushell
# BAD: Important info buried
def deploy [] {
    print "Deployment URL: https://app.example.com"
    print "Building assets..."
    print "Uploading files..."
    print "Configuring DNS..."
    print "Done!"
}

# GOOD: Important info at the end
def deploy [] {
    print "Building assets..."
    print "Uploading files..."
    print "Configuring DNS..."
    print ""
    print $"(ansi green)Deployed successfully!(ansi reset)"
    print $"URL: (ansi cyan)https://app.example.com(ansi reset)"
}
```

---

## Nushell Error Patterns

### Basic Error Creation

```nushell
# Simple error
error make { msg: "Something went wrong" }

# Error with help text
error make {
    msg: "Invalid port number"
    help: "Port must be between 1 and 65535"
}

# Error with source location (for parsers/validators)
error make {
    msg: "Syntax error in configuration"
    label: {
        text: "unexpected token here"
        span: (metadata $input).span
    }
    help: "Expected a string value, got a number"
}
```

### Try/Catch Pattern

```nushell
# Basic try/catch
def safe-operation [] {
    try {
        risky-operation
    } catch { |err|
        print -e $"(ansi red)Error:(ansi reset) ($err.msg)"
        exit 1
    }
}

# With error transformation
def fetch-data [url: string] {
    try {
        http get $url
    } catch { |err|
        let help = if ($err.msg | str contains "connection refused") {
            "Check if the server is running and the URL is correct"
        } else if ($err.msg | str contains "timeout") {
            "The server took too long to respond. Try again or check your network"
        } else {
            "Check your network connection and try again"
        }

        error make {
            msg: $"Failed to fetch data from ($url)"
            help: $help
        }
    }
}
```

### Nested Error Handling

```nushell
def complex-operation [input: path] {
    # Validate input exists
    if not ($input | path exists) {
        error make {
            msg: $"Input file not found: ($input)"
            help: "Provide a valid file path"
        }
    }

    # Try to read
    let data = try {
        open $input
    } catch { |err|
        error make {
            msg: "Cannot read input file"
            help: $"Check file permissions: ls -la ($input)"
        }
    }

    # Try to process
    let result = try {
        $data | process-data
    } catch { |err|
        error make {
            msg: "Failed to process data"
            help: $"Invalid format. ($err.msg)"
        }
    }

    $result
}
```

---

## Color Usage in Errors

### Use Red Intentionally and Sparingly

Red means danger/error. Don't overuse it:

```nushell
# Define semantic colors
const ERROR_COLOR = "red"
const WARNING_COLOR = "yellow"
const SUCCESS_COLOR = "green"
const INFO_COLOR = "cyan"
const DIM_COLOR = "dark_gray"

# Error output helper
def print-error [msg: string, --help: string] {
    print -e $"(ansi $ERROR_COLOR)error:(ansi reset) ($msg)"
    if $help != null {
        print -e $"(ansi $DIM_COLOR)  help:(ansi reset) ($help)"
    }
}

# Warning output helper
def print-warning [msg: string] {
    print -e $"(ansi $WARNING_COLOR)warning:(ansi reset) ($msg)"
}

# Example usage
def validate-config [config: record] {
    mut warnings = []

    if $config.timeout? == null {
        $warnings = ($warnings | append "No timeout set, using default of 30s")
    }

    if $config.api_key? == null {
        print-error "API key is required" --help "Set MY_APP_API_KEY environment variable"
        exit 1
    }

    for warning in $warnings {
        print-warning $warning
    }
}
```

### Respect NO_COLOR

Always check for the NO_COLOR environment variable:

```nushell
# Color-aware printing
def colored [text: string, color: string] {
    if ($env.NO_COLOR? | is-empty) {
        $"(ansi $color)($text)(ansi reset)"
    } else {
        $text
    }
}

def print-error [msg: string] {
    print -e $"(colored 'error:' red) ($msg)"
}
```

---

## Grouping Similar Errors

When multiple similar errors occur, group them:

```nushell
# BAD: Spammy repeated errors
def validate-files [files: list<path>] {
    for file in $files {
        if not ($file | path exists) {
            print -e $"Error: ($file) not found"
        }
    }
}

# GOOD: Grouped errors
def validate-files [files: list<path>] {
    let missing = $files | where { not ($in | path exists) }

    if ($missing | length) > 0 {
        print -e $"(ansi red)Error:(ansi reset) ($missing | length) files not found:"
        for file in $missing {
            print -e $"  - ($file)"
        }
        exit 1
    }
}
```

---

## Unexpected Errors and Bug Reports

### Provide Debug Information

When an unexpected error occurs, give users everything they need:

```nushell
def unexpected-error [err: record] {
    print -e $"
(ansi red)Unexpected error occurred(ansi reset)

This is likely a bug. Please report it with the following information:

(ansi yellow)Error:(ansi reset)
  ($err.msg)

(ansi yellow)Context:(ansi reset)
  Version: (version | get version)
  OS: (sys host | get name)
  Shell: ($env.SHELL? | default 'unknown')

(ansi yellow)Debug info:(ansi reset)
  ($err | to nuon)

(ansi cyan)Report at:(ansi reset) https://github.com/user/repo/issues/new
"
}
```

### Easy Bug Reporting with Pre-populated URLs

```nushell
def bug-report-url [err: record] {
    let title = $err.msg | url encode
    let body = $"
**Error:** ($err.msg)

**Version:** (version | get version)
**OS:** (sys host | get name)

**Steps to reproduce:**
1.

**Expected behavior:**


**Actual behavior:**

" | url encode

    $"https://github.com/user/repo/issues/new?title=($title)&body=($body)"
}

def handle-unexpected [err: record] {
    let url = bug-report-url $err
    print -e $"
(ansi red)Unexpected error:(ansi reset) ($err.msg)

Please report this bug:
  (ansi cyan)($url)(ansi reset)

Or copy this command:
  (ansi dim)open '($url)'(ansi reset)
"
}
```

---

## Exit Codes

### Basic Rules

- **0**: Success
- **1**: General error
- **2**: Misuse of command (bad arguments)
- **126**: Command not executable
- **127**: Command not found
- **128+N**: Fatal error signal N

### Mapping Exit Codes to Failure Modes

```nushell
# Define exit codes
const EXIT_SUCCESS = 0
const EXIT_ERROR = 1
const EXIT_USAGE = 2
const EXIT_CONFIG = 78
const EXIT_IO = 74
const EXIT_UNAVAILABLE = 69

# Exit with appropriate code
def exit-with-error [code: int, msg: string] {
    print -e $"(ansi red)error:(ansi reset) ($msg)"
    exit $code
}

# Example usage
def main [
    --config (-c): path
] {
    # Check usage
    if $config == null {
        exit-with-error $EXIT_USAGE "Missing required --config flag"
    }

    # Check config
    if not ($config | path exists) {
        exit-with-error $EXIT_CONFIG $"Config file not found: ($config)"
    }

    # Try operation
    try {
        do-work $config
    } catch { |err|
        if ($err.msg | str contains "connection") {
            exit-with-error $EXIT_UNAVAILABLE "Service unavailable"
        } else {
            exit-with-error $EXIT_ERROR $err.msg
        }
    }

    exit $EXIT_SUCCESS
}
```

---

## Complete Error Handling Example

```nushell
#!/usr/bin/env nu

# A well-behaved CLI with proper error handling

const VERSION = "1.0.0"

def main [
    input: path           # Input file to process
    --output (-o): path   # Output file (default: stdout)
    --verbose (-v)        # Show detailed progress
    --format (-f): string = "json"  # Output format
] {
    # Validate input exists
    if not ($input | path exists) {
        error make {
            msg: $"Input file not found: ($input)"
            help: "Check the path and try again"
        }
    }

    # Validate format
    let valid_formats = ["json", "yaml", "csv"]
    if $format not-in $valid_formats {
        error make {
            msg: $"Invalid format: ($format)"
            help: $"Supported formats: ($valid_formats | str join ', ')"
        }
    }

    # Process with error handling
    let result = try {
        if $verbose { print -e "Reading input..." }
        let data = open $input

        if $verbose { print -e "Processing..." }
        let processed = $data | transform-data

        if $verbose { print -e "Formatting output..." }
        format-output $processed $format
    } catch { |err|
        error make {
            msg: "Processing failed"
            help: $err.msg
        }
    }

    # Output
    if $output != null {
        try {
            $result | save -f $output
            if $verbose { print -e $"Saved to ($output)" }
        } catch {
            error make {
                msg: $"Cannot write to ($output)"
                help: "Check file permissions and disk space"
            }
        }
    } else {
        print $result
    }
}
```

---

## Summary Checklist

- [ ] Catch system errors and rewrite them in plain language
- [ ] Include actionable suggestions in error messages
- [ ] Keep output quiet by default, verbose when requested
- [ ] Put the most important information last
- [ ] Use color intentionally (red = error only)
- [ ] Respect NO_COLOR environment variable
- [ ] Group similar errors under single headers
- [ ] Provide debug info for unexpected errors
- [ ] Make bug reporting easy with pre-populated URLs
- [ ] Use meaningful exit codes consistently
- [ ] Test error paths as thoroughly as success paths
