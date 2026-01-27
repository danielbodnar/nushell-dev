---
name: nushell-fundamentals
description: This skill should be used when the user asks to "write a Nushell script", "create a Nushell command", "understand Nushell syntax", "work with Nushell pipelines", "use closures in Nushell", "create a Nushell module", "define an overlay", "understand Nushell types", or mentions core Nushell concepts like pipelines, closures, modules, overlays, custom commands, or type annotations.
version: 1.0.0
---

# Nushell Fundamentals

Comprehensive reference for core Nushell language patterns, syntax, and best practices. Nushell treats data as structured tables rather than text streams, enabling type-safe pipelines and powerful data manipulation.

## Core Philosophy

Nushell follows the Unix philosophy with modern enhancements:
- **Everything is data** - Commands return structured tables, records, and lists
- **Pipelines are typed** - Data flows with known shapes between commands
- **Errors are values** - Explicit error handling, not silent failures
- **Help is built-in** - Every command has discoverable documentation

## Data Types

### Primitive Types

| Type | Example | Description |
|------|---------|-------------|
| `int` | `42`, `-17` | 64-bit signed integers |
| `float` | `3.14`, `1e-5` | 64-bit floating point |
| `string` | `"hello"`, `'world'` | UTF-8 text |
| `bool` | `true`, `false` | Boolean values |
| `duration` | `5min`, `2hr`, `1day` | Time durations |
| `filesize` | `10kb`, `1gb`, `512mb` | File sizes |
| `date` | `2024-01-15` | Date/datetime |
| `nothing` | `null` | Absence of value |
| `binary` | `0x[FF 00 AB]` | Raw bytes |

### Structured Types

| Type | Syntax | Description |
|------|--------|-------------|
| `list` | `[1, 2, 3]` | Ordered collection |
| `record` | `{name: "foo", value: 42}` | Key-value mapping |
| `table` | `[[a, b]; [1, 2], [3, 4]]` | List of records |
| `closure` | `{\|x\| $x + 1}` | Anonymous function |

### Type Annotations

Annotate function parameters and return types for safety:

```nushell
def greet [name: string] -> string {
    $"Hello, ($name)!"
}

def add [a: int, b: int] -> int {
    $a + $b
}

# Optional parameters with defaults
def connect [host: string, --port: int = 8080] {
    # ...
}

# Rest parameters
def sum [...nums: int] -> int {
    $nums | math sum
}
```

## Pipelines

### Basic Pipeline Flow

```nushell
# Data flows left to right through pipes
ls | where size > 1mb | sort-by modified | first 5

# Each stage receives the output of the previous
open data.json | get users | where active == true
```

### Pipeline Input/Output

Commands declare their pipeline signature:
- **Input type** - What data the command accepts
- **Output type** - What data the command produces

```nushell
# nothing -> table<name, size, modified>
ls

# table -> table (filters rows)
where size > 1mb

# any -> any (transforms each element)
each { |it| $it.name | str upcase }
```

### Spreading into Pipelines

Use spread operator for multiple values:

```nushell
[...[1, 2], ...[3, 4]] # [1, 2, 3, 4]
{...{a: 1}, ...{b: 2}} # {a: 1, b: 2}
```

## Custom Commands

### Basic Definition

```nushell
# Simple command
def hello [] {
    "Hello, World!"
}

# With typed parameters
def greet [name: string] {
    print $"Hello, ($name)!"
}
```

### Flags and Options

```nushell
def fetch-data [
    url: string           # Required positional
    --format: string      # Optional flag with value
    --verbose (-v)        # Boolean flag with short form
    --timeout: duration = 30sec  # Flag with default
] {
    # Implementation
}

# Usage: fetch-data https://api.example.com --format json -v
```

### Documentation

```nushell
# Fetch data from a URL
#
# Returns the response body parsed according to format.
#
# Examples:
#   fetch-data https://api.example.com
#   fetch-data https://api.example.com --format json --verbose
def fetch-data [
    url: string           # The URL to fetch
    --format: string      # Response format (json, text, binary)
    --verbose (-v)        # Enable verbose output
] -> any {
    # Implementation
}
```

## Closures

### Syntax

