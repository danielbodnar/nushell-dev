# Nushell Code Snippets

Copy-paste ready code examples organized by category. All snippets are tested with Nushell 0.110+.

## Categories

| File | Description |
|------|-------------|
| [pipelines.md](./pipelines.md) | Pipeline patterns, data flow, transformations |
| [data.md](./data.md) | Data structures, manipulation, aggregation |
| [http.md](./http.md) | HTTP requests, APIs, authentication |
| [files.md](./files.md) | File operations, formats, streaming |
| [commands.md](./commands.md) | Custom commands, flags, documentation |
| [modules.md](./modules.md) | Modules, exports, overlays |

---

## Quick Reference

### One-Liners

```nushell
# Find large files
ls **/* | where type == file and size > 100mb | sort-by size --reverse

# Count lines in all .nu files
ls **/*.nu | each { |f| open $f.name | lines | length } | math sum

# Get unique values from column
open data.csv | get status | uniq

# Flatten nested JSON
open nested.json | flatten --all

# Group and count
open events.json | group-by type | transpose type events | each { |r| {type: $r.type, count: ($r.events | length)} }

# Parse dates and filter
open logs.json | where { |r| ($r.timestamp | into datetime) > ((date now) - 1day) }

# Extract field from all records
open users.json | get name | str join ", "

# Convert CSV columns to numbers
open data.csv | update amount { |r| $r.amount | into int }

# Merge multiple JSON files
ls *.json | each { |f| open $f.name } | flatten

# Calculate percentages
$data | each { |r| $r | insert pct ($r.value / ($data | get value | math sum) * 100) }
```

### Common Operations

```nushell
# Safe file read with fallback
open config.toml | default { setting: "default" }

# Null-safe field access
$record.maybe_field? | default "fallback"

# Conditional transformation
$data | if ($in | is-empty) { [] } else { $in | process }

# Error handling
try { risky_operation } catch { |e| print $"Error: ($e.msg)" }

# Environment variable with default
$env.MY_VAR? | default "default_value"

# Check if command exists
which rg | is-not-empty
```

---

## Usage Tips

1. **Copy entire blocks** - Snippets are self-contained
2. **Modify placeholders** - Replace `$data`, `file.json`, etc.
3. **Chain snippets** - Combine patterns with pipes
4. **Check types** - Use `describe` to inspect data shapes
