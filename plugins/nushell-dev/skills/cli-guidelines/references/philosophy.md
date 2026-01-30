# CLI Design Philosophy for Nushell

> Human-first design principles adapted from clig.dev for modern Nushell development

---

## 1. Human-First Design

**Principle:** Design for humans as the primary audience. While scripts and automation matter, optimize for human understanding, comfort, and cognitive load.

### Nushell Implementation

Leverage structured data, meaningful defaults, and readable output formats.

```nushell
# Human-first: Provide meaningful output, not cryptic codes
export def "files analyze" [
    path: path = "."  # Directory to analyze
] {
    ls $path
    | where type == "file"
    | select name size modified
    | sort-by size --reverse
    | first 10
    | update size { into filesize }  # 1.0 MiB not 1048576
    | update modified { format date "%Y-%m-%d %H:%M" }
}
```

### Anti-patterns

```nushell
# BAD: Cryptic machine-first output
export def "files stat" [path: path] {
    ls $path | get size | math sum  # Returns raw bytes: 15728640
}

# BAD: Abbreviations over clarity
export def "fs" [p: path, f?: string] {  # What does 'fs', 'p', 'f' mean?
    # ...
}
```

---

## 2. Simple Parts That Work Together

**Principle:** Unix philosophy modernized. Build small, focused tools that emit structured data. Expect your output to become someone else's input.

### Nushell Implementation

Design commands that return structured data (records, tables) rather than formatted strings.

```nushell
# Single responsibility: list merged branches
export def "git branches-merged" [] {
    git branch --merged
    | lines
    | where $it !~ '\*'
    | str trim
}

# Composes naturally with other commands
# git branches-merged | where $it != "main" | each { git branch -d $in }

# Emit structured data for downstream consumption
export def "deps list" [] {
    open package.json
    | get dependencies
    | transpose name version
}
# deps list | where version =~ "^1\." | get name
```

### Anti-patterns

```nushell
# BAD: Monolithic command doing everything
export def "git-cleanup-everything" [] {
    # Fetches, prunes, deletes merged, deletes stale, garbage collects
    # Violates single responsibility, impossible to compose
}

# BAD: String output instead of structured data
export def "users list" [] {
    "john:admin\nmary:user\nbob:guest"  # Requires parsing downstream
}
```

---

## 3. Consistency

**Principle:** Respect conventions and muscle memory. Users invest time learning patterns; honor that investment.

### Nushell Implementation

Use standard flag names and patterns users already know.

```nushell
# Standard flags everyone expects
export def "backup create" [
    source: path              # Source directory
    destination: path         # Destination directory
    --verbose (-v)            # Show detailed progress
    --quiet (-q)              # Suppress non-error output
    --force (-f)              # Overwrite existing files
    --recursive (-r)          # Include subdirectories
    --dry-run (-n)            # Show what would happen
] {
    # Implementation
}

# Consistent CRUD pattern across your toolset
export def "config get" [key: string] { }
export def "config set" [key: string, value: any] { }
export def "config list" [] { }
export def "config delete" [key: string] { }
```

### Anti-patterns

```nushell
# BAD: Reinventing standard flags
export def "copy files" [
    --chatty        # Use --verbose (-v)
    --yolo          # Use --force (-f)
    --peek          # Use --dry-run (-n)
]

# BAD: Inconsistent patterns
export def "user add" [] { }
export def "remove-user" [] { }  # Inconsistent naming
export def "users" [] { }        # Is this list? Show? Different pattern
```

---

## 4. Saying Just Enough

**Principle:** Balance silence and verbosity. Default to useful information without noise. Let users request more detail.

### Nushell Implementation

Progressive disclosure: essential info by default, details on request.

```nushell
# Default: Essential information only
export def "deploy status" [
    --verbose (-v)  # Show detailed status
] {
    let status = (get-deployment-status)

    if $verbose {
        $status | table --expand
    } else {
        # Concise summary
        print $"Status: ($status.state) | Uptime: ($status.uptime)"
    }
}

# Silent success for scriptable commands
export def "cache clear" [
    --quiet (-q)  # Suppress output on success
] {
    rm -rf ~/.cache/myapp | ignore

    if not $quiet {
        print "Cache cleared"
    }
}
```

### Anti-patterns

```nushell
# BAD: Too noisy by default
export def "compile" [] {
    print "Starting compilation..."
    print "Loading configuration..."
    print "Checking dependencies..."
    print "Compiling file 1 of 847..."
    # Overwhelming output for simple operation
}

# BAD: Too silent, no feedback
export def "deploy prod" [] {
    # Does dangerous things with zero output
    # User has no idea what happened
}
```

---

## 5. Ease of Discovery

**Principle:** Make CLIs learnable like GUIs. Users should discover features by exploring, not by reading manuals.

### Nushell Implementation

Leverage Nushell's auto-generated help and provide guidance when commands run without arguments.

```nushell
# Documentation comments become built-in help
# Run: help task add
export def "task add" [
    title: string              # The task title (required)
    --priority (-p): int       # Priority level 1-5 (default: 3)
    --due (-d): datetime       # Due date
    --tags (-t): list<string>  # Tags for categorization
] {
    # Implementation
}

# Base command shows available subcommands
export def "task" [] {
    print "Task management commands:"
    print ""
    print "  task add       Create a new task"
    print "  task list      Show all tasks"
    print "  task complete  Mark task as done"
    print "  task delete    Remove a task"
    print ""
    print "Run 'help task <command>' for details"
}
```

