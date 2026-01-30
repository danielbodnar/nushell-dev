# CLI Arguments and Flags Reference

> Based on [clig.dev](https://clig.dev) - Command Line Interface Guidelines

## Terminology

**Arguments (args):** Positional parameters passed to a command.
**Flags (options):** Named parameters prefixed with `-` or `--`.

```bash
# Arguments are positional
cp source.txt destination.txt

# Flags are named
grep --ignore-case --recursive "pattern" ./
```

---

## Prefer Flags to Arguments

Flags provide clearer semantics than positional arguments:

```bash
# Unclear: which is source, which is destination?
cp foo bar

# Clear: explicit naming
imagemagick --input foo.png --output bar.png
```

**When to use positional arguments:**
- Single, obvious input (like a filename)
- Commands modeled after well-known conventions (cp, mv)

**When to use flags:**
- Multiple inputs
- Optional parameters
- Configuration values
- Anything that benefits from explicit naming

---

## Full-Length Flag Versions

Always provide `--long-form` versions of flags:

```bash
# Both should work
command -v
command --verbose

# Self-documenting in scripts
command --recursive --ignore-case --output=results.json
```

**Why full-length flags matter:**
- Self-documenting in scripts and command history
- Easier to remember and discover
- Reduces ambiguity
- Accessible to users unfamiliar with short forms

---

## Single-Letter Flags for Common Options

Reserve single-letter flags for frequently used options:

| Short | Long          | Purpose                        |
|-------|---------------|--------------------------------|
| `-a`  | `--all`       | Include all items              |
| `-d`  | `--debug`     | Debug mode, verbose logging    |
| `-f`  | `--force`     | Skip confirmations             |
| `-h`  | `--help`      | Show help text                 |
| `-n`  | `--dry-run`   | Preview without changes        |
| `-o`  | `--output`    | Output file or destination     |
| `-q`  | `--quiet`     | Suppress non-error output      |
| `-v`  | `--verbose`   | More detailed output           |
| `-V`  | `--version`   | Show version information       |

**Additional common flags (long-form only):**

| Long           | Purpose                              |
|----------------|--------------------------------------|
| `--json`       | Output in JSON format                |
| `--no-input`   | Non-interactive mode                 |
| `--no-color`   | Disable colored output               |
| `--config`     | Specify configuration file           |
| `--yes`        | Auto-confirm prompts                 |

---

## Sensible Defaults

Commands should work with minimal configuration:

```bash
# Good: works out of the box
git status

# Good: sensible default behavior
ls        # current directory
cat       # reads from stdin if no file

# Bad: requires flags for basic operation
broken-tool --enable-basic-features --use-standard-format
```

**Default behavior guidelines:**
- Most common use case should require zero flags
- Safest option should be the default
- Destructive operations should NOT be default
- Output format should match typical usage context

---

## Prompting for Missing Input

When required input is missing, prompt interactively (if TTY):

```nushell
# Check if running interactively
def is-interactive [] -> bool {
    (term size | get columns) > 0
}

def my-command [
    name?: string  # Optional with prompting
] -> string {
    let actual_name = if ($name | is-empty) {
        if (is-interactive) {
            input "Enter name: "
        } else {
            error make { msg: "Name required in non-interactive mode" }
        }
    } else {
        $name
    }

    $actual_name
}
```

**TTY detection patterns:**
- Check if stdin/stdout is a terminal
- Provide `--no-input` flag for scripts
- Fall back to error in non-interactive mode
- Never block indefinitely waiting for input in pipes

---

## Confirming Dangerous Actions

Destructive operations should require confirmation:

```nushell
def delete-all [
    path: path
    --force (-f)     # Skip confirmation
    --dry-run (-n)   # Preview only
] {
    let files = (ls $path | where type == file)

    if $dry_run {
        print $"Would delete ($files | length) files"
        return
    }

    if not $force {
        let confirm = (input $"Delete ($files | length) files? [y/N] ")
        if ($confirm | str downcase) != "y" {
            print "Aborted."
            return
        }
    }

    $files | each { |f| rm $f.name }
    print $"Deleted ($files | length) files"
}
```

**Dangerous action guidelines:**
- Default to safe behavior (no action)
- Provide `--force` or `-f` to skip confirmation
- Provide `--dry-run` or `-n` to preview
- Show what will happen before confirming
- Make "no" or empty input the safe default

---

## Stdin/Stdout with "-" Convention

Use `-` to represent stdin/stdout:

```bash
# Read from stdin
cat - | process

# Write to stdout explicitly
generate --output -

# Pipe-friendly
curl url | convert - output.png
```

```nushell
def process-file [
    input: string = "-"   # Default to stdin
    --output (-o): string = "-"  # Default to stdout
] {
    let content = if $input == "-" {
        # Read from pipeline
        $in
    } else {
        open $input
    }

    let result = ($content | transform)

    if $output == "-" {
        $result
    } else {
        $result | save $output
    }
}
```

**Stdin/stdout conventions:**
- `-` means stdin for input, stdout for output
- Default to stdin when no file argument given
- Support piping by default
- Don't require file arguments for streaming operations

---

## NEVER Read Secrets from Flags

Command-line arguments are visible in process listings:

```bash
# DANGEROUS: password visible in `ps aux`
bad-tool --password=secret123

# SAFE: read from file
good-tool --password-file=/path/to/secret

# SAFE: read from environment
TOOL_PASSWORD=secret good-tool

# SAFE: read from stdin
echo "secret" | good-tool --password-stdin
```

```nushell
def secure-command [
    --password-file: path    # Read from file
    --password-stdin         # Read from stdin
] {
    let password = if $password_stdin {
        $in | str trim
    } else if ($password_file | is-not-empty) {
        open $password_file | str trim
    } else if ("MY_TOOL_PASSWORD" in $env) {
        $env.MY_TOOL_PASSWORD
    } else {
        error make { msg: "Password required via --password-file, --password-stdin, or MY_TOOL_PASSWORD env var" }
    }

    # Use password securely
}
```

**Secret handling:**
- Never accept secrets as command-line flags
- Support file-based secrets (`--password-file`)
- Support stdin secrets (`--password-stdin`)
- Support environment variables
- Document which methods are available

---

## Order Independence

Flags should work regardless of position:

```bash
# All of these should work identically
command --verbose --output=file input.txt
command input.txt --verbose --output=file
command --output=file input.txt --verbose
```

**Order independence rules:**
- Flags can appear before, after, or between arguments
- Use `--` to separate flags from arguments if needed
- Last value wins for repeated flags (or collect into list)

---

## Nushell Implementation Patterns

### Basic Command Structure

```nushell
# Complete command example with all patterns
def my-command [
    file: path                    # Required positional argument
    ...rest: path                 # Collect remaining args
    --all (-a)                    # Boolean flag with short form
    --output (-o): path           # Flag with value and short form
    --force (-f)                  # Dangerous action bypass
    --dry-run (-n)                # Preview mode
    --json                        # Machine-readable output
    --verbose (-v)                # Increase output detail
    --quiet (-q)                  # Decrease output detail
    --config: path                # Configuration file
] -> any {
    # Validate conflicting flags
    if $verbose and $quiet {
        error make { msg: "Cannot use --verbose and --quiet together" }
    }

    # Implementation
}
```

### Flag with Default Value

```nushell
def process [
    --format: string = "table"    # Default to table format
    --limit: int = 100            # Default limit
    --output: path                # Optional, no default
] {
    # $format is "table" if not specified
    # $limit is 100 if not specified
    # $output is null if not specified
}
```

### Boolean vs Value Flags

```nushell
def example [
    --verbose (-v)          # Boolean: true if present, false if absent
    --level: int            # Value: requires argument
    --output (-o): path     # Value with short form
] {
    if $verbose { print "Verbose mode" }
    if ($level | is-not-empty) { print $"Level: ($level)" }
}
```

### Rest Parameters

```nushell
# Collect multiple positional arguments
def concat [...files: path] -> string {
    $files | each { |f| open $f } | str join "\n"
}

# Usage: concat file1.txt file2.txt file3.txt
```

### Optional Arguments with Prompting

```nushell
def greet [
    name?: string    # Optional positional
] {
    let actual_name = $name | default (input "What is your name? ")
    print $"Hello, ($actual_name)!"
}
```

### Mutually Exclusive Flags

```nushell
def output-format [
    --json
    --yaml
    --toml
    --table
] {
    let formats = [$json $yaml $toml $table] | where { $in }

    if ($formats | length) > 1 {
        error make { msg: "Only one output format allowed" }
    }

    # Determine format
    let format = if $json { "json" }
        else if $yaml { "yaml" }
        else if $toml { "toml" }
        else { "table" }  # default

    $format
}
```

---

## Common Mistakes

### Mistake: Too Many Required Arguments

```nushell
# Bad: unclear what each argument means
def bad-copy [src dst mode owner group] { }

# Good: use flags for clarity
def good-copy [
    source: path
    destination: path
    --mode: string
    --owner: string
    --group: string
] { }
```

### Mistake: Inconsistent Flag Naming

```nushell
# Bad: inconsistent conventions
def bad-tool [
    --outputFile   # camelCase
    --input_dir    # snake_case
    --DryRun       # PascalCase
] { }

# Good: consistent kebab-case
def good-tool [
    --output-file
    --input-dir
    --dry-run
] { }
```

### Mistake: Hidden Required Flags

```nushell
# Bad: flag is actually required
def bad-api [
    --api-key: string   # Required but looks optional
] {
    if ($api_key | is-empty) {
        error make { msg: "API key required" }
    }
}

# Good: make it a positional or document clearly
def good-api [
    api_key: string     # Required positional
] { }

# Or with environment fallback
def good-api-alt [
    --api-key: string   # Optional, falls back to env
] {
    let key = $api_key | default ($env.API_KEY? | default "")
    if ($key | is-empty) {
        error make { msg: "API key required via --api-key or API_KEY env" }
    }
}
```

---

## Summary

1. **Prefer flags** over positional arguments for clarity
2. **Provide both** short (-v) and long (--verbose) forms
3. **Use standard names** for common flags
4. **Set sensible defaults** - most common case needs zero flags
5. **Prompt interactively** when input is missing (with TTY check)
6. **Confirm dangerous actions** with --force override
7. **Support stdin/stdout** with "-" convention
8. **Never accept secrets** as command-line arguments
9. **Ensure order independence** for flags
10. **Be consistent** with naming conventions
