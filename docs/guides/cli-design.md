# CLI Design Guide

Best practices for designing professional command-line interfaces in Nushell.

## Core Principles

### 1. Human-First Design

CLIs are for humans first, machines second.

```nushell
# Good: Clear, descriptive output
def "db status" [] {
    let status = check-connection
    if $status.connected {
        print $"✓ Connected to ($status.host):($status.port)"
        print $"  Database: ($status.database)"
        print $"  Latency: ($status.latency)"
    } else {
        print $"✗ Not connected: ($status.error)"
    }
}

# Bad: Cryptic output
def "db status" [] {
    $"C:($host):($port):($db):($latency)"
}
```

### 2. Composable by Default

Output structured data that works in pipelines.

```nushell
# Good: Return structured data
def "user list" [] -> table {
    stor open | query db "SELECT * FROM users"
}

# Compose with other commands
user list | where active == true | select name email

# Bad: Print formatted strings
def "user list" [] {
    print "Users:"
    print "------"
    # ...
}
```

### 3. Fail Gracefully

Handle errors with clear messages and exit codes.

```nushell
def "config load" [path: path] {
    if not ($path | path exists) {
        error make {
            msg: $"Config file not found: ($path)"
            help: "Create a config file or specify a different path with --config"
        }
    }

    try {
        open $path
    } catch { |e|
        error make {
            msg: $"Failed to parse config: ($e.msg)"
            help: "Check the config file syntax"
        }
    }
}
```

---

## Command Structure

### Main Entry Point

```nushell
#!/usr/bin/env nu

# mytool - Brief description of what it does
#
# A longer description of the tool's purpose,
# key features, and usage patterns.

def main [] {
    help main
}
```

### Subcommand Groups

```nushell
# Group related functionality
def "db" [] { help db }

def "db connect" [
    host: string
    --port: int = 5432
    --database: string = "postgres"
] {
    # Connect to database
}

def "db status" [] {
    # Show connection status
}

def "db query" [sql: string] {
    # Execute query
}
```

### Consistent Naming

```nushell
# Verb-noun pattern
def "user create" [] { }
def "user delete" [] { }
def "user list" [] { }
def "user update" [] { }

# Or noun first for discovery
def "users" [] { help users }
def "users create" [] { }
def "users list" [] { }
```

---

## Arguments and Flags

### Positional Arguments

```nushell
def "file copy" [
    source: path       # Source file path
    destination: path  # Destination path
] {
    cp $source $destination
}
```

### Optional Arguments

```nushell
def greet [
    name?: string     # Name to greet (optional)
] {
    let who = $name | default "World"
    print $"Hello, ($who)!"
}
```

### Flags with Values

```nushell
def "api request" [
    url: string
    --method: string = "GET"     # HTTP method
    --timeout: duration = 30sec  # Request timeout
    --headers: record = {}       # Additional headers
] {
    # Implementation
}
```

### Boolean Flags

```nushell
def "build" [
    --release (-r)    # Build in release mode
    --verbose (-v)    # Enable verbose output
    --dry-run         # Show what would be done
] {
    if $verbose {
        print "Starting build..."
    }

    if $dry_run {
        print "Would build in release mode: ($release)"
        return
    }

    # Actual build
}
```

### Rest Parameters

```nushell
def "run" [
    command: string
    ...args: string   # Additional arguments
] {
    ^$command ...$args
}
```

---

## Output Design

### Structured Output for Pipelines

```nushell
# Return structured data
def "process list" [] -> table {
    ps | select pid name cpu mem
}

# Can be piped and filtered
process list | where cpu > 10 | sort-by cpu --reverse
```

### Human-Readable Output

```nushell
# Format for display when needed
def "status show" [] {
    let data = get-status

    print $"Service: ($data.name)"
    print $"Status:  (colorize $data.status)"
    print $"Uptime:  ($data.uptime)"
}

def colorize [status: string] -> string {
    match $status {
        "running" => $"(ansi green)●(ansi reset) running"
        "stopped" => $"(ansi red)●(ansi reset) stopped"
        _ => $"(ansi yellow)●(ansi reset) ($status)"
    }
}
```

### Progress Feedback

```nushell
def "process files" [files: list<path>] {
    let total = $files | length

    $files | enumerate | each { |item|
        let progress = ($item.index + 1) / $total * 100 | into int
        print -n $"\rProcessing: ($progress)% (($item.index + 1)/($total))"

        process-file $item.item
    }

    print "\nDone!"
}
```

---

## Error Handling

