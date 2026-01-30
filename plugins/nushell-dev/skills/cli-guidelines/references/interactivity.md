# CLI Interactivity Guidelines

> Reference: https://clig.dev/#interactivity

Interactive CLI tools provide rich user experiences while maintaining compatibility
with scripted and automated workflows. Balance user-friendliness with scriptability.

---

## TTY Detection

Only prompt for input when stdin is connected to a terminal (TTY).
Scripts and pipelines should not trigger interactive prompts.

### Principles

- Check if stdin is a TTY before prompting
- Provide non-interactive alternatives for all prompts
- Fail with helpful errors when interaction is required but unavailable

### Nushell Implementation

```nushell
# Detect if running in a terminal
def is-terminal [] -> bool {
    # term size returns empty record when not a TTY
    (term size | is-not-empty)
}

# Prompt only when interactive
def prompt-if-interactive [prompt: string] -> string {
    if (is-terminal) {
        input $prompt
    } else {
        error make {
            msg: "Cannot prompt: not running in a terminal"
            help: "Provide required values via command-line arguments or use --no-input flag"
        }
    }
}

# Interactive confirmation with non-interactive fallback
def confirm [
    message: string
    --default: bool = false    # Default when non-interactive
] -> bool {
    if (is-terminal) {
        let suffix = if $default { " (Y/n): " } else { " (y/N): " }
        let response = input $"($message)($suffix)" | str trim | str downcase

        if ($response | is-empty) {
            $default
        } else {
            $response in ["y", "yes", "true", "1"]
        }
    } else {
        $default
    }
}

# Multi-choice selection
def select-option [
    prompt: string
    options: list<string>
    --default: int = 0
] -> string {
    if not (is-terminal) {
        return ($options | get $default)
    }

    print $prompt
    $options | enumerate | each { |opt|
        let marker = if $opt.index == $default { ">" } else { " " }
        print $"  ($marker) ($opt.index + 1)) ($opt.item)"
    }

    let response = input "Enter number: " | str trim

    if ($response | is-empty) {
        $options | get $default
    } else {
        let idx = ($response | into int) - 1
        if $idx >= 0 and $idx < ($options | length) {
            $options | get $idx
        } else {
            error make { msg: "Invalid selection" }
        }
    }
}
```

---

## The --no-input Flag

Provide a flag to disable all interactive prompts for scripted use.

### Principles

- `--no-input` should disable ALL prompts
- Required values must be provided via flags when using `--no-input`
- Fail fast with clear error messages when required values are missing

### Nushell Implementation

```nushell
# Standard --no-input pattern
def my-command [
    --no-input              # Disable all interactive prompts
    --name: string          # Required if --no-input
    --confirm               # Auto-confirm if --no-input
] {
    # Get name: from flag or prompt
    let name = if $no_input {
        if ($name | is-empty) {
            error make {
                msg: "--name is required when using --no-input"
                help: "Provide --name <value> or remove --no-input"
            }
        }
        $name
    } else {
        $name | default (input "Enter name: ")
    }

    # Handle confirmation
    let confirmed = if $no_input {
        $confirm  # Must explicitly pass --confirm
    } else {
        confirm "Proceed with operation?"
    }

    if not $confirmed {
        print "Operation cancelled"
        return
    }

    # Continue with operation...
    print $"Processing: ($name)"
}

# Comprehensive non-interactive mode
def deploy [
    --no-input              # Non-interactive mode
    --environment: string   # Required: dev, staging, prod
    --version: string       # Required: version to deploy
    --force                 # Skip confirmation prompts
] {
    # Validate required args in non-interactive mode
    if $no_input {
        let missing = []
        if ($environment | is-empty) { $missing = ($missing | append "--environment") }
        if ($version | is-empty) { $missing = ($missing | append "--version") }

        if ($missing | is-not-empty) {
            error make {
                msg: $"Missing required arguments for non-interactive mode"
                help: $"Required flags: ($missing | str join ', ')"
            }
        }
    }

    let env = $environment | default (select-option "Select environment:" ["dev", "staging", "prod"])
    let ver = $version | default (input "Enter version: ")

    # Confirmation for production
    if $env == "prod" and not $force {
        if not (confirm "Deploy to PRODUCTION? This cannot be undone." --default false) {
            print "Deployment cancelled"
            return
        }
    }

    print $"Deploying ($ver) to ($env)..."
}
```

