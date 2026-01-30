# CLI Robustness Guidelines

> Reference: https://clig.dev/#robustness-and-future-proofing

Building robust CLI tools means anticipating failure, handling edge cases gracefully,
and ensuring your tool remains reliable across diverse environments and use cases.

---

## Input Validation

Validate all input as early as possible. Fail fast with clear error messages.

### Principles

- Check required arguments before any processing
- Validate file paths exist before operations
- Verify data formats match expectations
- Provide specific error messages about what's wrong

### Nushell Implementation

```nushell
# Comprehensive input validation
def process-file [
    path: string        # Path to input file
    --format: string    # Expected format (json, yaml, toml)
] {
    # Validate path is not empty
    if ($path | is-empty) {
        error make {
            msg: "Input path cannot be empty"
            label: {
                text: "required argument"
                span: (metadata $path).span
            }
        }
    }

    # Validate file exists
    if not ($path | path exists) {
        error make {
            msg: $"File not found: ($path)"
            help: "Ensure the file path is correct and the file exists"
        }
    }

    # Validate it's a file, not directory
    if ($path | path type) != "file" {
        error make {
            msg: $"Expected a file, got: ($path | path type)"
        }
    }

    # Validate format if specified
    let valid_formats = ["json", "yaml", "toml", "nuon"]
    if ($format | is-not-empty) and ($format not-in $valid_formats) {
        error make {
            msg: $"Invalid format: ($format)"
            help: $"Valid formats: ($valid_formats | str join ', ')"
        }
    }

    # Continue with processing...
    open $path
}

# Type-safe validation with custom types
def validate-url [url: string] -> bool {
    $url | str starts-with "http://" or ($url | str starts-with "https://")
}

def fetch-data [
    url: string     # URL to fetch
] {
    if not (validate-url $url) {
        error make {
            msg: "Invalid URL format"
            help: "URL must start with http:// or https://"
        }
    }
    http get $url
}
```

---

## Responsiveness Over Speed

Users perceive tools as fast when they respond quickly, even if the total operation takes time.
Print something within 100ms to show the tool is working.

### Principles

- Acknowledge input immediately
- Show progress for operations > 1 second
- Provide intermediate feedback during long operations
- Don't buffer output unnecessarily

### Nushell Implementation

```nushell
# Immediate acknowledgment pattern
def long-operation [files: list<string>] {
    print "Starting operation..."  # Immediate feedback

    let total = $files | length
    $files | enumerate | each { |item|
        # Progress update
        print -n $"\r\e[KProcessing ($item.index + 1)/($total): ($item.item | path basename)"

        # Actual work
        sleep 500ms  # Simulated work

        $item.item
    }

    print ""  # Clear the line
    print "Operation complete!"
}

# Streaming output for real-time feedback
def process-stream [] {
    # Stream results as they become available
    ls **/*.nu | each { |file|
        print $"Checking: ($file.name)"
        # Process and output immediately
        {
            file: $file.name
            lines: (open $file.name | lines | length)
        }
    }
}
```

---

## Progress Indicators

For operations that take more than a second, show progress.

### Types of Progress Indicators

1. **Spinner** - Unknown duration, shows activity
2. **Progress bar** - Known duration, shows completion percentage
3. **Counter** - Processing items, shows current/total
4. **Status text** - Descriptive updates about current operation

### Nushell Implementation

```nushell
# Simple spinner for unknown duration
def with-spinner [message: string, action: closure] {
    let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    let pid = (random uuid)

    # Note: True async spinners require background jobs
    # This is a simplified synchronous version
    print -n $"($frames.0) ($message)"
    let result = do $action
    print $"\r\e[K✓ ($message)"
    $result
}

# Progress bar implementation
def progress-bar [current: int, total: int, width: int = 40] -> string {
    let percent = ($current / $total)
    let filled = ($percent * $width | math round | into int)
    let empty = $width - $filled

    let bar = $"[('█' | str repeat $filled)('░' | str repeat $empty)]"
    let pct = ($percent * 100 | math round | into int)
    $"($bar) ($pct)%"
}

# Process with progress bar
def process-with-progress [items: list<any>] {
    let total = $items | length

    $items | enumerate | each { |item|
        let bar = progress-bar ($item.index + 1) $total
        print -n $"\r($bar) Processing item ($item.index + 1)..."

        # Do actual work here
        sleep 100ms

        $item.item
    }
    print ""  # Final newline
}

# Download with progress
def download-files [urls: list<string>, --output-dir: string = "."] {
    let total = $urls | length

    print $"Downloading ($total) files..."

    $urls | enumerate | each { |item|
        let url = $item.item
        let filename = $url | path basename
        let output_path = $"($output_dir)/($filename)"

        print -n $"\r\e[K[($item.index + 1)/($total)] ($filename)..."

        try {
            http get $url | save -f $output_path
            print -n " ✓"
        } catch { |err|
            print -n $" ✗ (($err.msg))"
        }
    }
    print "\nDownload complete!"
}
```