### User-Friendly Errors

```nushell
def "config validate" [path: path] {
    if not ($path | path exists) {
        error make {
            msg: "Config file not found"
            help: $"Expected config at: ($path)\nCreate one with: mytool config init"
        }
    }

    let config = open $path

    if ($config.api_key? | is-empty) {
        error make {
            msg: "Missing required field: api_key"
            help: "Add 'api_key = \"your-key\"' to your config file"
        }
    }
}
```

### Exit Codes

```nushell
def main [] {
    try {
        run-application
    } catch { |e|
        print $"Error: ($e.msg)" err> /dev/stderr
        exit 1
    }
}
```

### Validation Early

```nushell
def "deploy" [
    env: string
    --force
] {
    # Validate before doing anything
    if $env not-in ["dev", "staging", "prod"] {
        error make { msg: $"Invalid environment: ($env). Use: dev, staging, or prod" }
    }

    if $env == "prod" and not $force {
        error make {
            msg: "Production deployment requires --force flag"
            help: "Review changes and run again with --force"
        }
    }

    # Proceed with deployment
    do-deploy $env
}
```

---

## Configuration

### Config File Loading

```nushell
const CONFIG_PATHS = [
    "./config.toml"
    "~/.config/mytool/config.toml"
    "/etc/mytool/config.toml"
]

def load-config [] {
    for path in $CONFIG_PATHS {
        let expanded = $path | path expand
        if ($expanded | path exists) {
            return (open $expanded)
        }
    }

    # Return defaults if no config found
    {
        api_url: "https://api.example.com"
        timeout: 30sec
    }
}
```

### Environment Variables

```nushell
def get-config [] {
    {
        api_url: ($env.MYTOOL_API_URL? | default "https://api.example.com")
        api_key: ($env.MYTOOL_API_KEY? | default null)
        debug: ($env.MYTOOL_DEBUG? | default "false" | into bool)
        timeout: ($env.MYTOOL_TIMEOUT? | default "30" | $"($in)sec" | into duration)
    }
}
```

### Config Initialization

```nushell
def "config init" [
    --path: path   # Config file path
] {
    let config_path = $path | default "~/.config/mytool/config.toml" | path expand
    let config_dir = $config_path | path dirname

    mkdir $config_dir

    if ($config_path | path exists) {
        error make { msg: $"Config already exists at ($config_path)" }
    }

    {
        api_url: "https://api.example.com"
        timeout: 30
        debug: false
    } | to toml | save $config_path

    print $"Created config at: ($config_path)"
}
```

---

## Help and Documentation

### Command Documentation

```nushell
# Deploy application to specified environment
#
# Deploys the current application build to the target environment.
# Requires appropriate credentials and permissions.
#
# Examples:
#   deploy dev                    # Deploy to development
#   deploy staging --verbose      # Deploy to staging with logs
#   deploy prod --force           # Deploy to production
def deploy [
    env: string       # Target environment (dev, staging, prod)
    --force (-f)      # Skip confirmation prompts
    --verbose (-v)    # Show detailed output
    --dry-run         # Show what would be done without executing
] {
    # Implementation
}
```

### Version Information

```nushell
const VERSION = "1.0.0"

def "version" [] {
    {
        name: "mytool"
        version: $VERSION
        nushell: $nu.version
        os: $nu.os-info.name
    }
}
```

### Examples in Help

```nushell
# Process data files with transformations
#
# Examples:
#   # Basic usage
#   process input.csv
#
#   # With filtering
#   process input.csv --filter "amount > 100"
#
#   # Output to different format
#   process input.csv --output json > output.json
#
#   # Batch processing
#   ls *.csv | each { |f| process $f.name }
def process [
    input: path
    --filter: string
    --output: string = "table"
] {
    # Implementation
}
```

---

## Testing CLI Tools

### Integration Tests

```nushell
# tests/test_cli.nu

def test-help-works [] {
    let result = do { nu mytool.nu --help } | complete
    assert ($result.exit_code == 0)
    assert ($result.stdout | str contains "Usage:")
}

def test-version-output [] {
    let result = nu mytool.nu version
    assert ($result.version | is-not-empty)
}

def test-invalid-command [] {
    let result = do { nu mytool.nu invalid } | complete
    assert ($result.exit_code != 0)
}
```

### Validation Tests

```nushell
def test-validates-input [] {
    let result = do { nu mytool.nu process "" } | complete
    assert ($result.exit_code != 0)
    assert ($result.stderr | str contains "cannot be empty")
}
```