---

## Password Handling

Never echo passwords to the terminal. Provide secure input methods.

### Principles

- Passwords should not appear on screen while typing
- Clear password from memory after use when possible
- Support password from environment variables or files for automation
- Never log or display passwords

### Nushell Implementation

```nushell
# Secure password input (basic - Nushell doesn't have native hidden input yet)
def get-password [prompt: string = "Password: "] -> string {
    if not (is-terminal) {
        error make {
            msg: "Cannot read password: not a terminal"
            help: "Use --password-file or PASSWORD environment variable"
        }
    }

    # Use stty to disable echo (Unix systems)
    ^stty -echo
    let password = input $prompt
    ^stty echo
    print ""  # Newline after hidden input

    $password
}

# Password from multiple sources
def get-credentials [
    --password: string          # Password (insecure, visible in process list)
    --password-file: string     # Read password from file
    --password-env: string      # Environment variable name
] -> string {
    # Priority: flag > file > env > prompt
    if ($password | is-not-empty) {
        print --stderr "Warning: --password is insecure. Use --password-file or --password-env"
        return $password
    }

    if ($password_file | is-not-empty) {
        if not ($password_file | path exists) {
            error make { msg: $"Password file not found: ($password_file)" }
        }
        return (open $password_file | str trim)
    }

    if ($password_env | is-not-empty) {
        let env_val = $env | get -i $password_env
        if ($env_val | is-not-empty) {
            return $env_val
        }
        error make { msg: $"Environment variable not set: ($password_env)" }
    }

    # Fall back to interactive prompt
    get-password "Enter password: "
}

# Example usage in a login command
def login [
    username: string
    --password-file: string
] {
    let password = get-credentials --password-file $password_file

    # Use password...
    print $"Logging in as ($username)..."

    # Note: In real implementation, clear password from memory
}
```

---

## Escape Capability

Users should always have a clear way to exit or cancel operations.

### Principles

- Ctrl-C should always work to abort
- Provide explicit exit/quit commands in interactive modes
- Show how to exit in prompts and help text
- Don't trap users in infinite loops

### Nushell Implementation

```nushell
# Interactive mode with clear exit
def interactive-shell [] {
    print "Interactive mode. Type 'exit' or 'quit' to leave, Ctrl-C to abort."
    print ""

    loop {
        let cmd = input "> " | str trim

        match $cmd {
            "" => { continue }
            "exit" | "quit" | "q" => {
                print "Goodbye!"
                break
            }
            "help" | "?" => {
                print "Commands: help, exit, quit"
                print "Press Ctrl-C to abort at any time"
            }
            _ => {
                print $"Unknown command: ($cmd). Type 'help' for options."
            }
        }
    }
}

# Long-running operation with cancellation info
def long-process [] {
    print "Processing... (Press Ctrl-C to cancel)"

    for i in 1..100 {
        print -n $"\rProgress: ($i)%"
        sleep 100ms
    }
    print "\nComplete!"
}

# Wizard with back/cancel options
def setup-wizard [] {
    print "Setup Wizard (type 'back' to go back, 'cancel' to exit)"
    print ""

    mut step = 1
    mut answers = {}

    while $step <= 3 {
        let response = match $step {
            1 => { input "Step 1 - Enter name: " }
            2 => { input "Step 2 - Enter email: " }
            3 => { input "Step 3 - Enter company: " }
        }

        match ($response | str trim | str downcase) {
            "cancel" | "quit" | "exit" => {
                print "Setup cancelled"
                return null
            }
            "back" => {
                if $step > 1 { $step = $step - 1 }
            }
            _ => {
                $answers = ($answers | insert $"step($step)" $response)
                $step = $step + 1
            }
        }
    }

    print "Setup complete!"
    $answers
}
```

