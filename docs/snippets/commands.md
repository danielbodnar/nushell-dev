# Custom Commands Snippets

## Basic Commands

### Simple Command

```nushell
def hello [] {
    "Hello, World!"
}
```

### Command with Parameters

```nushell
def greet [name: string] {
    print $"Hello, ($name)!"
}

# Usage: greet "Alice"
```

### Command with Return Type

```nushell
def add [a: int, b: int] -> int {
    $a + $b
}
```

---

## Parameter Types

### Type Annotations

```nushell
def process [
    input: string           # Basic type
    count: int              # Integer
    ratio: float            # Float
    active: bool            # Boolean
    file: path              # File path
    duration: duration      # Duration (e.g., 5min)
    size: filesize          # File size (e.g., 1gb)
    when: datetime          # Date/time
    items: list<string>     # List of strings
    config: record          # Record/object
    data: table             # Table
    action: closure         # Closure/function
    anything: any           # Any type
] {
    # Implementation
}
```

### Optional Parameters

```nushell
def fetch [
    url: string
    format?: string  # Optional (can be null)
] {
    let fmt = $format | default "json"
    http get $url | match $fmt {
        "json" => { $in }
        "text" => { $in | to text }
    }
}

# Usage: fetch "https://..." or fetch "https://..." "text"
```

### Default Values

```nushell
def connect [
    host: string
    port: int = 8080           # Default value
    --timeout: duration = 30sec
] {
    print $"Connecting to ($host):($port) with ($timeout) timeout"
}
```

### Rest Parameters

```nushell
def sum [...nums: int] -> int {
    $nums | math sum
}

# Usage: sum 1 2 3 4 5
```

---

## Flags and Switches

### Boolean Flags (Switches)

```nushell
def build [
    --verbose (-v)           # Boolean flag with short form
    --release (-r)           # Another boolean flag
    --quiet                  # Boolean flag without short form
] {
    if $verbose {
        print "Verbose mode enabled"
    }
    if $release {
        print "Building release version"
    }
}

# Usage: build --verbose --release
# Usage: build -v -r
```

### Flags with Values

```nushell
def deploy [
    --env: string            # Required when flag is used
    --replicas: int = 1      # With default
    --config: path           # File path flag
] {
    print $"Deploying to ($env) with ($replicas) replicas"
}

# Usage: deploy --env production --replicas 3
```

### Combining Positional and Flags

```nushell
def search [
    pattern: string              # Required positional
    path?: path                  # Optional positional
    --ignore-case (-i)           # Boolean flag
    --max-results: int = 100     # Flag with default
    --exclude: list<string> = [] # List flag
] {
    let search_path = $path | default "."

    let args = [
        (if $ignore_case { "-i" } else { "" })
        $"--max-count=($max_results)"
        $pattern
        $search_path
    ] | compact

    ^rg ...$args
}
```

---

## Documentation

### Inline Documentation

```nushell
# Fetch user data from the API
#
# Returns a record containing user profile information
# including name, email, and account status.
#
# Examples:
#   fetch-user 123
#   fetch-user 123 --include-posts
#   fetch-user 123 --format json
def fetch-user [
    id: int                  # The user's unique identifier
    --include-posts          # Include the user's recent posts
    --format: string = "json" # Output format (json, yaml, table)
] -> record {
    let user = http get $"https://api.example.com/users/($id)"

    if $include_posts {
        let posts = http get $"https://api.example.com/users/($id)/posts"
        $user | insert posts $posts
    } else {
        $user
    }
}
```

### Multi-line Examples

```nushell
# Process data files with various transformations
#
# Takes input files, applies transformations, and outputs results.
# Supports filtering, sorting, and aggregation operations.
#
# Examples:
#   # Basic usage
#   process-data input.csv
#
#   # With filtering
#   process-data input.csv --filter "amount > 100"
#
#   # Complex pipeline
#   ls *.csv | each { |f| process-data $f.name --output json }
def process-data [
    input: path              # Input file path
    --filter: string         # Filter expression
    --output: string = "table" # Output format
] -> any {
    # Implementation
}
```

---

## Subcommands

### Creating Subcommand Groups

```nushell
# Main command (shows help)
def config [] {
    help config
}

# Subcommands
def "config get" [key: string] -> any {
    $env.APP_CONFIG? | get $key | default null
}

def "config set" [key: string, value: any] {
    $env.APP_CONFIG = ($env.APP_CONFIG? | default {} | insert $key $value)
}

def "config list" [] -> record {
    $env.APP_CONFIG? | default {}
}

def "config reset" [] {
    $env.APP_CONFIG = {}
}

# Usage:
#   config get api_url
#   config set api_url "https://api.example.com"
#   config list
#   config reset
```

### Nested Subcommands

```nushell
def db [] { help db }
def "db table" [] { help "db table" }

def "db table list" [] {
    stor open | schema | get tables
}

def "db table create" [name: string, --columns: record] {
    stor create --table-name $name --columns $columns
}

def "db table drop" [name: string] {
    stor open | query db $"DROP TABLE ($name)"
}

# Usage:
#   db table list
#   db table create users --columns {id: int, name: str}
#   db table drop users
```

