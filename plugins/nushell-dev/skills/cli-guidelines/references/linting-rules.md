# Linting Rules for CLI-Compliant Nushell Scripts

> Checkable rules for validating CLI compliance in Nushell scripts.
> Based on CLI Guidelines and Nushell best practices.

---

## Severity Levels

| Level | Code | Description | Behavior |
|-------|------|-------------|----------|
| **ERROR** | E | Must fix | Blocks validation |
| **WARNING** | W | Should fix | Blocks in strict mode |
| **INFO** | I | Suggestion | Never blocks |

---

## Rule Categories

1. [Help & Documentation (HELP-xxx)](#1-help--documentation-help-xxx)
2. [Arguments & Flags (ARG-xxx)](#2-arguments--flags-arg-xxx)
3. [Output (OUT-xxx)](#3-output-out-xxx)
4. [Errors (ERR-xxx)](#4-errors-err-xxx)
5. [Configuration (CFG-xxx)](#5-configuration-cfg-xxx)
6. [Robustness (ROB-xxx)](#6-robustness-rob-xxx)
7. [Style (STY-xxx)](#7-style-sty-xxx)

---

## 1. Help & Documentation (HELP-xxx)

### HELP-001: Exported commands must have documentation

**Severity:** ERROR
**Auto-fixable:** No

**Description:** All exported commands (`export def`) must have a documentation comment immediately preceding the definition.

**Good:**
```nushell
# Fetches user data from the API
#
# Returns a record containing user information including
# name, email, and account status.
export def "api get-user" [
    user_id: string  # The unique identifier for the user
] {
    # implementation
}
```

**Bad:**
```nushell
export def "api get-user" [
    user_id: string
] {
    # implementation
}
```

---

### HELP-002: Commands must support --help flag

**Severity:** INFO
**Auto-fixable:** No

**Description:** All commands should support `--help` flag. Nushell provides this automatically for properly documented commands with parameter descriptions.

**Good:**
```nushell
# Processes data files in the specified directory
export def process-data [
    path: path  # Directory containing data files
] {
    # implementation
}
# Usage: process-data --help
```

**Bad:**
```nushell
# No documentation, --help provides minimal information
export def process-data [path] {
    # implementation
}
```

---

### HELP-003: Documentation must include at least one example

**Severity:** WARNING
**Auto-fixable:** No

**Description:** Command documentation should include at least one usage example for non-trivial commands.

**Good:**
```nushell
# Converts JSON files to YAML format
#
# Examples:
#   > convert-format input.json --to yaml
#   > ls *.json | each { |f| convert-format $f.name }
export def convert-format [
    file: path        # Input file path
    --to: string      # Target format (yaml, toml, csv)
] {
    # implementation
}
```

**Bad:**
```nushell
# Converts JSON files to YAML format
export def convert-format [
    file: path
    --to: string
] {
    # implementation
}
```

---

### HELP-004: Complex commands must have usage examples in comments

**Severity:** INFO
**Auto-fixable:** No

**Description:** Commands with more than 3 parameters or complex behavior should have detailed usage documentation with multiple examples.

**Good:**
```nushell
# Synchronizes local files with remote storage
#
# This command handles bidirectional sync with conflict resolution.
# Files are compared by hash, not timestamp.
#
# Parameters:
#   source - Local directory to sync
#   dest - Remote storage URL (s3://, gs://, etc.)
#
# Examples:
#   > sync-files ./data s3://bucket/data
#   > sync-files ./data s3://bucket/data --dry-run --delete
#
# See also: upload-file, download-file
export def sync-files [
    source: path
    dest: string
    --dry-run         # Show what would be synced
    --delete          # Delete files not in source
    --exclude: list   # Patterns to exclude
] {
    # implementation
}
```

**Bad:**
```nushell
# Syncs files
export def sync-files [source dest --dry-run --delete --exclude: list] {
    # implementation
}
```

---

## 2. Arguments & Flags (ARG-xxx)

### ARG-001: Prefer flags over positional arguments

**Severity:** WARNING
**Auto-fixable:** No

**Description:** For commands with more than 2 inputs, prefer named flags over positional arguments for clarity and self-documentation.

**Good:**
```nushell
export def create-user [
    --name: string      # User's display name
    --email: string     # User's email address
    --role: string      # User role (admin, user, guest)
    --active            # Whether user is active
] {
    # implementation
}
```

**Bad:**
```nushell
export def create-user [
    name: string
    email: string
    role: string
    active: bool
] {
    # implementation
}
```

---

### ARG-002: Use standard flag names where applicable

**Severity:** WARNING
**Auto-fixable:** No

**Description:** Use conventional flag names for common operations to reduce cognitive load.

**Standard flags:**
- `--help`, `-h` - Show help
- `--version`, `-V` - Show version
- `--verbose`, `-v` - Increase verbosity
- `--quiet`, `-q` - Suppress output
- `--force`, `-f` - Force operation
- `--output`, `-o` - Output file/destination
- `--config`, `-c` - Config file path
- `--dry-run`, `-n` - Preview without executing

**Good:**
```nushell
export def deploy [
    --verbose (-v)    # Show detailed output
    --dry-run (-n)    # Preview changes without deploying
    --force (-f)      # Skip confirmation prompts
] {
    # implementation
}
```

**Bad:**
```nushell
export def deploy [
    --loud            # Show detailed output (non-standard)
    --preview         # Preview changes (use --dry-run)
    --yes             # Skip confirmation (use --force)
] {
    # implementation
}
```

---

### ARG-003: All flags must have long form (--flag)

**Severity:** ERROR
**Auto-fixable:** No

**Description:** Every flag must have a long form (`--flag`). Short forms are optional additions.

**Good:**
```nushell
export def backup [
    --output (-o): path   # Destination path
    --compress (-c)       # Enable compression
    --recursive           # Include subdirectories
] {
    # implementation
}
```

**Bad:**
```nushell
export def backup [
    -o: path    # Only short form - invalid
    -c          # Only short form - invalid
] {
    # implementation
}
```

---

### ARG-004: Common flags should have short form (-f)

**Severity:** INFO
**Auto-fixable:** No

**Description:** Frequently used flags should have single-character short forms for convenience.

**Good:**
```nushell
export def search [
    pattern: string
    --recursive (-r)      # Search subdirectories
    --ignore-case (-i)    # Case-insensitive matching
    --count (-c)          # Show match count only
] {
    # implementation
}
```

**Bad:**
```nushell
export def search [
    pattern: string
    --recursive           # Missing short form
    --ignore-case         # Missing short form
    --count               # Missing short form
] {
    # implementation
}
```

---

### ARG-005: Flags must have type annotations

**Severity:** ERROR
**Auto-fixable:** No

**Description:** All flags that accept values must have explicit type annotations.

**Good:**
```nushell
export def fetch-data [
    --url: string         # API endpoint URL
    --timeout: duration   # Request timeout
    --retries: int        # Number of retry attempts
    --headers: record     # Custom HTTP headers
] {
    # implementation
}
```

**Bad:**
```nushell
export def fetch-data [
    --url             # No type annotation
    --timeout         # No type annotation
    --retries         # No type annotation
] {
    # implementation
}
```

---

### ARG-006: Never accept secrets via flags

**Severity:** ERROR
**Auto-fixable:** No

**Description:** Sensitive data (passwords, tokens, keys) must never be accepted as command-line arguments. Use stdin, files, or environment variables instead. Command-line arguments are visible in process lists.

**Good:**
```nushell
# Authenticates with the API
#
# Token is read from stdin or MYAPP_TOKEN environment variable
export def auth-login [
    --token-file: path    # File containing auth token
] {
    let token = if $token_file != null {
        open $token_file | str trim
    } else if ($env.MYAPP_TOKEN? | is-not-empty) {
        $env.MYAPP_TOKEN
    } else {
        input --suppress-output "Enter token: "
    }
    # use $token
}
```

**Bad:**
```nushell
export def auth-login [
    --token: string       # Auth token (EXPOSED IN PROCESS LIST!)
    --password: string    # Password (EXPOSED IN PROCESS LIST!)
] {
    # implementation
}
```

---

### ARG-007: Provide sensible defaults for optional flags

**Severity:** WARNING
**Auto-fixable:** No

**Description:** Optional flags should have sensible default values documented and applied.

**Good:**
```nushell
# Compresses files with configurable settings
export def compress [
    input: path
    --level: int = 6         # Compression level (1-9, default: 6)
    --format: string = "gz"  # Output format (gz, xz, zst)
] {
    # implementation uses defaults
}
```

**Bad:**
```nushell
export def compress [
    input: path
    --level: int          # No default, unclear what happens if omitted
    --format: string      # No default
] {
    # What level is used if not specified?
}
```

---

## 3. Output (OUT-xxx)

### OUT-001: Support --json flag for machine-readable output

**Severity:** WARNING
**Auto-fixable:** No

**Description:** Commands that output data should support `--json` flag (or similar) for machine-readable output, enabling scripting and piping.

**Good:**
```nushell
# Lists active processes
export def list-processes [
    --json            # Output as JSON
] {
    let data = (ps | select name pid cpu mem)

    if $json {
        $data | to json
    } else {
        $data
    }
}
```

**Bad:**
```nushell
export def list-processes [] {
    ps | each { |p| $"($p.name): ($p.pid)" } | str join "\n"
}
```

---

### OUT-002: Use stderr for errors/diagnostics, stdout for data

**Severity:** ERROR
**Auto-fixable:** No

**Description:** Error messages, warnings, progress indicators, and debug output must go to stderr. Only primary data output goes to stdout.

**Good:**
```nushell
export def process-files [
    files: list<path>
    --verbose
] {
    for file in $files {
        if $verbose {
            print -e $"Processing: ($file)"  # stderr
        }
        let result = (open $file | process-content)
        print $result  # stdout - the actual data
    }
}
```

**Bad:**
```nushell
export def process-files [files: list<path>] {
    for file in $files {
        print $"Processing: ($file)"  # Mixes with data output!
        open $file | process-content
    }
}
```

---

### OUT-003: Respect NO_COLOR environment variable

**Severity:** WARNING
**Auto-fixable:** Partial

**Description:** When `NO_COLOR` environment variable is set, suppress color output regardless of other settings.

**Good:**
```nushell
def should-use-color [] {
    ($env.NO_COLOR? | is-empty) and (term size | get columns) > 0
}

export def status [] {
    let use_color = (should-use-color)
    let status = "OK"

    if $use_color {
        print $"(ansi green)($status)(ansi reset)"
    } else {
        print $status
    }
}
```

**Bad:**
```nushell
export def status [] {
    print $"(ansi green)OK(ansi reset)"  # Always uses color
}
```

---

### OUT-004: Don't output colors when not a TTY

**Severity:** WARNING
**Auto-fixable:** Partial

**Description:** Don't output colors when stdout is not a terminal (e.g., piped to file or another command).

**Good:**
```nushell
def is-terminal [] {
    (term size | get columns) > 0
}

export def report [--color: string = "auto"] {
    let use_color = match $color {
        "always" => true,
        "never" => false,
        _ => (is-terminal) and ($env.NO_COLOR? | is-empty)
    }
    # Use $use_color to conditionally format
}
```

**Bad:**
```nushell
export def report [] {
    # Always outputs ANSI codes, breaks piping
    print $"(ansi bold)Report(ansi reset)"
}
```

---

### OUT-005: Print actionable information on success

**Severity:** INFO
**Auto-fixable:** No

**Description:** On successful completion, print information that helps the user take the next logical action.

**Good:**
```nushell
export def init-project [name: string] {
    mkdir $name
    # ... setup project ...

    print -e $"Created project '($name)'"
    print -e ""
    print -e "Next steps:"
    print -e $"  cd ($name)"
    print -e "  myapp build"
}
```

**Bad:**
```nushell
export def init-project [name: string] {
    mkdir $name
    # ... setup project ...
    # Silent completion - user doesn't know what to do next
}
```

---

## 4. Errors (ERR-xxx)

### ERR-001: All errors must be caught and handled

**Severity:** ERROR
**Auto-fixable:** No

**Description:** Commands must handle potential errors gracefully, not let them propagate unexpectedly with cryptic messages.

**Good:**
```nushell
export def read-config [path: path] {
    if not ($path | path exists) {
        error make {
            msg: $"Config file not found: ($path)"
            help: "Create the config file or specify a different path with --config"
        }
    }

    try {
        open $path
    } catch {
        error make {
            msg: $"Failed to parse config: ($path)"
            help: "Ensure the file contains valid TOML/JSON/YAML"
        }
    }
}
```

**Bad:**
```nushell
export def read-config [path: path] {
    open $path  # Cryptic error if file doesn't exist or is invalid
}
```

---

### ERR-002: Error messages must be actionable

**Severity:** WARNING
**Auto-fixable:** No

**Description:** Error messages should tell the user what went wrong AND how to fix it.

**Good:**
```nushell
error make {
    msg: "Database connection failed"
    help: "Check that DATABASE_URL is set and the database server is running"
}
```

**Bad:**
```nushell
error make { msg: "Error" }
# or
error make { msg: "Connection failed" }  # Failed how? What to do?
```

---

### ERR-003: Use appropriate exit codes

**Severity:** WARNING
**Auto-fixable:** No

**Description:** Use standard exit codes: 0 for success, 1 for general errors, 2 for usage errors.

**Good:**
```nushell
export def main [--validate] {
    if $validate {
        let result = (validate-input)
        if not $result.valid {
            print -e $"Validation failed: ($result.error)"
            exit 1
        }
    }
    # Success path
    exit 0
}
```

**Bad:**
```nushell
export def main [] {
    # No explicit exit codes
    # Nushell default behavior may not match expectations
}
```

---

### ERR-004: Don't swallow errors silently

**Severity:** ERROR
**Auto-fixable:** No

**Description:** Never catch errors without logging or re-raising them. Silent failures cause debugging nightmares.

**Good:**
```nushell
export def cleanup [path: path] {
    try {
        rm -rf $path
    } catch { |e|
        print -e $"Warning: Could not remove ($path): ($e.msg)"
        # Continue execution but user is informed
    }
}
```

**Bad:**
```nushell
export def cleanup [path: path] {
    try {
        rm -rf $path
    } catch {
        # Silent failure - user has no idea it failed
    }
}
```

---

## 5. Configuration (CFG-xxx)

### CFG-001: Follow config precedence (flags > env > config)

**Severity:** WARNING
**Auto-fixable:** No

**Description:** Configuration sources should be checked in order: flags > environment variables > config file > defaults.

**Good:**
```nushell
export def connect [
    --host: string        # Override host
    --port: int           # Override port
] {
    let config = (load-config)

    let host = $host
        | default ($env.MYAPP_HOST? | default $config.host? | default "localhost")

    let port = $port
        | default ($env.MYAPP_PORT? | into int | default $config.port? | default 8080)

    # Use $host and $port
}
```

**Bad:**
```nushell
export def connect [--host: string] {
    let host = (open ~/.myapp/config.toml).host  # Ignores flag and env!
}
```

---

### CFG-002: Use XDG paths for user config

**Severity:** WARNING
**Auto-fixable:** Yes

**Description:** Store user configuration in XDG-compliant locations.

**Good:**
```nushell
def config-dir [] {
    $env.XDG_CONFIG_HOME?
    | default ($env.HOME | path join ".config")
    | path join "myapp"
}

def data-dir [] {
    $env.XDG_DATA_HOME?
    | default ($env.HOME | path join ".local" "share")
    | path join "myapp"
}

def cache-dir [] {
    $env.XDG_CACHE_HOME?
    | default ($env.HOME | path join ".cache")
    | path join "myapp"
}
```

**Bad:**
```nushell
def config-dir [] {
    $env.HOME | path join ".myapp"  # Not XDG compliant
}
```

---

### CFG-003: Never read secrets from environment variables

**Severity:** ERROR
**Auto-fixable:** No

**Description:** Secrets should be read from secure sources: dedicated secret managers, encrypted files, or interactive prompts. Environment variables are visible in process lists and logs.

**Good:**
```nushell
export def api-call [] {
    let token = if (which secret-tool | is-not-empty) {
        ^secret-tool lookup service myapp
    } else {
        input --suppress-output "API Token: "
    }
    # use $token
}
```

**Bad:**
```nushell
export def api-call [] {
    let token = $env.API_TOKEN  # Visible in process lists!
}
```

---

## 6. Robustness (ROB-xxx)

### ROB-001: Validate input early

**Severity:** WARNING
**Auto-fixable:** No

**Description:** Validate all inputs at the start of the command before performing any operations.

**Good:**
```nushell
export def process [
    input: path
    --output: path
] {
    # Validate upfront
    if not ($input | path exists) {
        error make { msg: $"Input file not found: ($input)" }
    }

    if ($output | path dirname | path exists | not $in) {
        error make { msg: $"Output directory does not exist: ($output | path dirname)" }
    }

    # Now do the actual work
    open $input | transform | save $output
}
```

**Bad:**
```nushell
export def process [input: path --output: path] {
    open $input           # Fails late if input doesn't exist
    | expensive-transform # Wasted work
    | save $output        # Fails even later if dir doesn't exist
}
```

---

### ROB-002: Handle network timeouts

**Severity:** WARNING
**Auto-fixable:** Partial

**Description:** Network operations should have explicit timeouts and retry logic.

**Good:**
```nushell
export def fetch [
    url: string
    --timeout: duration = 30sec
    --retries: int = 3
] {
    mut attempts = 0

    loop {
        $attempts += 1
        try {
            return (http get --max-time $timeout $url)
        } catch { |e|
            if $attempts >= $retries {
                error make {
                    msg: $"Failed to fetch ($url) after ($retries) attempts"
                    help: "Check your network connection and try again"
                }
            }
            print -e $"Retry ($attempts)/($retries)..."
            sleep 1sec
        }
    }
}
```

**Bad:**
```nushell
export def fetch [url: string] {
    http get $url  # No timeout, no retries, hangs forever
}
```

---

### ROB-003: Design for crash-only operation

**Severity:** INFO
**Auto-fixable:** No

**Description:** Commands should be safe to interrupt and re-run. Use atomic operations where possible.

**Good:**
```nushell
export def update-config [key: string, value: any] {
    let config_path = (config-dir | path join "config.toml")
    let temp_path = $"($config_path).tmp"

    # Write to temp file first
    let config = (open $config_path | upsert $key $value)
    $config | to toml | save -f $temp_path

    # Atomic rename
    mv -f $temp_path $config_path
}
```

**Bad:**
```nushell
export def update-config [key: string, value: any] {
    let config_path = (config-dir | path join "config.toml")

    # Direct modification - corruption if interrupted
    open $config_path | upsert $key $value | to toml | save -f $config_path
}
```

---

## 7. Style (STY-xxx)

### STY-001: Use kebab-case for command names

**Severity:** ERROR
**Auto-fixable:** Yes

**Description:** Command names and subcommands must use kebab-case.

**Good:**
```nushell
export def "user create" [] {}        # Subcommand
export def get-status [] {}           # Single command
export def sync-remote-data [] {}     # Multi-word command
```

**Bad:**
```nushell
export def "user_create" [] {}        # snake_case
export def getStatus [] {}            # camelCase
export def SyncRemoteData [] {}       # PascalCase
```

---

### STY-002: Use snake_case for variable names

**Severity:** WARNING
**Auto-fixable:** Yes

**Description:** Variable names should use snake_case for consistency with Nushell conventions.

**Good:**
```nushell
let user_name = "alice"
let max_retries = 3
let config_path = (config-dir | path join "config.toml")
```

**Bad:**
```nushell
let userName = "alice"      # camelCase
let MaxRetries = 3          # PascalCase
let config-path = "..."     # kebab-case (invalid in Nushell anyway)
```

---

### STY-003: Type annotations on all exports

**Severity:** WARNING
**Auto-fixable:** No

**Description:** All exported functions should have type annotations on parameters and return values where applicable.

**Good:**
```nushell
export def calculate-total [
    items: list<record<price: float, quantity: int>>
    --tax-rate: float = 0.0
] -> float {
    $items
    | each { |i| $i.price * $i.quantity }
    | math sum
    | $in * (1 + $tax_rate)
}
```

**Bad:**
```nushell
export def calculate-total [items --tax-rate] {
    # No type information
}
```

---

### STY-004: Lines under 120 characters

**Severity:** INFO
**Auto-fixable:** Partial

**Description:** Keep lines under 120 characters for readability. Break long lines logically.

**Good:**
```nushell
export def complex-operation [
    input: path
    --format: string = "json"
    --verbose
] {
    let result = (
        open $input
        | where status == "active"
        | select name email created_at
        | sort-by created_at
    )

    $result
}
```

**Bad:**
```nushell
export def complex-operation [input: path --format: string = "json" --verbose] { open $input | where status == "active" | select name email created_at | sort-by created_at }
```

---

## Quick Reference Table

| Rule ID | Severity | Description | Auto-fix |
|---------|----------|-------------|----------|
| HELP-001 | ERROR | Exported commands must have documentation | No |
| HELP-002 | INFO | Commands must support --help flag | No |
| HELP-003 | WARNING | Documentation must include examples | No |
| HELP-004 | INFO | Complex commands need detailed usage | No |
| ARG-001 | WARNING | Prefer flags over positional arguments | No |
| ARG-002 | WARNING | Use standard flag names | No |
| ARG-003 | ERROR | All flags must have long form | No |
| ARG-004 | INFO | Common flags should have short forms | No |
| ARG-005 | ERROR | Flags must have type annotations | No |
| ARG-006 | ERROR | Never accept secrets via flags | No |
| ARG-007 | WARNING | Provide sensible defaults | No |
| OUT-001 | WARNING | Support --json for machine-readable output | No |
| OUT-002 | ERROR | Use stderr for diagnostics | No |
| OUT-003 | WARNING | Respect NO_COLOR environment variable | Partial |
| OUT-004 | WARNING | Don't output colors when not a TTY | Partial |
| OUT-005 | INFO | Print actionable success information | No |
| ERR-001 | ERROR | All errors must be caught and handled | No |
| ERR-002 | WARNING | Error messages must be actionable | No |
| ERR-003 | WARNING | Use appropriate exit codes | No |
| ERR-004 | ERROR | Don't swallow errors silently | No |
| CFG-001 | WARNING | Follow config precedence | No |
| CFG-002 | WARNING | Use XDG paths for user config | Yes |
| CFG-003 | ERROR | Never read secrets from env vars | No |
| ROB-001 | WARNING | Validate input early | No |
| ROB-002 | WARNING | Handle network timeouts | Partial |
| ROB-003 | INFO | Design for crash-only operation | No |
| STY-001 | ERROR | Use kebab-case for command names | Yes |
| STY-002 | WARNING | Use snake_case for variable names | Yes |
| STY-003 | WARNING | Type annotations on all exports | No |
| STY-004 | INFO | Lines under 120 characters | Partial |

---

## Usage

### Running Validation

```nushell
# Validate a single file
cli-lint validate script.nu

# Validate with specific rules
cli-lint validate script.nu --rules [HELP-001 ARG-005 ERR-001]

# Strict mode (warnings become errors)
cli-lint validate script.nu --strict

# Show only errors
cli-lint validate script.nu --severity error
```

### Disabling Rules

```nushell
# Disable for a line
let token = $env.API_TOKEN  # cli-lint: disable=CFG-003

# Disable for a block
# cli-lint: disable=OUT-001
export def internal-util [] {
    # No --json needed for internal tools
}
# cli-lint: enable=OUT-001
```

---

## See Also

- [CLI Guidelines](https://clig.dev)
- [Nushell Style Guide](https://www.nushell.sh/book/style_guide.html)
- [12 Factor CLI Apps](https://medium.com/@jdxcode/12-factor-cli-apps-dd3c227a0e46)
