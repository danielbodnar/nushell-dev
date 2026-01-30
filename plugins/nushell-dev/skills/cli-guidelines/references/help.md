# CLI Help Systems in Nushell

> Comprehensive guide to implementing help, documentation, and user guidance

---

## Core Help Conventions

Every CLI must support multiple ways to get help:

| Invocation | Expected Behavior |
|------------|-------------------|
| `myapp` | Brief usage when no args required; otherwise run |
| `myapp --help` | Detailed help with all options |
| `myapp -h` | Same as --help (short form) |
| `myapp help` | Same as --help (subcommand form) |
| `myapp help <cmd>` | Help for specific subcommand |

---

## 1. Display Help on -h and --help

### Nushell Auto-Generated Help

Nushell generates help automatically from documentation comments and signatures.

```nushell
# Synchronize local files with remote storage
#
# This command uploads changed files to your configured remote
# storage backend, handling conflicts and preserving metadata.
#
# Examples:
#   sync upload .                    # Sync current directory
#   sync upload ./src --dry-run      # Preview what would sync
#   sync upload . --exclude "*.tmp"  # Exclude temp files
export def "sync upload" [
    path: path = "."           # Directory to synchronize
    --dry-run (-n)             # Show changes without applying
    --force (-f)               # Overwrite remote conflicts
    --exclude (-e): string     # Glob pattern to exclude
    --verbose (-v)             # Show detailed progress
] {
    # Implementation
}

# Users get help automatically:
# > help sync upload
# > sync upload --help
# > sync upload -h
```

### Anatomy of Good Documentation Comments

```nushell
# One-line description (shows in command listings)
#
# Extended description with more detail. Can span
# multiple lines and explain the command's purpose,
# behavior, and important caveats.
#
# Examples:
#   command simple-case           # Basic usage
#   command complex --flag value  # With options
#   input | command               # Piped usage
export def "command" [
    required: string       # Description of required param
    optional?: int         # Description of optional param
    --flag (-f): string    # Description of flag with value
    --switch (-s)          # Description of boolean switch
] {
    # Implementation
}
```

---

## 2. Concise Help When Run Without Args

When a command requires arguments, show brief usage guidance.

```nushell
export def "deploy" [
    environment?: string  # Target environment
    --help (-h)
] {
    if $help {
        show-deploy-help
        return
    }

    if ($environment | is-empty) {
        # Brief usage, not full help
        print "Usage: deploy <environment> [options]"
        print ""
        print "Environments: dev, staging, prod"
        print ""
        print "Run 'deploy --help' for detailed information"
        return
    }

    perform-deployment $environment
}
```

---

## 3. Support All Help Access Patterns

```nushell
export def main [
    command?: string
    ...args: string
    --help (-h)
    --version (-V)
] {
    # Pattern: myapp --help
    if $help {
        show-help
        return
    }

    # Pattern: myapp (no args)
    if ($command | is-empty) {
        show-help
        return
    }

    # Pattern: myapp help <command>
    if $command == "help" {
        if ($args | is-empty) {
            show-help
        } else {
            show-command-help ($args | first)
        }
        return
    }

    # Dispatch to subcommand
    run-subcommand $command $args
}
```

---

## 4. Include Support URLs

Always tell users where to get more help.

```nushell
def show-help [] {
    print $"
(ansi cyan_bold)myapp(ansi reset) - Modern application toolkit

(ansi yellow)USAGE:(ansi reset)
    myapp <command> [options]

(ansi yellow)COMMANDS:(ansi reset)
    init       Create a new project
    build      Compile the application
    test       Run the test suite
    deploy     Deploy to environment

(ansi yellow)OPTIONS:(ansi reset)
    -h, --help      Show this help
    -V, --version   Show version

(ansi dim)Documentation: https://docs.example.com
GitHub:        https://github.com/example/myapp
Report bugs:   https://github.com/example/myapp/issues(ansi reset)
"
}
```

---

## 5. Lead with Examples

Examples teach faster than reference documentation.

