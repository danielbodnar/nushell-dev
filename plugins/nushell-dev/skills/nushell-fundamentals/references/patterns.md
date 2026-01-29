# Idiomatic Nushell Patterns

## Pipeline Patterns

### Chained Transformations

```nushell
# Transform data step by step
open users.json
| get data
| where status == "active"
| select name email created_at
| sort-by created_at --reverse
| first 10
```

### Parallel Processing

```nushell
# Use par-each for CPU-intensive operations
ls **/*.nu | par-each { |f|
    open $f.name | lines | length
}
```

### Conditional Pipeline

```nushell
# Apply transformations conditionally
let data = open input.json
let result = if $env.VERBOSE? != null {
    $data | debug
} else {
    $data
}
```

## Data Transformation Patterns

### Record to Table

```nushell
# Convert record to table rows
{a: 1, b: 2, c: 3}
| transpose key value
| rename column1 column2
```

### Table Reshaping

```nushell
# Pivot table
[[name, metric, value]; ["a", "x", 1], ["a", "y", 2]]
| group-by name
| transpose name metrics
| each { |r|
    {name: $r.name} | merge ($r.metrics | transpose -rd)
}
```

### Nested Data Extraction

```nushell
# Flatten nested structures
open data.json
| get items
| each { |item|
    {
        id: $item.id
        user_name: $item.user.name
        tags: ($item.tags | str join ", ")
    }
}
```

## Error Handling Patterns

### Safe Navigation

```nushell
# Use ? for optional access
$record.maybe_field?
$env.OPTIONAL_VAR?

# Default on null
$record.field? | default "fallback"
```

### Graceful Degradation

```nushell
def fetch-with-retry [url: string, --retries: int = 3] {
    mut attempts = 0
    loop {
        try {
            return (http get $url)
        } catch {
            $attempts = $attempts + 1
            if $attempts >= $retries {
                error make { msg: $"Failed after ($retries) attempts" }
            }
            sleep 1sec
        }
    }
}
```

### Result Pattern

```nushell
# Return structured results
def safe-parse [input: string] -> record {
    try {
        {ok: true, value: ($input | from json)}
    } catch { |err|
        {ok: false, error: $err.msg}
    }
}
```

## Command Design Patterns

### Subcommand Groups

```nushell
# Group related commands under namespace
export def "config get" [key: string] {
    # Get config value
}

export def "config set" [key: string, value: any] {
    # Set config value
}

export def "config list" [] {
    # List all config
}
```

### Builder Pattern

```nushell
# Chainable command options
def query [
    table: string
    --select: list<string> = []
    --where: string = ""
    --limit: int = 100
    --order-by: string = ""
] {
    mut sql = $"SELECT ($select | default ['*'] | str join ', ') FROM ($table)"
    if $where != "" { $sql = $"($sql) WHERE ($where)" }
    if $order-by != "" { $sql = $"($sql) ORDER BY ($order-by)" }
    $sql = $"($sql) LIMIT ($limit)"
    $sql
}
```

### Pipeline-Aware Commands

```nushell
# Accept both piped input and argument
def process [data?: any] -> any {
    let input = $data | default $in
    # Process $input
}
```

## Module Organization Patterns

### Feature Modules

```nushell
# mod.nu - Main entry point
export use ./core.nu *
export use ./utils.nu [helper1, helper2]
export use ./constants.nu *
```

### Lazy Loading

```nushell
# Only load when needed
def heavy-feature [] {
    use ./heavy-module.nu
    heavy-module do-work
}
```

### Configuration Module

```nushell
# config.nu
export-env {
    $env.MY_APP_CONFIG = {
        api_url: ($env.MY_APP_API_URL? | default "https://api.example.com")
        timeout: 30sec
        retries: 3
    }
}
```

## Testing Patterns

### Assertion Helpers

```nushell
def assert-eq [expected: any, actual: any, message?: string] {
    if $expected != $actual {
        let msg = $message | default $"Expected ($expected), got ($actual)"
        error make { msg: $msg }
    }
}

def assert-contains [haystack: string, needle: string] {
    if not ($haystack | str contains $needle) {
        error make { msg: $"Expected '($haystack)' to contain '($needle)'" }
    }
}
```

### Test Organization

```nushell
# tests/test_utils.nu
use ../src/utils.nu

def "test double" [] {
    assert-eq 4 (double 2)
    assert-eq 0 (double 0)
    assert-eq -4 (double -2)
}

def "test all" [] {
    test double
    print "All tests passed!"
}
```

## Performance Patterns

### Avoid Repeated Parsing

```nushell
# Bad: Re-parses file each iteration
for item in (open large.json | get items) {
    let all = open large.json  # Avoid this!
}

# Good: Parse once
let data = open large.json
let all_items = $data | get items
for item in $all_items {
    # Use $all_items
}
```

### Use Lazy Operations

```nushell
# Prefer where over each + if
ls | where size > 1mb  # Optimized

# Avoid manual filtering
ls | each { |f| if $f.size > 1mb { $f } }  # Less efficient
```

### Batch Operations

```nushell
# Process in batches for large datasets
let items = open huge.json | get items
$items
| chunks 1000
| each { |batch|
    $batch | par-each { |item| process $item }
}
| flatten
```

## Integration Patterns

### External Command Wrapping

```nushell
# Wrap external command with structured output
def git-status [] {
    ^git status --porcelain
    | lines
    | each { |line|
        let parts = $line | split row " " | compact
        {
            status: $parts.0
            file: ($parts | skip 1 | str join " ")
        }
    }
}
```

### Environment Setup

```nushell
# Use with-env for temporary changes
with-env {API_KEY: $secret} {
    http get $url --headers [Authorization $"Bearer ($env.API_KEY)"]
}
```

### Cross-Platform Paths

```nushell
# Use path join for portability
let config_path = [$nu.home-path, ".config", "myapp"] | path join

# Check platform
if $nu.os-info.name == "windows" {
    # Windows-specific
} else {
    # Unix-like
}
```
