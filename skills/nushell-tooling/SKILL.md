---
name: nushell-tooling
description: This skill should be used when the user asks to "lint Nushell code", "use nu-lint", "set up Nushell LSP", "configure nu --lsp", "use nu --mcp", "test Nushell scripts", "generate documentation", "format Nushell code", "debug Nushell", or mentions LSP, MCP server, linting, testing, debugging, or IDE integration for Nushell.
version: 1.0.0
---

# Nushell Tooling & Developer Experience

Guide for Nushell development tooling including LSP, MCP server, linting, testing, and documentation generation. Covers IDE integration, debugging, and workflow automation.

## Language Server Protocol (LSP)

### Starting the LSP

```nushell
# Start LSP server
nu --lsp

# The LSP provides:
# - Code completion
# - Hover information
# - Go to definition
# - Diagnostics (errors/warnings)
# - Document symbols
```

### IDE Configuration

#### VS Code

Install "Nushell" extension, then configure:

```json
// settings.json
{
    "nushell.server.path": "nu",
    "nushell.server.args": ["--lsp"],
    "nushell.config.path": "~/.config/nushell/config.nu",
    "nushell.env.path": "~/.config/nushell/env.nu"
}
```

#### Neovim (nvim-lspconfig)

```lua
-- init.lua
require('lspconfig').nushell.setup{
    cmd = { "nu", "--lsp" },
    filetypes = { "nu" },
    settings = {}
}
```

#### Helix

```toml
# languages.toml
[[language]]
name = "nu"
language-servers = ["nu"]

[language-server.nu]
command = "nu"
args = ["--lsp"]
```

#### Zed

```json
// settings.json
{
    "languages": {
        "Nushell": {
            "language_servers": ["nu-lsp"]
        }
    },
    "lsp": {
        "nu-lsp": {
            "binary": { "path": "nu", "arguments": ["--lsp"] }
        }
    }
}
```

### LSP Features

| Feature | Description |
|---------|-------------|
| Completion | Command names, flags, variables |
| Hover | Type info, documentation |
| Diagnostics | Syntax errors, type mismatches |
| Go to Definition | Jump to command/variable definition |
| Document Symbols | Outline of definitions in file |
| Signature Help | Parameter hints while typing |

## MCP Server (Model Context Protocol)

### Starting MCP Server

```nushell
# Start MCP server for Claude Code integration
nu --mcp

# Available tools:
# - list_commands: List all Nushell commands
# - command_help: Get detailed help for a command
# - evaluate: Execute Nushell code and return results
```

### MCP Configuration

For Claude Code, add to settings:

```json
{
    "mcpServers": {
        "nushell": {
            "command": "nu",
            "args": ["--mcp"]
        }
    }
}
```

### Using MCP Tools

The MCP server provides structured access to Nushell:

```nushell
# Through MCP tools:

# list_commands - discover available commands
# Returns structured list of all commands with signatures

# command_help [command_name] - get detailed help
# Returns documentation, examples, flags

# evaluate [code] - run Nushell code
# Returns structured output (tables, records, etc.)
```

## Linting

### nu-lint

```bash
# Install nu-lint (separate tool)
cargo install nu-lint

# Run linter
nu-lint check script.nu
nu-lint check --recursive ./src/
```

### Built-in Checks

```nushell
# Syntax validation
nu --commands "source script.nu"

# Parse without execution
nu-check script.nu
nu-check --as-module module.nu

# Check specific constructs
nu-check --debug script.nu  # Verbose output
```

### Common Lint Rules

| Rule | Description | Fix |
|------|-------------|-----|
| Unused variable | Variable defined but not used | Remove or use with `_` prefix |
| Shadow variable | Variable redefined in same scope | Use different name |
| Type mismatch | Incompatible types in operation | Add type conversion |
| Missing parameter | Required parameter not provided | Add parameter or default |
| Deprecated command | Using old command name | Use new command name |

### Custom Lint Script