```nushell
export def "api" [--help (-h)] {
    print $"(ansi cyan_bold)api(ansi reset) - Interact with the REST API"
    print ""

    # Examples FIRST, before formal documentation
    print $"(ansi yellow)EXAMPLES:(ansi reset)"
    print ""
    print $"  (ansi dim)# List all users(ansi reset)"
    print "  api get /users"
    print ""
    print $"  (ansi dim)# Create a new post(ansi reset)"
    print '  api post /posts --data {title: "Hello"}'
    print ""
    print $"  (ansi dim)# Update with authentication(ansi reset)"
    print "  api put /users/123 --auth token.txt"
    print ""

    # Then commands and options
    print $"(ansi yellow)COMMANDS:(ansi reset)"
    print "  get, post, put, delete"
    print ""
    print "Run 'help api <method>' for full options"
}
```

### Examples in Nushell Comments

```nushell
# Convert data between formats
#
# Examples:
#   convert data.json --to yaml           # JSON to YAML
#   convert data.csv --to json --pretty   # CSV to pretty JSON
#   open data.xml | convert --to toml     # Piped input
#   convert input.json -o output.yaml     # Write to file
export def "convert" [
    input?: path                    # Input file (or use stdin)
    --to (-t): string               # Output format: json, yaml, toml
    --pretty (-p)                   # Pretty-print output
    --output (-o): path             # Write to file instead of stdout
] { }
```

---

## 6. Prioritize Common Flags First

Order options by frequency of use, not alphabetically.

```nushell
def show-options [] {
    print $"(ansi yellow)OPTIONS:(ansi reset)"
    # Most common first
    print "    -o, --output     Output file path"
    print "    -f, --format     Output format (json, yaml, table)"
    print "    -v, --verbose    Show detailed output"
    print "    -q, --quiet      Suppress non-error output"
    print ""
    # Less common
    print "    --config         Path to config file"
    print "    --no-color       Disable colored output"
    print "    --timeout        Request timeout in seconds"
    print ""
    # Rarely needed
    print "    --debug          Enable debug logging"
    print "    --trace          Enable trace logging"
}
```

---

## 7. Use Formatting for Readability

Apply consistent visual hierarchy with ANSI colors.

```nushell
def show-styled-help [] {
    # Title
    print $"(ansi cyan_bold)MYAPP(ansi reset) (ansi dim)v1.2.3(ansi reset)"
    print ""

    # Section headers in yellow
    print $"(ansi yellow)DESCRIPTION(ansi reset)"
    print "    A powerful tool for managing workflows."
    print ""

    # Commands with green highlighting
    print $"(ansi yellow)COMMANDS(ansi reset)"
    print $"    (ansi green)init(ansi reset)      Initialize a new project"
    print $"    (ansi green)build(ansi reset)     Compile the project"
    print $"    (ansi green)test(ansi reset)      Run the test suite"
    print ""

    # Options aligned
    print $"(ansi yellow)OPTIONS(ansi reset)"
    print "    -v, --verbose    Enable verbose output"
    print "    -q, --quiet      Suppress all output"
    print "    -c, --config     Path to config file"
    print ""

    # Secondary info dimmed
    print $"(ansi dim)https://example.com/docs(ansi reset)"
}
```

---

## 8. Suggest Corrections for Typos

Help users recover from mistakes.

```nushell
const COMMANDS = ["init", "build", "test", "deploy", "status"]

export def main [command?: string] {
    if ($command | is-empty) {
        show-help
        return
    }

    if $command not-in $COMMANDS {
        suggest-correction $command
        return
    }

    run-command $command
}

def suggest-correction [input: string] {
    let similar = $COMMANDS | where {|cmd|
        ($cmd | str starts-with ($input | str substring 0..2)) or
        (levenshtein $input $cmd) <= 2
    }

    print $"(ansi red)Error:(ansi reset) Unknown command '($input)'"
    print ""

    if ($similar | length) > 0 {
        print "Did you mean?"
        $similar | each {|s| print $"    (ansi cyan)($s)(ansi reset)" }
        print ""
    }

    print "Run 'myapp --help' for available commands"
}

def levenshtein [a: string, b: string] -> int {
    # Simplified edit distance
    let a_chars = ($a | split chars)
    let b_chars = ($b | split chars)
    let common = ($a_chars | where {|c| $c in $b_chars} | length)
    (($a | str length) + ($b | str length) - (2 * $common))
}
```

