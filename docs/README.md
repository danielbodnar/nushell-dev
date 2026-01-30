# Nushell Development Documentation

> Comprehensive documentation for the nushell-dev Claude Code plugin
> Nushell version: 0.110.0+

## Quick Links

| Resource | Description |
|----------|-------------|
| [**Snippets**](./snippets/) | Copy-paste code examples by category |
| [**Reference**](./reference/) | Complete language and API reference |
| [**Guides**](./guides/) | Step-by-step tutorials and how-tos |

---

## Getting Started

### Prerequisites

```nushell
# Check Nushell version (requires 0.100+)
version | get version

# Verify LSP availability
which nu | get 0.path
nu --ide-check --help
```

### Plugin Installation

```bash
# Install from nushell-marketplace
/plugin marketplace add danielbodnar/nushell-dev
/plugin install nushell-dev@nushell-marketplace

# Or test in isolation
claude --plugin-dir ~/.claude/plugins/nushell-dev/plugins/nushell-dev
```

### Recommended Nushell Plugins

```nushell
# High-performance data processing
plugin add polars

# Additional file formats
plugin add formats

# SQL-like queries
plugin add query
```

---

## Documentation Structure

```
docs/
├── README.md              # This file
├── snippets/              # Code snippets
│   ├── README.md          # Snippet index
│   ├── pipelines.md       # Pipeline patterns
│   ├── data.md            # Data transformation
│   ├── http.md            # HTTP & API calls
│   ├── files.md           # File operations
│   ├── commands.md        # Custom commands
│   └── modules.md         # Module patterns
├── reference/             # Reference documentation
│   ├── README.md          # Reference index
│   ├── types.md           # Type system
│   ├── operators.md       # Operators reference
│   ├── configuration.md   # $env.config reference
│   ├── commands.md        # Built-in commands
│   └── errors.md          # Error handling
└── guides/                # How-to guides
    ├── README.md          # Guide index
    ├── cli-design.md      # CLI design patterns
    ├── testing.md         # Testing strategies
    ├── performance.md     # Performance optimization
    └── migration.md       # Migrating from bash/Python
```

---

## Core Concepts

### Everything is Data

Nushell treats command output as structured data, not text:

```nushell
# Commands return tables, not strings
ls | where size > 1mb | sort-by modified

# JSON is automatically parsed
http get https://api.example.com/data | get items | first 5

# Types are preserved through pipelines
date now | $in - 1day | format date "%Y-%m-%d"
```

### Pipelines are Typed

Data flows through pipelines with known shapes:

```nushell
# Input: nothing → Output: table<name, size, modified>
ls

# Input: table → Output: table (filtered)
where size > 1mb

# Input: any → Output: transformed any
each { |it| $it.name | str upcase }
```

### Commands Have Signatures

Every command declares its interface:

```nushell
# View command signature
help str join

# Signatures enforce types at runtime
def greet [name: string, --excited] -> string {
    if $excited {
        $"Hello, ($name)!"
    } else {
        $"Hello, ($name)."
    }
}
```

---

## Plugin Features

### Skills (Auto-activating)

Skills automatically activate based on context:

| Skill | Triggers |
|-------|----------|
| `nushell-fundamentals` | pipelines, closures, modules, types |
| `nushell-data-processing` | polars, dataframes, large datasets |
| `nushell-http-api` | http commands, REST APIs, webhooks |
| `nushell-storage` | stor, SQLite, parquet, file formats |
| `nushell-cloudflare` | workers, R2, wrangler |
| `nushell-tooling` | LSP, linting, testing |
| `cli-guidelines` | CLI design, argument parsing |

### Commands (User-initiated)

| Command | Description |
|---------|-------------|
| `/nushell-dev:new` | Scaffold scripts, modules, commands |
| `/nushell-dev:lint` | Lint and auto-fix Nushell code |
| `/nushell-dev:docs` | Generate documentation |
| `/nushell-dev:test` | Create or run tests |
| `/nushell-dev:convert` | Convert from bash/Python/jq |
| `/nushell-dev:cli-scaffold` | Create CLI-compliant scripts |
| `/nushell-dev:cli-check` | Audit against CLI guidelines |

### Agents (Autonomous)

| Agent | Purpose |
|-------|---------|
| `nushell-generator` | Generate complete scripts from descriptions |
| `nushell-code-reviewer` | Review for best practices |
| `nushell-refactorer` | Modernize and optimize code |

### Hooks (Automatic)

- **PreToolUse**: Validates syntax before writing `.nu` files
- **PostToolUse**: Auto-formats after successful writes

---

## Common Tasks

### Create a New Script

```
/nushell-dev:new script --name my-script --description "Process log files"
```

### Convert Bash to Nushell

```
/nushell-dev:convert ./legacy.sh
```

### Generate Documentation

```
/nushell-dev:docs ./src
```

### Lint Your Code

```
/nushell-dev:lint ./my-module.nu
```

---

## Best Practices

### 1. Type Everything

```nushell
# Good: Explicit types
def process [input: path, --format: string = "json"] -> table {
    open $input | from json
}

# Avoid: Untyped parameters
def process [input, format] {
    open $input
}
```

### 2. Handle Errors Gracefully

```nushell
# Good: Try/catch with meaningful errors
def safe-read [path: path] -> any {
    try {
        open $path
    } catch {
        error make { msg: $"Failed to read ($path)" }
    }
}

# Good: Optional access with fallback
$record.maybe_field? | default "fallback"
```

### 3. Use Structured Data

```nushell
# Good: Return structured data
def analyze [file: path] -> record {
    let content = open $file
    {
        lines: ($content | lines | length)
        words: ($content | split words | length)
        bytes: ($content | str length)
    }
}

# Avoid: Return formatted strings
def analyze [file: path] {
    print $"Lines: ..."
}
```

### 4. Prefer Pipeline Over Loops

```nushell
# Good: Pipeline operations
ls **/*.nu | where size > 1kb | each { |f| open $f.name | lines | length }

# Avoid: Manual iteration
mut results = []
for f in (ls **/*.nu) {
    if $f.size > 1kb {
        $results = $results ++ [(open $f.name | lines | length)]
    }
}
```

### 5. Document Commands

```nushell
# Fetch user data from the API
#
# Returns user record with profile information.
#
# Examples:
#   fetch-user 123
#   fetch-user 123 --include-posts
def fetch-user [
    id: int              # User ID to fetch
    --include-posts      # Include user's posts in response
] -> record {
    # Implementation
}
```

---

## Resources

### Official Documentation

- [Nushell Book](https://www.nushell.sh/book/)
- [Command Reference](https://www.nushell.sh/commands/)
- [Cookbook](https://www.nushell.sh/cookbook/)

### Community

- [GitHub](https://github.com/nushell/nushell)
- [Discord](https://discord.gg/NtAbbGn)
- [nu_scripts](https://github.com/nushell/nu_scripts)

### Related Tools

- [nupm](https://github.com/nushell/nupm) - Package manager
- [Polars](https://pola.rs/) - DataFrame library
- [Carapace](https://carapace.sh/) - Multi-shell completions

---

## Version History

| Version | Nushell | Changes |
|---------|---------|---------|
| 1.0.0 | 0.100+ | Initial release |
| 1.1.0 | 0.107+ | CLI guidelines, hooks |
| 1.2.0 | 0.110+ | Configuration reference |