---

## Subcommand Patterns

Well-designed subcommand hierarchies make CLIs intuitive and discoverable.

### Principles

1. **Consistency** - Same patterns across all subcommands
2. **Noun-verb ordering** - `docker container create` not `docker create container`
3. **Avoid ambiguity** - Clear distinction between similar commands
4. **Predictable depth** - Usually 2-3 levels maximum

### Nushell Implementation

```nushell
# Top-level command shows usage
export def main [] {
    print "myapp - Application management tool"
    print ""
    print "Usage: myapp <command> [options]"
    print ""
    print "Commands:"
    print "  config     Manage configuration"
    print "  service    Manage services"
    print "  user       Manage users"
    print ""
    print "Run 'myapp <command> --help' for more information"
}

# Noun-verb pattern: myapp config <verb>
export def "myapp config" [] {
    print "Usage: myapp config <command>"
    print ""
    print "Commands:"
    print "  get <key>          Get a configuration value"
    print "  set <key> <value>  Set a configuration value"
    print "  list               List all configuration"
    print "  reset              Reset to defaults"
}

export def "myapp config get" [
    key: string     # Configuration key to retrieve
] {
    # Implementation
    print $"Getting config: ($key)"
}

export def "myapp config set" [
    key: string     # Configuration key
    value: any      # Value to set
] {
    print $"Setting ($key) = ($value)"
}

export def "myapp config list" [
    --format: string = "table"    # Output format (table, json, yaml)
] {
    # Return config as table or specified format
    { setting1: "value1", setting2: "value2" }
}

export def "myapp config reset" [
    --force    # Skip confirmation
] {
    if not $force {
        if not (confirm "Reset all configuration to defaults?") {
            print "Cancelled"
            return
        }
    }
    print "Configuration reset"
}

# Service management subcommands
export def "myapp service" [] {
    print "Usage: myapp service <command>"
    print ""
    print "Commands:"
    print "  start <name>    Start a service"
    print "  stop <name>     Stop a service"
    print "  restart <name>  Restart a service"
    print "  status [name]   Show service status"
    print "  list            List all services"
}

export def "myapp service start" [name: string] { print $"Starting ($name)..." }
export def "myapp service stop" [name: string] { print $"Stopping ($name)..." }
export def "myapp service restart" [name: string] { print $"Restarting ($name)..." }
export def "myapp service status" [name?: string] {
    if ($name | is-empty) {
        print "All services status..."
    } else {
        print $"($name) status..."
    }
}
export def "myapp service list" [] { print "Listing services..." }
```

### Avoiding Ambiguous Names

```nushell
# BAD: Ambiguous names
# export def "pkg update" []    # Update packages or update index?
# export def "pkg upgrade" []   # What's the difference?

# GOOD: Clear, specific names
export def "pkg refresh" [] {
    # Refresh package index/cache
    print "Refreshing package index..."
}

export def "pkg upgrade" [
    ...packages: string    # Specific packages, or all if empty
] {
    # Upgrade installed packages to newer versions
    if ($packages | is-empty) {
        print "Upgrading all packages..."
    } else {
        print $"Upgrading: ($packages | str join ', ')"
    }
}

export def "pkg install" [...packages: string] {
    # Install new packages
    print $"Installing: ($packages | str join ', ')"
}
```

---

## Naming Conventions

Command and option names should be memorable, typeable, and self-documenting.

### Principles

1. **Simple and memorable** - Easy to recall without documentation
2. **Lowercase with dashes** - `my-command` not `myCommand` or `my_command`
3. **Keep short but not too short** - `ls` is fine, `l` is too short
4. **Easy to type** - Avoid awkward key combinations
5. **No arbitrary abbreviations** - `--verbose` not `--vrbse`

