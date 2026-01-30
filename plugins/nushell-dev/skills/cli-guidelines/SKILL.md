---
name: cli-guidelines
description: This skill should be used when the user asks to "build a CLI tool", "create command-line interface", "CLI best practices", "clig.dev guidelines", "help text patterns", "CLI arguments", "CLI error messages", "CLI output formatting", "human-first design", "CLI interactivity", "exit codes", "CLI configuration", "environment variables", or mentions building user-facing Nushell scripts, commands, or tools that should follow professional CLI design principles.
version: 1.0.0
---

# CLI Guidelines for Nushell

Comprehensive reference for building excellent command-line interfaces in Nushell, based on [clig.dev](https://clig.dev) principles and adapted for Nushell's structured data paradigm. Great CLIs are not just functional - they are empathetic, discoverable, consistent, and robust.

## Why CLI Guidelines Matter

Command-line interfaces are often the primary way developers and power users interact with tools. A well-designed CLI:

- **Reduces cognitive load** - Users can focus on their tasks, not fighting the tool
- **Builds trust** - Consistent, predictable behavior creates confidence
- **Enables automation** - Scripts and pipelines work reliably
- **Scales knowledge** - Learning one well-designed CLI transfers to others

## Core Philosophy from clig.dev

The eight principles that guide excellent CLI design:

### 1. Human-First Design

**Humans come first, machines second.** Optimize for human understanding by default.

```nushell
# Human-friendly: structured output Nushell displays beautifully
def "files analyze" [path: path = "."] -> table {
    ls $path
    | where type == "file"
    | select name size modified
    | sort-by size --reverse
    | first 10
}

# Machine-readable when needed: one pipe away
# files analyze | to json
# files analyze | to csv
```

**Nushell advantage:** Tables and records are both human-readable AND machine-parseable. No need to choose.

### 2. Simple Parts That Work Together

**Do one thing well.** Build small, focused commands that compose via pipelines.

```nushell
# GOOD: Single responsibility, composable
export def "git branches-merged" [] {
    git branch --merged
    | lines
    | where $it !~ '\*'
    | str trim
}

# Can be composed: git branches-merged | each { git branch -d $in }

# BAD: Trying to do too much
export def "git-cleanup-everything" [] {
    # Fetches, prunes, deletes merged, deletes stale, garbage collects...
    # Violates single responsibility
}
```

### 3. Consistency Across Programs

**Users build mental models. Respect them.** Use standard flag names and behaviors.

| Short | Long | Purpose |
|-------|------|---------|
| `-h` | `--help` | Show help text |
| `-v` | `--verbose` | More detailed output |
| `-q` | `--quiet` | Suppress non-error output |
| `-f` | `--force` | Skip confirmations |
| `-n` | `--dry-run` | Preview without changes |
| `-o` | `--output` | Output file or destination |
| `-r` | `--recursive` | Include subdirectories |

```nushell
# Consistent across your entire toolset
export def "backup create" [
    source: path
    destination: path
    --verbose (-v)
    --quiet (-q)
    --force (-f)
    --recursive (-r)
    --dry-run (-n)
] {
    # Users learn once, apply everywhere
}
```

### 4. Saying Just Enough

**Balance silence and verbosity.** Default to useful information, not noise.

```nushell
# Default: Essential information only
export def "deploy status" [--verbose (-v)] {
    let status = get-deployment-status

    if $verbose {
        # Full details when requested
        $status | table --expand
    } else {
        # Concise default
        print $"Status: ($status.state) | Uptime: ($status.uptime)"
    }
}

# Silent success for scripts
export def "cache clear" [--quiet (-q)] {
    rm -rf ~/.cache/myapp

    if not $quiet {
        print "Cache cleared successfully"
    }
}
```

### 5. Ease of Discovery

**Users should learn your CLI by using it.** Make help accessible and thorough.

```nushell
# Nushell's def comments become built-in help
# Run: help task add

# Add a new task to the task list
#
# Creates a task with the given title and optional metadata.
# Tasks are stored in ~/.local/share/tasks/tasks.nuon
#
# Examples:
#   task add "Fix bug in parser"
#   task add "Review PR" --priority 5 --due 2024-03-15
#   task add "Weekly meeting" --tags ["recurring", "team"]
export def "task add" [
    title: string           # The task title (required)
    --priority (-p): int    # Priority level 1-5 (default: 3)
    --due (-d): datetime    # Due date in any parseable format
    --tags (-t): list<string>  # Tags for categorization
] {
    # Implementation
}

# Typing `task` alone shows available subcommands
export def "task" [] {
    print "Task management commands:"
    print ""
    print "  task add      - Create a new task"
    print "  task list     - Show all tasks"
    print "  task complete - Mark task as done"
    print "  task delete   - Remove a task"
    print ""
    print "Run 'help task <command>' for details"
}
```

### 6. Conversation as the Norm

**Treat CLI interaction as a dialogue.** Confirm destructive actions and show progress.

```nushell
# Confirmation for destructive actions
export def "data purge" [
    --force (-f)    # Skip confirmation
    --dry-run (-n)  # Show what would be deleted
] {
    let items = (ls data/ | length)

    if $dry_run {
        print $"Would delete ($items) items"
        return
    }

    if not $force {
        let confirm = input $"Delete ($items) items? This cannot be undone. [y/N] "
        if ($confirm | str downcase) != "y" {
            print "Aborted."
            return
        }
    }

    rm -rf data/*
    print $"Deleted ($items) items"
}

# Progress for long operations
export def "sync remote" [--verbose (-v)] {
    let files = (ls -r src/ | where type == "file")
    let total = ($files | length)

    $files | enumerate | each { |item|
        if $verbose {
            print -e $"Syncing [($item.index + 1)/($total)]: ($item.item.name)"
        }
        upload-file $item.item.name
    }

    print $"Synced ($total) files"
}
```

### 7. Robustness

**Handle edge cases gracefully. Fail fast with clear messages.**

```nushell
export def "file process" [path: path] {
    # Validate early with helpful messages
    if not ($path | path exists) {
        error make {
            msg: $"File not found: ($path)"
            help: "Check the path and try again. Use 'ls' to see available files."
        }
    }

    if ($path | path type) != "file" {
        error make {
            msg: $"Expected a file, got: ($path | path type)"
            help: "Use --recursive for directories"
        }
    }

    # Wrap risky operations
    try {
        open $path | process-contents
    } catch { |err|
        error make {
            msg: $"Failed to process ($path)"
            help: $"File may be corrupted or unsupported format.\nOriginal: ($err.msg)"
        }
    }
}
```

### 8. Empathy

**Remember: users are often stressed, debugging, or learning.** Be helpful.

```nushell
# Helpful error messages with actionable suggestions
export def "config validate" [path: path = "config.toml"] {
    if not ($path | path exists) {
        print $"(ansi red)Error:(ansi reset) Config file not found: ($path)"
        print ""
        print "To create a default config:"
        print $"  (ansi cyan)config init(ansi reset)"
        print ""
        print "Or specify a different path:"
        print $"  (ansi cyan)config validate /path/to/config.toml(ansi reset)"
        exit 1
    }

    # Validate with specific fix suggestions
    let errors = validate-config $path
    if ($errors | length) > 0 {
        print $"(ansi yellow)Found ($errors | length) issue(s):(ansi reset)"
        $errors | each { |e|
            print $"  Line ($e.line): ($e.message)"
            if ($e.suggestion | is-not-empty) {
                print $"    (ansi dim)Fix: ($e.suggestion)(ansi reset)"
            }
        }
    }
}
```

## Nushell's Natural Advantages

Nushell inherently supports many CLI guidelines through its design:

| CLI Guideline | Nushell Feature |
|---------------|-----------------|
| Structured output | Tables, records, lists - native data types |
| Type safety | Built-in type system validates input |
| Self-documenting | `def` comments become `help` output |
| Error handling | `try`/`catch` with rich error messages |
| Composability | Pipeline-native, structured data flows |
| Discoverability | Tab completion, `help` system |

## Quick Reference: CLI Concepts to Nushell

| CLI Concept | Nushell Feature | Example |
|-------------|-----------------|---------|
| Help text | Documentation comments | `# Description\ndef cmd []` |
| Arguments | `def` parameters | `def cmd [file: path]` |
| Flags | Named parameters | `--verbose (-v)` |
| Optional args | Default values | `file: string = "default"` |
| Rest args | Spread parameter | `...files: path` |
| Subcommands | Space-separated names | `def "git commit" []` |
| Stdout | Return values | `$data` |
| Stderr | `print -e` | `print -e "Warning"` |
| Exit codes | `exit` command | `exit 1` |
| Machine output | Format conversions | `\| to json`, `\| to csv` |
| Config | Environment + files | `$env.MY_CONFIG`, `open ~/.config/` |
| stdin | `$in` variable | `$in \| each {}` |

## The 10 CLI Commandments

### 1. Make Help Helpful

```nushell
# Fetch data from a remote API endpoint
#
# Retrieves JSON data and returns it as a Nushell table.
# Supports authentication via environment variable or flag.
#
# Examples:
#   fetch-api https://api.example.com/users
#   fetch-api https://api.example.com/users --token $env.API_TOKEN
#   fetch-api https://api.example.com/users | where active == true
def fetch-api [
    url: string              # The API endpoint URL
    --token (-t): string     # Authentication token (or use $env.API_TOKEN)
    --timeout: duration = 30sec  # Request timeout
    --raw (-r)               # Return raw response without parsing
] -> table {
    # Implementation
}
```

### 2. Prefer Flags to Arguments

```nushell
# AVOID: Positional args for optional behavior
def bad-copy [source: path, dest: path, recursive: bool] { }

# PREFER: Flags for optional behavior
def copy-files [
    source: path             # Source file or directory
    dest: path               # Destination path
    --recursive (-r)         # Copy directories recursively
    --force (-f)             # Overwrite without prompting
    --preserve (-p)          # Preserve file attributes
] { }
```

### 3. Output for Humans by Default

```nushell
def list-services [] -> table {
    # Structured data - beautiful for humans, convertible for machines
    [
        { name: "api", status: "running", port: 8080, uptime: 5day }
        { name: "db", status: "running", port: 5432, uptime: 12day }
        { name: "cache", status: "stopped", port: null, uptime: null }
    ]
}
```

### 4. Enable Machine Output When Needed

```nushell
def get-status [
    --json (-j)              # Output as JSON
    --quiet (-q)             # Output only status code
] {
    let status = get-current-status

    if $quiet { $status.code }
    else if $json { $status | to json }
    else { $status }
}
```

### 5. Handle Errors with Care

```nushell
def process-file [file: path] {
    if not ($file | path exists) {
        error make {
            msg: $"File not found: ($file)"
            help: "Check the file path. Use 'ls' to see available files."
        }
    }

    try {
        open $file | process-contents
    } catch { |err|
        error make {
            msg: $"Failed to process ($file)"
            help: $"File may be corrupted.\nOriginal: ($err.msg)"
        }
    }
}
```

### 6. Use Sensible Exit Codes

| Code | Meaning | Use Case |
|------|---------|----------|
| 0 | Success | Operation completed |
| 1 | General error | Something went wrong |
| 2 | Usage error | Invalid arguments/flags |
| 78 | Config error | Configuration problem |
| 126 | Not executable | Permission issue |
| 127 | Not found | Command/file missing |

### 7. Support Configuration Hierarchy

Priority from highest to lowest:
1. Command-line flags
2. Environment variables
3. Project-local config
4. User config (`~/.config/myapp/`)
5. System config (`/etc/myapp/`)
6. Built-in defaults

### 8. Be Discoverable

```nushell
# Typing `myapp` alone shows help
def "myapp" [] { help myapp }

def "myapp init" [name: string, --template (-t): string] { }
def "myapp build" [--release (-r), --target: string] { }
def "myapp deploy" [environment: string, --dry-run] { }
```

### 9. Provide Progress Feedback

```nushell
def process-files [...files: path, --quiet (-q)] {
    let total = ($files | length)

    $files | enumerate | each { |item|
        if not $quiet {
            print -e $"Processing [($item.index + 1)/($total)]: ($item.item | path basename)"
        }
        process-single-file $item.item
    }

    if not $quiet {
        print -e $"Completed processing ($total) files"
    }
}
```

### 10. Support Interactive and Scripted Use

```nushell
def dangerous-operation [
    target: path
    --force (-f)    # Skip confirmation
    --dry-run (-n)  # Show what would happen
] {
    if $dry_run {
        print $"Would delete: ($target)"
        return
    }

    # Check if interactive
    let is_interactive = (term size | is-not-empty)

    if not $force and $is_interactive {
        let confirm = input $"Delete ($target)? [y/N] "
        if $confirm not-in ["y", "Y", "yes"] {
            print "Aborted"
            return
        }
    }

    rm -rf $target
    print $"Deleted: ($target)"
}
```

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Better Approach |
|--------------|---------|-----------------|
| Printing JSON directly | Loses Nushell's power | Return records/tables |
| Hardcoded paths | Not portable | Use XDG, `$env.HOME` |
| Silent failures | Users don't know what happened | Always report errors |
| Cryptic flags | `-xvzf` is hard to remember | Meaningful long names |
| No help text | Undiscoverable | Document everything |
| Prompts in non-interactive | Breaks scripts | Check TTY, use `--force` |
| Mixing output and status | Hard to parse | Data to stdout, status to stderr |
| Secrets as flags | Visible in `ps` | Use env vars or files |

## TTY Detection Pattern

```nushell
# Check if running in terminal
def is-terminal [] -> bool {
    (term size | is-not-empty)
}

# Prompt only when interactive
def get-input [prompt: string, --no-input] -> string {
    if $no_input {
        error make { msg: "Input required. Use appropriate flag." }
    }

    if (is-terminal) {
        input $prompt
    } else {
        error make {
            msg: "Cannot prompt: not running in terminal"
            help: "Provide value via flags or use --no-input mode"
        }
    }
}
```

## Color Usage Guidelines

```nushell
# Semantic colors
def print-error [msg: string] {
    if ($env.NO_COLOR? | is-empty) {
        print -e $"(ansi red)error:(ansi reset) ($msg)"
    } else {
        print -e $"error: ($msg)"
    }
}

def print-warning [msg: string] {
    if ($env.NO_COLOR? | is-empty) {
        print -e $"(ansi yellow)warning:(ansi reset) ($msg)"
    } else {
        print -e $"warning: ($msg)"
    }
}

def print-success [msg: string] {
    if ($env.NO_COLOR? | is-empty) {
        print $"(ansi green)success:(ansi reset) ($msg)"
    } else {
        print $"success: ($msg)"
    }
}
```

**Color conventions:**
- **Red:** Errors, failures, destructive actions
- **Yellow:** Warnings, caution
- **Green:** Success, additions
- **Blue/Cyan:** Information, paths, URLs
- **Dim:** Secondary information

## Additional Resources

### Reference Files

Detailed documentation in `references/`:
- **`philosophy.md`** - Deep dive into clig.dev principles
- **`arguments.md`** - Arguments, flags, and input patterns
- **`output.md`** - Output formatting and color
- **`errors.md`** - Error handling and exit codes
- **`help.md`** - Help text and documentation
- **`configuration.md`** - Config files and environment variables
- **`interactivity.md`** - TTY detection and prompts
- **`robustness.md`** - Edge cases and future-proofing
- **`linting-rules.md`** - Automated CLI quality checks

### Example Files

Working examples in `examples/`:
- **`cli-compliant-script.nu`** - Complete CLI following all guidelines

### Scripts

Utility scripts in `scripts/`:
- **`validate-cli.nu`** - Check if a CLI follows guidelines

### External Resources

- [clig.dev](https://clig.dev) - Command Line Interface Guidelines
- [12 Factor CLI Apps](https://medium.com/@jdxcode/12-factor-cli-apps-dd3c227a0e46) - CLI principles
- [Nushell Documentation](https://www.nushell.sh/book/) - Official Nushell book
- [NO_COLOR](https://no-color.org/) - Standard for disabling color
