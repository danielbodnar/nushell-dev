# Nushell Development Guides

Step-by-step tutorials and how-to guides for common development tasks.

## Available Guides

| Guide | Description |
|-------|-------------|
| [cli-design.md](./cli-design.md) | Designing professional CLI tools |
| [testing.md](./testing.md) | Testing strategies for Nushell code |
| [performance.md](./performance.md) | Optimizing Nushell scripts |
| [migration.md](./migration.md) | Migrating from bash/Python/jq |

---

## Quick Start Tutorials

### Create Your First Script

```nushell
#!/usr/bin/env nu

# hello.nu - A simple greeting script

def main [name: string = "World"] {
    print $"Hello, ($name)!"
}
```

Run with: `nu hello.nu` or `nu hello.nu "Alice"`

### Create a Reusable Module

```nushell
# utils.nu

export def greet [name: string] {
    $"Hello, ($name)!"
}

export def goodbye [name: string] {
    $"Goodbye, ($name)!"
}
```

Use in other scripts:
```nushell
use utils.nu
utils greet "World"
```

### Create a CLI Tool

```nushell
#!/usr/bin/env nu

# mytool.nu - A CLI tool example

def main [] {
    print "Usage: mytool <command>"
    print "Commands: list, add, remove"
}

def "main list" [] {
    # List items
}

def "main add" [item: string] {
    # Add item
}

def "main remove" [item: string] {
    # Remove item
}
```

---

## Common Workflows

### Data Processing Pipeline

```nushell
# Read → Transform → Filter → Output
open data.csv
| update amount { into float }
| where amount > 100
| select id name amount
| sort-by amount --reverse
| to json
| save output.json
```

### API Integration

```nushell
# Fetch → Process → Store
http get "https://api.example.com/data"
| get items
| each { |item| {
    id: $item.id
    name: $item.name
    processed_at: (date now)
}}
| to json
| save processed.json
```

### File Batch Processing

```nushell
# Find → Process → Report
ls **/*.json
| par-each { |f|
    let data = open $f.name
    {
        file: $f.name
        records: ($data | length)
        size: $f.size
    }
}
| sort-by records --reverse
| first 10
```

---

## Development Best Practices

1. **Type Everything** - Use type annotations for safety
2. **Handle Errors** - Use try/catch and error make
3. **Document Commands** - Add help text and examples
4. **Test Your Code** - Write tests for critical functions
5. **Use Pipelines** - Prefer pipeline operations over loops
6. **Keep It Simple** - Start simple, add complexity as needed

---

## Related Resources

- [Snippets](../snippets/) - Copy-paste code examples
- [Reference](../reference/) - Language reference
- [Plugin README](../../plugins/nushell-dev/README.md) - Plugin features