---

## Pipeline-Aware Commands

### Accept Both Piped and Argument Input

```nushell
def process [data?: any] -> any {
    let input = $data | default $in

    if ($input | is-empty) {
        error make { msg: "No input provided" }
    }

    # Process $input
    $input | each { |item| transform $item }
}

# Usage:
#   process $my_data
#   $my_data | process
#   open file.json | process
```

### Command as Filter

```nushell
# Filter command that works in pipelines
def active [] {
    where status == "active"
}

# Usage: open users.json | active | select name email
```

### Command with Pipeline Metadata

```nushell
def with-index [] {
    enumerate | each { |item|
        $item.item | insert _index $item.index
    }
}

# Usage: ["a", "b", "c"] | with-index
# [{_index: 0, value: "a"}, ...]
```

---

## Error Handling in Commands

### Basic Error Handling

```nushell
def safe-divide [a: int, b: int] -> int {
    if $b == 0 {
        error make { msg: "Division by zero" }
    }
    $a / $b
}
```

### Structured Errors

```nushell
def validate-user [user: record] {
    if ($user.name? | is-empty) {
        error make {
            msg: "Validation failed"
            label: {
                text: "name is required"
                span: (metadata $user).span
            }
        }
    }

    if ($user.email? | is-empty) or not ($user.email | str contains "@") {
        error make {
            msg: "Invalid email"
            label: {
                text: "must be a valid email address"
                span: (metadata $user).span
            }
        }
    }

    $user
}
```

### Result Pattern

```nushell
def try-parse [input: string] -> record {
    try {
        {ok: true, value: ($input | from json)}
    } catch { |err|
        {ok: false, error: $err.msg}
    }
}

# Usage:
let result = try-parse $input
if $result.ok {
    process $result.value
} else {
    print $"Parse error: ($result.error)"
}
```

---

## Advanced Patterns

### Command with Closure Parameter

```nushell
def with-retry [action: closure, --max-attempts: int = 3] -> any {
    mut last_error = null

    for attempt in 1..=$max_attempts {
        try {
            return (do $action)
        } catch { |err|
            $last_error = $err.msg
            print $"Attempt ($attempt) failed: ($last_error)"
            if $attempt < $max_attempts {
                sleep 1sec
            }
        }
    }

    error make { msg: $"Failed after ($max_attempts) attempts: ($last_error)" }
}

# Usage: with-retry { http get "https://api.example.com" }
```

### Command with Environment Setup

```nushell
def with-env-vars [vars: record, action: closure] {
    # Save current values
    let saved = $vars | columns | each { |key|
        {key: $key, value: ($env | get -i $key)}
    }

    # Set new values
    $vars | transpose key value | each { |kv|
        load-env {($kv.key): $kv.value}
    }

    try {
        do $action
    } catch { |err|
        # Restore on error
        $saved | each { |kv|
            if $kv.value != null {
                load-env {($kv.key): $kv.value}
            }
        }
        error make { msg: $err.msg }
    }

    # Restore after success
    $saved | each { |kv|
        if $kv.value != null {
            load-env {($kv.key): $kv.value}
        }
    }
}
```

### Builder Pattern Command

```nushell
def query-builder [table: string] -> record {
    {
        table: $table
        columns: ["*"]
        conditions: []
        order: null
        limit: null
    }
}

def "query select" [columns: list<string>] -> record {
    $in | update columns $columns
}

def "query where" [condition: string] -> record {
    $in | update conditions { |q| $q.conditions ++ [$condition] }
}

def "query order-by" [column: string, --desc] -> record {
    $in | update order $"($column)(if $desc { ' DESC' } else { '' })"
}

def "query limit" [n: int] -> record {
    $in | update limit $n
}

def "query build" [] -> string {
    let q = $in
    let cols = $q.columns | str join ", "
    let where_clause = if ($q.conditions | is-empty) { "" } else {
        " WHERE " + ($q.conditions | str join " AND ")
    }
    let order_clause = if $q.order == null { "" } else { $" ORDER BY ($q.order)" }
    let limit_clause = if $q.limit == null { "" } else { $" LIMIT ($q.limit)" }

    $"SELECT ($cols) FROM ($q.table)($where_clause)($order_clause)($limit_clause)"
}

# Usage:
query-builder "users"
| query select [name, email]
| query where "active = 1"
| query order-by "created_at" --desc
| query limit 10
| query build
```

---

## Export Patterns

### Selective Exports

```nushell
# Export for external use
export def public-api [] { ... }

# Keep internal (not exported)
def internal-helper [] { ... }

# Export constant
export const VERSION = "1.0.0"

# Export with use *
export def main [] { ... }
```

### Re-export from Submodules

```nushell
# mod.nu
export use ./commands.nu *
export use ./utils.nu [helper1, helper2]
export use ./types.nu *
```