---

## Parallel Processing

When processing multiple items, parallelism can improve performance.
Ensure output remains coherent and progress reporting is thread-safe.

### Nushell Implementation

```nushell
# Parallel processing with par-each
def process-parallel [files: list<string>] {
    # par-each handles parallelism automatically
    # Output is collected and returned together
    $files | par-each { |file|
        let content = open $file
        {
            file: $file
            size: ($content | str length)
            lines: ($content | lines | length)
        }
    }
}

# Controlled parallelism with batching
def batch-process [
    items: list<any>
    --batch-size: int = 10
] {
    $items
    | chunks $batch_size
    | enumerate
    | each { |batch|
        print $"Processing batch ($batch.index + 1)..."
        $batch.item | par-each { |item|
            # Process item
            $item
        }
    }
    | flatten
}
```

---

## Timeouts

Network operations and external commands should have timeouts to prevent hanging.

### Nushell Implementation

```nushell
# HTTP requests with timeout
def fetch-with-timeout [
    url: string
    --timeout: duration = 30sec
] {
    try {
        http get $url --max-time ($timeout | into int | $in / 1_000_000_000)
    } catch { |err|
        error make {
            msg: $"Request timed out after ($timeout)"
            help: "Check network connectivity or increase --timeout"
        }
    }
}

# External command with timeout
def run-with-timeout [
    command: string
    --timeout: duration = 60sec
] {
    # Use timeout command if available
    let timeout_secs = $timeout | into int | $in / 1_000_000_000

    ^timeout $timeout_secs $command
}
```

---

## Recoverability

Design tools to continue from where they left off after interruption.

### Principles

- Save progress periodically
- Use atomic file operations
- Implement checkpointing for long operations
- Clean up partial state on startup

### Nushell Implementation

```nushell
# State file for recovery
const STATE_FILE = ".myapp-state.nuon"

def save-state [state: record] {
    $state | save -f $STATE_FILE
}

def load-state [] -> record {
    if ($STATE_FILE | path exists) {
        open $STATE_FILE
    } else {
        { completed: [], current: null, started_at: (date now | into string) }
    }
}

def clear-state [] {
    if ($STATE_FILE | path exists) {
        rm $STATE_FILE
    }
}

# Recoverable batch processing
def process-recoverable [items: list<string>] {
    mut state = load-state

    let remaining = $items | where { |item| $item not-in $state.completed }

    if ($remaining | is-empty) {
        print "All items already processed!"
        clear-state
        return
    }

    print $"Resuming: ($remaining | length) items remaining..."

    for item in $remaining {
        $state.current = $item
        save-state $state

        print $"Processing: ($item)"
        # Do actual work...
        sleep 500ms

        $state.completed = ($state.completed | append $item)
        $state.current = null
        save-state $state
    }

    print "Complete!"
    clear-state
}

# Atomic file writes
def save-atomic [path: string, content: any] {
    let temp_path = $"($path).tmp.(random uuid)"

    # Write to temp file first
    $content | save -f $temp_path

    # Atomic rename
    mv -f $temp_path $path
}
```

---

## Crash-Only Design

Design tools that can crash safely and recover on next run.
Don't rely on graceful shutdown - assume the process can die at any point.

### Principles

- Clean up stale state on startup, not shutdown
- Use atomic operations for critical data
- Prefer idempotent operations
- Log enough to understand what happened

### Nushell Implementation

```nushell
# Crash-safe startup routine
def main [] {
    # Clean up any stale state from previous runs
    cleanup-stale-state

    # Check for incomplete operations
    if (has-incomplete-work) {
        print "Found incomplete work from previous run..."
        if (confirm-resume) {
            resume-work
        } else {
            discard-incomplete-work
        }
    }

    # Normal operation...
}

def cleanup-stale-state [] {
    # Remove old temp files
    glob "*.tmp.*" | each { |f| rm -f $f }

    # Remove stale lock files older than 1 hour
    glob "*.lock" | where {
        ((date now) - ($in | path stat).modified) > 1hr
    } | each { |f|
        print $"Removing stale lock: ($f)"
        rm -f $f
    }
}

def has-incomplete-work [] -> bool {
    ".myapp-state.nuon" | path exists
}

def confirm-resume [] -> bool {
    if (term size | is-not-empty) {
        (input "Resume previous work? (y/n): ") == "y"
    } else {
        true  # Auto-resume in non-interactive mode
    }
}
```