### Nushell Implementation

```nushell
# GOOD: Clear, full names
export def "file search" [
    pattern: string
    --recursive (-r)           # Short AND long form
    --ignore-case (-i)
    --max-depth: int
    --type: string             # file, dir, symlink
] {
    # Implementation
}

# GOOD: Standard abbreviations that everyone knows
export def "net check" [
    host: string
    --timeout (-t): duration = 5sec
    --count (-c): int = 4
    --verbose (-v)
] {
    # -t, -c, -v are universally understood
}

# BAD: Arbitrary abbreviations
# export def cmd [
#     --vb    # verbose? vibration? variable?
#     --cnt   # count? continue? content?
#     --pth   # path? something else?
# ]

# GOOD: Consistent flag patterns across commands
export def "db backup" [
    --output (-o): string      # Consistent: -o for output
    --force (-f)               # Consistent: -f for force
    --quiet (-q)               # Consistent: -q for quiet
    --verbose (-v)             # Consistent: -v for verbose
] { }

export def "db restore" [
    --input (-i): string       # Consistent: -i for input
    --force (-f)               # Same as backup
    --quiet (-q)               # Same as backup
    --verbose (-v)             # Same as backup
] { }

# Compound command names: verb-noun or noun-verb
# Prefer consistency within your tool

# Option A: Noun-verb (Docker style)
export def "container create" [] { }
export def "container start" [] { }
export def "container stop" [] { }

# Option B: Verb-noun (Git style)
export def "create container" [] { }
export def "start container" [] { }
export def "stop container" [] { }

# Pick ONE and stick with it!
```

### Flag Naming Guidelines

```nushell
# Standard short flags (universally understood)
# -h, --help       Help
# -v, --verbose    Verbose output
# -q, --quiet      Quiet/silent mode
# -f, --force      Force operation
# -n, --dry-run    Dry run (no changes)
# -o, --output     Output file/path
# -i, --input      Input file/path
# -r, --recursive  Recursive operation
# -y, --yes        Auto-confirm (non-interactive)

# Define with both short and long forms
export def process-files [
    ...files: string
    --recursive (-r)           # Both forms
    --verbose (-v)
    --output (-o): string
    --dry-run (-n)             # -n is conventional for dry-run
    --force (-f)
    --yes (-y)                 # Auto-confirm
] {
    if $verbose {
        print $"Processing ($files | length) files..."
    }

    if $dry_run {
        print "(dry run - no changes will be made)"
    }
}
```

---

## Input Methods Summary

Support multiple ways to provide input for maximum flexibility.

```nushell
# Comprehensive input handling
def process [
    value?: string              # Positional argument
    --value (-v): string        # Flag (alternative to positional)
    --file (-f): string         # Read from file
    --stdin                     # Read from stdin
] {
    # Priority: positional > flag > file > stdin > interactive
    let input = if ($value | is-not-empty) {
        $value
    } else if ($value | is-not-empty) {  # --value flag
        $value
    } else if ($file | is-not-empty) {
        open $file | str trim
    } else if $stdin {
        $in | str trim
    } else if (is-terminal) {
        input "Enter value: "
    } else {
        error make {
            msg: "No input provided"
            help: "Provide value as argument, --file, --stdin, or interactively"
        }
    }

    print $"Processing: ($input)"
}
```

---

## Summary Checklist

- [ ] Check TTY before prompting for input
- [ ] Provide `--no-input` flag for scripted use
- [ ] All interactive prompts have flag alternatives
- [ ] Passwords are never echoed or logged
- [ ] Clear exit methods are documented and available
- [ ] Ctrl-C works to abort operations
- [ ] Subcommands follow consistent noun-verb or verb-noun pattern
- [ ] Command names are lowercase with dashes
- [ ] Abbreviations are standard and universal (not arbitrary)
- [ ] Short flags (-v) and long flags (--verbose) are both provided
- [ ] Help text shows all input methods available