```nushell
# Explicit parameter
let double = {|x| $x * 2}

# Using $in for implicit input
let double = { $in * 2 }

# Multiple parameters
let add = {|a, b| $a + $b}
```

### Common Uses

```nushell
# Iteration
[1, 2, 3] | each { |n| $n * 2 }

# Filtering
ls | where { |f| $f.size > 1mb }

# Reduction
[1, 2, 3, 4] | reduce { |acc, x| $acc + $x }

# Transformation
{name: "test", value: 42} | update value { |r| $r.value * 2 }
```

## Modules

### Creating a Module

```nushell
# math-utils.nu
export def double [n: int] -> int {
    $n * 2
}

export def square [n: int] -> int {
    $n * $n
}

# Private (not exported)
def helper [] {
    # Internal use only
}
```

### Using Modules

```nushell
# Import entire module
use math-utils.nu

# Import specific commands
use math-utils.nu [double, square]

# Import with prefix
use math-utils.nu *
```

### Module Constants

```nushell
# config.nu
export const VERSION = "1.0.0"
export const API_URL = "https://api.example.com"
```

## Overlays

Overlays provide scoped environments that can be added/removed:

```nushell
# Create overlay from module
overlay use ./my-env.nu

# List active overlays
overlay list

# Remove overlay
overlay hide my-env

# Create named overlay
overlay new dev-env

# Add commands to current overlay
def my-cmd [] { "hello" }
```

### Overlay Use Cases

- **Development environments** - Different tool versions
- **Project-specific configs** - Custom commands per project
- **Feature flags** - Enable/disable functionality

## Control Flow

### Conditionals

```nushell
if $condition {
    # true branch
} else if $other {
    # else if branch
} else {
    # false branch
}

# Match expressions
match $value {
    "a" => "got a"
    "b" | "c" => "got b or c"
    $x if $x > 10 => "big number"
    _ => "default"
}
```

### Loops

```nushell
# For loop
for item in [1, 2, 3] {
    print $item
}

# While loop
mut counter = 0
while $counter < 10 {
    $counter = $counter + 1
}

# Loop with break/continue
loop {
    if $condition { break }
    continue
}
```

### Error Handling

```nushell
# Try/catch
try {
    risky-operation
} catch { |err|
    print $"Error: ($err.msg)"
}

# Propagate errors
def safe-divide [a: int, b: int] -> int {
    if $b == 0 {
        error make { msg: "Division by zero" }
    }
    $a / $b
}
```

## Variables and Scope

### Immutable by Default

```nushell
let name = "value"        # Immutable
mut counter = 0           # Mutable
const PI = 3.14159        # Compile-time constant
```

### Environment Variables

```nushell
$env.MY_VAR = "value"     # Set
$env.MY_VAR               # Read
$env.MY_VAR?              # Read with null fallback
hide-env MY_VAR           # Remove
```

### Scope Rules

```nushell
let outer = "outer"
do {
    let inner = "inner"    # Scoped to block
    print $outer           # Can access outer
}
# $inner not accessible here
```

## String Interpolation

```nushell
let name = "world"
$"Hello, ($name)!"              # Interpolated string
$"Math: (2 + 2)"                # Expressions work
$"Today: (date now | format date '%Y-%m-%d')"  # Pipelines work

# Raw strings (no interpolation)
r#'Hello, ($name)!'#            # Literal: Hello, ($name)!
```

## Help System

Access built-in documentation:

```nushell
help commands              # List all commands
help modules               # List modules
help operators             # Operator reference
help escapes               # Escape sequences
help pipe-and-redirect     # Pipeline syntax

help ls                    # Specific command help
help str                   # Subcommand category
```

## Additional Resources

### Reference Files

For detailed patterns and advanced techniques:
- **`references/patterns.md`** - Idiomatic Nushell patterns
- **`references/type-system.md`** - Complete type system reference
- **`references/module-patterns.md`** - Module organization patterns

### Example Files

Working examples in `examples/`:
- **`basic-script.nu`** - Simple script template
- **`custom-command.nu`** - Command definition patterns
- **`module-example/`** - Complete module structure

### Scripts

Utility scripts in `scripts/`:
- **`validate-syntax.nu`** - Validate .nu file syntax