---

## 9. Pipe-Friendliness

Never hang waiting for stdin when run interactively.

```nushell
export def "process" [
    input?: string       # Input data (or use stdin)
    --interactive (-i)   # Force interactive mode
] {
    # Check for piped input
    let piped = $in
    let has_pipe = ($piped | is-not-empty)

    let data = if $has_pipe {
        $piped
    } else if ($input | is-not-empty) {
        $input
    } else if $interactive {
        input "Enter data: "
    } else {
        # Don't hang! Show usage instead
        print "Usage: process <input> or pipe data"
        print ""
        print "Examples:"
        print "  process 'data'"
        print "  echo data | process"
        print "  process --interactive"
        return
    }

    process-data $data
}
```

### Output Mode Detection

```nushell
export def "list items" [
    --json       # Force JSON output
    --table      # Force table output
] {
    let items = (get-items)

    if $json {
        $items | to json
    } else if $table {
        $items | table
    } else {
        # Default: structured for terminal, JSON for pipes
        # (Nushell handles this automatically in most cases)
        $items
    }
}
```

---

## Complete Example: Full Help System

```nushell
#!/usr/bin/env nu

# MyApp - Modern application toolkit
#
# A comprehensive example of CLI help best practices.
#
# Examples:
#   myapp init my-project          Create new project
#   myapp build --release          Build for production
#   myapp test --coverage          Run tests with coverage
export def main [
    command?: string
    ...args: string
    --help (-h)
    --version (-V)
    --docs
] {
    if $version {
        print "myapp v2.0.0"
        return
    }

    if $docs {
        ^xdg-open "https://docs.example.com"
        return
    }

    if $help or ($command | is-empty) {
        show-main-help
        return
    }

    let known = ["init", "build", "test", "deploy"]

    if $command == "help" {
        if ($args | is-empty) {
            show-main-help
        } else {
            print $"Help for: ($args | first)"
            # Delegate to: help myapp-($args | first)
        }
        return
    }

    if $command not-in $known {
        print $"(ansi red)Error:(ansi reset) Unknown command '($command)'"
        let similar = ($known | where { str starts-with ($command | str substring 0..1) })
        if ($similar | length) > 0 {
            print $"\nDid you mean: (ansi cyan)($similar | first)(ansi reset)?"
        }
        print "\nRun 'myapp --help' for available commands"
        exit 1
    }
}

def show-main-help [] {
    print $"
(ansi cyan_bold)myapp(ansi reset) (ansi dim)v2.0.0(ansi reset) - Modern application toolkit

(ansi yellow)EXAMPLES:(ansi reset)
    myapp init my-project       Create new project
    myapp build --release       Build for production
    myapp test --watch          Run tests in watch mode

(ansi yellow)COMMANDS:(ansi reset)
    (ansi green)init(ansi reset)       Create a new project
    (ansi green)build(ansi reset)      Compile the application
    (ansi green)test(ansi reset)       Run the test suite
    (ansi green)deploy(ansi reset)     Deploy to environment

(ansi yellow)OPTIONS:(ansi reset)
    -h, --help      Show this help
    -V, --version   Show version
    --docs          Open docs in browser

(ansi dim)Docs:   https://docs.example.com
Bugs:   https://github.com/example/myapp/issues
Source: https://github.com/example/myapp(ansi reset)
"
}
```

---

## Summary

| Guideline | Implementation |
|-----------|----------------|
| -h/--help | Use Nushell doc comments |
| Concise default | Show usage when args missing |
| Multiple patterns | Support cmd, cmd --help, help cmd |
| Support URLs | Include docs/issues links |
| Examples first | Lead help with examples |
| Common first | Order flags by frequency |
| Formatting | Use ANSI colors consistently |
| Typo correction | Suggest similar commands |
| Pipe-friendly | Don't hang; detect stdin |

Good help transforms confusion into confidence.