### Anti-patterns

```nushell
# BAD: No help, requires external docs
export def "cryptic" [a: int, b: string, c?: list] {
    # What does this do? No way to know without source code
}

# BAD: Hanging with no output
export def "process" [] {
    # Runs silently, user doesn't know if it's working or broken
}
```

---

## 6. Conversation as the Norm

**Principle:** Treat CLI interaction as a dialogue. Support trial-and-error, step-by-step refinement, and safe exploration through dry-runs.

### Nushell Implementation

Confirm destructive actions, support dry-runs, communicate progress.

```nushell
export def "data purge" [
    --force (-f)   # Skip confirmation
    --dry-run (-n) # Show what would be deleted
] {
    let items = (ls data/ | length)

    if $dry_run {
        print $"Would delete ($items) items"
        return
    }

    if not $force {
        let confirm = (input $"Delete ($items) items? [y/N] " | str downcase)
        if $confirm != "y" {
            print "Aborted."
            return
        }
    }

    rm -rf data/*
    print $"Deleted ($items) items"
}

# Progress communication for long operations
export def "sync files" [--verbose (-v)] {
    let files = (ls -r src/ | where type == "file")
    let total = ($files | length)

    $files | enumerate | each {|item|
        if $verbose {
            print $"Syncing \(($item.index + 1)/($total)\): ($item.item.name)"
        }
        upload-file $item.item.name
    }
}
```

### Anti-patterns

```nushell
# BAD: Destructive without confirmation
export def "nuke everything" [] {
    rm -rf /important/data  # Gone forever, no warning
}

# BAD: No dry-run for risky operations
export def "migrate database" [] {
    # Modifies production with no way to preview
}
```

---

## 7. Robustness

**Principle:** Handle unexpected input gracefully. Be idempotent where possible. Fail fast and clearly when something goes wrong.

### Nushell Implementation

Validate inputs, handle edge cases, provide clear errors.

```nushell
export def "file process" [path: path] {
    # Validate existence
    if not ($path | path exists) {
        error make { msg: $"File not found: ($path)" }
    }

    # Handle edge cases
    let info = (ls $path | first)
    if $info.size == 0 {
        print "Warning: File is empty, nothing to process"
        return
    }

    # Idempotent: safe to run multiple times
    let output = ($path | path parse | update extension "processed" | path join)
    if ($output | path exists) {
        print "Already processed, skipping"
        return
    }

    process-content (open $path)
}
```

### Anti-patterns

```nushell
# BAD: Assumes everything works
export def "process" [path: path] {
    open $path | transform | save output.txt  # Crashes on missing file
}

# BAD: Silent failure
export def "send email" [to: string] {
    try { do-send $to } catch { }  # Swallows errors
}
```

---

## 8. Empathy

**Principle:** Remember users are often stressed, debugging issues, or learning. Build tools that are enjoyable to use and value users' time.

### Nushell Implementation

Helpful errors, suggest fixes, respect user time with fast feedback.

```nushell
export def "config validate" [path: path = "config.toml"] {
    if not ($path | path exists) {
        print $"(ansi red)Error:(ansi reset) Config file not found: ($path)"
        print ""
        print "To create a default config:"
        print $"  (ansi cyan)config init(ansi reset)"
        print ""
        print "Or specify a different path:"
        print $"  (ansi cyan)config validate /path/to/config.toml(ansi reset)"
        return
    }

    # Specific, actionable error messages
    let errors = (validate-config $path)
    $errors | each {|e|
        print $"  Line ($e.line): ($e.message)"
        print $"    (ansi dim)Fix: ($e.suggestion)(ansi reset)"
    }
}
```

### Anti-patterns

```nushell
# BAD: Unhelpful error
export def "run" [config: path] {
    if not ($config | path exists) {
        error make { msg: "Error" }  # What error? How to fix?
    }
}

# BAD: Wastes user time
export def "status" [] {
    sleep 5sec  # Unnecessary delay
    print "OK"
}
```

---

## 9. Chaos Principle

**Principle:** Abandon standards when demonstrably harmful. Rules exist to serve users; when a rule hurts users, break it thoughtfully.

### Nushell Implementation

Prioritize user outcomes over rigid adherence to conventions.

```nushell
# Convention says --verbose, but for a monitoring tool
# showing less might be the sane default
export def "monitor" [
    --quiet (-q)  # Show only critical alerts (inverted logic)
] {
    # Default: show everything (opposite of typical CLI)
    # For monitoring, more info by default is safer
}

# Convention says confirm destructive actions
# But for undo-able operations, skip it
export def "git stash" [] {
    # No confirmation needed - easily reversible with 'git stash pop'
}
```

### When to Break Rules

- Safety trumps convenience (default to safe, opt-in to dangerous)
- Domain conventions override general CLI conventions
- User research shows the standard causes confusion
- The rule creates friction without adding value

---

## Summary: The Nushell Advantage

Nushell's design aligns naturally with good CLI philosophy:

| Principle | Nushell Feature |
|-----------|-----------------|
| Human-first | Structured tables, filesize/datetime formatting |
| Composability | Typed pipelines, not string parsing |
| Consistency | Built-in help from signatures |
| Discoverability | `help` command, tab completion |
| Robustness | Type system catches errors early |

Design for humans first. The machines will follow.