```nushell
# lint.nu - Custom linting wrapper
def lint [path: path, --fix] {
    let files = if ($path | path type) == "dir" {
        glob $"($path)/**/*.nu"
    } else {
        [$path]
    }

    let results = $files | each { |file|
        let check = do { nu-check $file } | complete
        {
            file: $file
            ok: ($check.exit_code == 0)
            errors: ($check.stderr | lines)
        }
    }

    let errors = $results | where not ok

    if ($errors | is-empty) {
        print "✅ All files passed"
    } else {
        $errors | each { |r|
            print $"❌ ($r.file)"
            $r.errors | each { |e| print $"   ($e)" }
        }
        error make { msg: $"($errors | length) files with errors" }
    }
}
```

## Testing

### Test Framework Pattern

```nushell
# tests/test_utils.nu
use ../src/utils.nu

# Test definitions
def "test add" [] {
    let result = utils add 2 3
    assert-eq 5 $result "add should return sum"
}

def "test subtract" [] {
    let result = utils subtract 5 3
    assert-eq 2 $result "subtract should return difference"
}

# Test runner
def "test all" [] {
    let tests = (scope commands | where name =~ "^test " | get name)

    let results = $tests | each { |test_name|
        try {
            do (scope commands | where name == $test_name | get 0.closure).0
            {name: $test_name, passed: true, error: null}
        } catch { |err|
            {name: $test_name, passed: false, error: $err.msg}
        }
    }

    let passed = $results | where passed | length
    let failed = $results | where not passed

    print $"Passed: ($passed)/($results | length)"

    if ($failed | is-not-empty) {
        print "\nFailures:"
        $failed | each { |f|
            print $"  ❌ ($f.name): ($f.error)"
        }
        exit 1
    }
}
```

### Assertion Helpers

```nushell
# assertions.nu

# Assert equality
def assert-eq [expected: any, actual: any, message?: string] {
    if $expected != $actual {
        error make {
            msg: ($message | default $"Expected ($expected), got ($actual)")
        }
    }
}

# Assert truthy
def assert [condition: bool, message?: string] {
    if not $condition {
        error make { msg: ($message | default "Assertion failed") }
    }
}

# Assert contains
def assert-contains [haystack: any, needle: any, message?: string] {
    let contains = match ($haystack | describe) {
        "string" => { $haystack | str contains $needle }
        "list" => { $needle in $haystack }
        _ => false
    }
    if not $contains {
        error make {
            msg: ($message | default $"Expected ($haystack) to contain ($needle)")
        }
    }
}

# Assert throws
def assert-throws [closure: closure, message?: string] {
    try {
        do $closure
        error make { msg: ($message | default "Expected exception, but none thrown") }
    } catch {
        # Expected behavior
    }
}
```

### Running Tests

```nushell
# Run all tests
nu tests/test_all.nu

# Run specific test file
nu tests/test_utils.nu

# With verbose output
nu --commands "use tests/test_utils.nu; test all"
```

## Documentation Generation

### Built-in Documentation

```nushell
# Generate help for custom commands
def documented-command [
    arg1: string  # First argument description
    --flag: int   # Flag description
] {
    # Implementation
}

# Access documentation
help documented-command
```

### DocGen Script

```nushell
# docgen.nu - Generate markdown documentation from .nu files

def generate-docs [source_dir: path, output_dir: path] {
    mkdir $output_dir

    glob $"($source_dir)/**/*.nu" | each { |file|
        let commands = extract-commands $file
        let doc = format-markdown $file $commands
        let output = [
            $output_dir,
            ($file | path basename | str replace ".nu" ".md")
        ] | path join
        $doc | save --force $output
    }
}

def extract-commands [file: path] {
    # Parse file and extract exported commands
    open $file
    | lines
    | window 2
    | where { |w| $w.1 | str starts-with "export def" }
    | each { |w|
        {
            comment: $w.0
            signature: $w.1
        }
    }
}

def format-markdown [file: path, commands: list] {
    let header = $"# ($file | path basename)\n\n"
    let body = $commands | each { |cmd|
        $"## `($cmd.signature | str replace 'export def ' '' | str trim)`\n\n($cmd.comment | str replace '# ' '')\n"
    } | str join "\n"
    $header + $body
}
```

