# Nushell Error Handling Reference

## Error Types

### Syntax Errors

Detected during parsing, before execution.

```nushell
# Missing closing bracket
[1, 2, 3         # Error: Unclosed [

# Invalid syntax
def foo { }       # Error: Missing parameter list []

# Unexpected token
let x = = 5       # Error: Unexpected =
```

### Type Errors

Type mismatches at runtime.

```nushell
# Wrong argument type
"hello" | math sum    # Error: expected numeric input

# Invalid operation
"hello" + 5           # Error: cannot add string and int

# Missing required field
{a: 1} | get b        # Error: column 'b' not found
```

### Runtime Errors

Errors during execution.

```nushell
# Division by zero
10 / 0                # Error: division by zero

# File not found
open nonexistent.txt  # Error: file not found

# Command not found
nonexistent_command   # Error: command not found

# Index out of bounds
[1, 2, 3] | get 10    # Error: index out of bounds
```

---

## Error Handling Constructs

### try-catch

```nushell
# Basic try-catch
try {
    risky_operation
} catch {
    print "Operation failed"
}

# Catch with error variable
try {
    open missing.txt
} catch { |err|
    print $"Error: ($err.msg)"
}

# Re-throw error
try {
    risky_operation
} catch { |err|
    log-error $err.msg
    error make { msg: $err.msg }
}
```

### error make

Create custom errors with structured information.

```nushell
# Simple error
error make { msg: "Something went wrong" }

# Error with label (points to source)
error make {
    msg: "Invalid value"
    label: {
        text: "this value is invalid"
        span: (metadata $value).span
    }
}

# Error with help text
error make {
    msg: "Configuration missing"
    help: "Set the CONFIG_PATH environment variable"
}

# Full error structure
error make {
    msg: "Validation failed"
    label: {
        text: "invalid field"
        span: (metadata $input).span
    }
    help: "Ensure all required fields are present"
}
```

### complete

Capture command result including exit status.

```nushell
# Capture external command result
let result = do { ^git status } | complete

$result.exit_code     # 0 if success
$result.stdout        # Standard output
$result.stderr        # Standard error

# Check for failure
if $result.exit_code != 0 {
    print $"Failed: ($result.stderr)"
}
```

---

## Error Patterns

### Guard Clauses

```nushell
def process [input: any] {
    # Validate early
    if ($input | is-empty) {
        error make { msg: "Input cannot be empty" }
    }

    if ($input | describe) != "record" {
        error make { msg: "Input must be a record" }
    }

    # Process valid input
    $input | transform
}
```

### Result Pattern

```nushell
# Return structured result
def safe-parse [input: string] -> record {
    try {
        {ok: true, value: ($input | from json)}
    } catch { |err|
        {ok: false, error: $err.msg}
    }
}

# Usage
let result = safe-parse $input
if $result.ok {
    process $result.value
} else {
    print $"Parse error: ($result.error)"
}
```

### Optional with Default

```nushell
# Safe field access with default
$record.maybe? | default "fallback"

# Safe command with default
try { open config.toml } catch { {} }

# Chain of defaults
$env.CUSTOM_CONFIG?
| default ($env.HOME | path join ".config" "app.toml")
| open
```

### Retry Pattern

```nushell
def with-retry [action: closure, --max: int = 3, --delay: duration = 1sec] {
    mut last_error = ""

    for attempt in 1..=$max {
        try {
            return (do $action)
        } catch { |err|
            $last_error = $err.msg
            if $attempt < $max {
                print $"Attempt ($attempt) failed, retrying..."
                sleep $delay
            }
        }
    }

    error make { msg: $"Failed after ($max) attempts: ($last_error)" }
}

# Usage
with-retry { http get "https://api.example.com/unstable" }
```

### Graceful Degradation

```nushell
def fetch-with-fallback [primary: string, fallback: string] {
    try {
        http get $primary
    } catch {
        print "Primary failed, using fallback..."
        try {
            http get $fallback
        } catch { |err|
            error make { msg: $"All sources failed: ($err.msg)" }
        }
    }
}
```

---

## Error Information

### Accessing Error Details

```nushell
try {
    operation
} catch { |err|
    # Error message
    $err.msg

    # Full error record
    $err | describe

    # Check error type
    if ($err.msg | str contains "not found") {
        handle-not-found
    }
}
```

### Metadata for Source Location

```nushell
def validate [value: any] {
    if ($value | is-empty) {
        error make {
            msg: "Value is empty"
            label: {
                text: "this value"
                span: (metadata $value).span  # Points to source
            }
        }
    }
}
```

---

## Error Display Configuration

### Error Style

```nushell
# Fancy (default) - with line drawings
$env.config.error_style = "fancy"

# Plain - for screen readers
$env.config.error_style = "plain"

# Short - single line
$env.config.error_style = "short"

# Nested - fancy with nesting
$env.config.error_style = "nested"
```

### Context Lines

```nushell
# Number of context lines in error output
$env.config.error_lines = 3
```

### Exit Code Display

```nushell
# Show error for non-zero exit codes
$env.config.display_errors.exit_code = true

# Show error for signal termination
$env.config.display_errors.termination_signal = true
```

---

## Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| `column 'x' not found` | Missing record field | Use `get -i` or `?` operator |
| `division by zero` | Dividing by zero | Check divisor before division |
| `file not found` | Invalid path | Verify path with `path exists` |
| `cannot apply '+'` | Type mismatch | Convert types first |
| `command not found` | Typo or missing | Check with `which` |
| `index out of bounds` | Invalid index | Check length first |
| `expected X, got Y` | Wrong type | Use correct type or convert |

### Solutions

```nushell
# Column not found - use optional access
$record.field? | default "missing"

# Division - check first
if $b != 0 { $a / $b } else { 0 }

# File - check existence
if ($path | path exists) { open $path }

# Index - check bounds
if $index < ($list | length) { $list | get $index }

# Type - convert first
$value | into int
```

---

## Debugging Errors

### Print Debugging

```nushell
# Print and pass through
$data | debug | process

# Print with label
$data | debug "before transform" | transform | debug "after transform"
```

### Inspect Types

```nushell
# Check type
$value | describe

# Check structure
$table | schema
$record | columns
```

### Trace Execution

```nushell
# Verbose mode for commands
ls --long

# Check command signature
help command_name
```