---

## Anticipate Misuse

Your tool will be used in ways you didn't anticipate.

### Scenarios to Consider

- Running from scripts (no TTY)
- Multiple instances simultaneously
- Unreliable networks
- Insufficient disk space
- Missing dependencies

### Nushell Implementation

```nushell
# Handle non-TTY execution
def interactive-or-fail [prompt: string] -> string {
    if (term size | is-empty) {
        error make {
            msg: "Interactive input required but running non-interactively"
            help: "Provide required values via command-line arguments"
        }
    }
    input $prompt
}

# Lock file for single-instance enforcement
def with-lock [lock_path: string, action: closure] {
    if ($lock_path | path exists) {
        let pid = open $lock_path | str trim
        error make {
            msg: $"Another instance is running (PID: ($pid))"
            help: $"Remove ($lock_path) if the other instance is not running"
        }
    }

    # Create lock file
    $nu.pid | save $lock_path

    try {
        do $action
    } catch { |err|
        rm -f $lock_path
        error make { msg: $err.msg }
    }

    rm -f $lock_path
}

# Check available disk space
def check-disk-space [required_mb: int, path: string = "."] {
    # This would use df command in practice
    let available = (^df -m $path | lines | skip 1 | first | split row -r '\s+' | get 3 | into int)

    if $available < $required_mb {
        error make {
            msg: $"Insufficient disk space: ($available)MB available, ($required_mb)MB required"
        }
    }
}
```

---

## Future-Proofing

Design for long-term stability and backward compatibility.

### Principles

1. **Keep changes additive** - Add new options, don't remove old ones
2. **Warn before breaking** - Deprecation notices before removal
3. **Human vs machine output** - Human output can evolve; machine output is contract
4. **No catch-all subcommands** - Explicit is better than implicit
5. **No arbitrary abbreviations** - Full names are documentation

### Nushell Implementation

```nushell
# Deprecation warning
def old-command [...args] {
    print --stderr "Warning: 'old-command' is deprecated, use 'new-command' instead"
    new-command ...$args
}

# Versioned output formats
def output-data [
    data: any
    --format: string = "human"  # human, json, json-v2
] {
    match $format {
        "human" => { $data | table }
        "json" => { $data | to json }  # v1 format - stable contract
        "json-v2" => { { version: 2, data: $data } | to json }
        _ => { error make { msg: $"Unknown format: ($format)" } }
    }
}

# Explicit subcommands (no catch-all)
export def "myapp config" [] {
    print "Usage: myapp config <get|set|list>"
}

export def "myapp config get" [key: string] {
    # Explicit get command
}

export def "myapp config set" [key: string, value: any] {
    # Explicit set command
}
```

---

## Signal Handling

Handle interruption signals gracefully.

### Principles

- First Ctrl-C: Cleanup and exit gracefully
- Second Ctrl-C: Exit immediately, skip cleanup
- Save any in-progress work before exiting

### Nushell Implementation

```nushell
# Note: Nushell handles Ctrl-C at the shell level
# For custom handling, use try/catch patterns

def interruptible-operation [items: list<any>] {
    mut processed = []

    for item in $items {
        # Nushell will interrupt on Ctrl-C here
        # Progress is lost unless we save state

        # Save progress before each item
        { processed: $processed, current: $item } | save -f ".progress.nuon"

        # Process item
        print $"Processing: ($item)"
        sleep 1sec

        $processed = ($processed | append $item)
    }

    # Cleanup progress file on success
    rm -f ".progress.nuon"
    $processed
}
```

---

## Summary Checklist

- [ ] Validate all input early with clear error messages
- [ ] Print something within 100ms to show responsiveness
- [ ] Show progress for operations > 1 second
- [ ] Use timeouts for network operations
- [ ] Implement checkpointing for long operations
- [ ] Design for crash recovery (cleanup on startup)
- [ ] Handle non-TTY execution
- [ ] Prevent multiple simultaneous instances when needed
- [ ] Keep changes additive for backward compatibility
- [ ] Separate human and machine output formats
- [ ] Handle Ctrl-C gracefully