## Debugging

### Print Debugging

```nushell
# Debug helper
def dbg [label: string, value: any] {
    print -e $"[DEBUG] ($label): ($value | to nuon)"
    $value  # Pass through
}

# Usage in pipeline
$data
| dbg "after load" $in
| transform
| dbg "after transform" $in
```

### Describe Types

```nushell
# Inspect type
$value | describe

# Detailed type info
$value | describe --detailed

# Check structure
$data | columns
$data | schema
```

### Error Investigation

```nushell
# Capture errors
try {
    risky-operation
} catch { |err|
    print $"Error type: ($err | describe)"
    print $"Message: ($err.msg)"
    print $"Debug: ($err | to nuon)"
}
```

### REPL Exploration

```nushell
# Interactive exploration
let data = open complex.json

# Check structure
$data | describe
$data | columns
$data | get some_field | first 5

# Test transformations incrementally
$data | step1
$data | step1 | step2
```

## Help System Integration

### Using Built-in Help

```nushell
# Command categories
help commands      # All commands
help modules       # Available modules
help operators     # Operator reference
help escapes       # Escape sequences
help pipe-and-redirect  # Pipeline syntax

# Specific help
help str           # String commands
help str join      # Specific subcommand
help http get      # HTTP commands
```

### Creating Discoverable Commands

```nushell
# Well-documented command
# Processes input data according to specified format
#
# The format parameter determines output structure.
# Supported formats: json, csv, table
#
# Examples:
#   process-data input.json --format csv
#   open data.csv | process-data --format table
export def process-data [
    input?: path      # Input file path (or pipe data)
    --format: string  # Output format: json, csv, table
    --verbose (-v)    # Enable verbose logging
] {
    # Implementation with rich help
}
```

## Workflow Automation

### Pre-commit Hook

```nushell
# .git/hooks/pre-commit (make executable)
#!/usr/bin/env nu

# Lint all changed .nu files
let files = ^git diff --cached --name-only --diff-filter=d
| lines
| where ($it | str ends-with ".nu")

if ($files | is-not-empty) {
    $files | each { |f|
        print $"Checking: ($f)"
        let result = do { nu-check $f } | complete
        if $result.exit_code != 0 {
            print $"Error in ($f):"
            print $result.stderr
            exit 1
        }
    }
}

print "✅ All Nushell files pass"
```

### CI/CD Integration

```yaml
# .github/workflows/nushell.yml
name: Nushell CI

on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Nushell
        run: |
          curl -sL https://github.com/nushell/nushell/releases/latest/download/nu-*-x86_64-unknown-linux-gnu.tar.gz | tar xz
          sudo mv nu-*/nu /usr/local/bin/
      - name: Lint
        run: |
          nu -c "glob **/*.nu | each { |f| nu-check $f }"

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Nushell
        run: |
          curl -sL https://github.com/nushell/nushell/releases/latest/download/nu-*-x86_64-unknown-linux-gnu.tar.gz | tar xz
          sudo mv nu-*/nu /usr/local/bin/
      - name: Test
        run: nu tests/run_all.nu
```

## Additional Resources

### Reference Files

For detailed configurations:
- **`references/ide-configs.md`** - Complete IDE setup guides
- **`references/ci-templates.md`** - CI/CD configuration templates

### Example Files

Working examples in `examples/`:
- **`test-framework.nu`** - Complete test framework
- **`docgen.nu`** - Documentation generator
- **`lint-wrapper.nu`** - Enhanced linting script

### Scripts

Utility scripts in `scripts/`:
- **`setup-hooks.nu`** - Install git hooks
- **`run-tests.nu`** - Test runner
