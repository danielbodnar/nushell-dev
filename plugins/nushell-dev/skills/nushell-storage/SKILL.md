---
name: nushell-storage
description: This skill should be used when the user asks to "store data in Nushell", "use stor command", "query SQLite", "work with parquet files", "save to database", "read CSV files", "convert JSON to parquet", "persist data between sessions", or mentions stor, SQLite, parquet, CSV, JSON, file formats, or data persistence in Nushell.
version: 1.0.0
---

# Nushell Storage & File Formats

Guide for data persistence, file format handling, and SQLite storage in Nushell. Covers the `stor` commands for in-memory SQLite, file format conversions, and efficient data storage patterns.

## The stor System

Nushell's `stor` provides an in-memory SQLite database accessible across commands:

```nushell
# Available stor commands
stor create    # Create table
stor delete    # Delete rows
stor export    # Export to file
stor import    # Import from file
stor insert    # Insert rows
stor open      # Open/create database
stor reset     # Reset database
stor update    # Update rows
help stor      # Full documentation
```

### Creating Tables

```nushell
# Create table with schema
stor create --table-name users --columns {
    id: int
    name: str
    email: str
    created_at: datetime
    active: bool
}

# View tables
stor open | schema
```

### Inserting Data

```nushell
# Insert single row
stor insert --table-name users --data-record {
    id: 1
    name: "Alice"
    email: "alice@example.com"
    created_at: (date now)
    active: true
}

# Insert multiple rows from table
[[id, name, email]; [2, "Bob", "bob@example.com"], [3, "Carol", "carol@example.com"]]
| each { |row|
    stor insert --table-name users --data-record $row
}
```

### Querying Data

```nushell
# Query with SQL
stor open | query db "SELECT * FROM users WHERE active = 1"

# Query with conditions
stor open | query db "SELECT name, email FROM users WHERE id > 1 ORDER BY name"

# Aggregations
stor open | query db "SELECT COUNT(*) as count, active FROM users GROUP BY active"
```

### Updating and Deleting

```nushell
# Update rows
stor update --table-name users --update-record {active: false} --where-clause "id = 1"

# Delete rows
stor delete --table-name users --where-clause "active = 0"
```

### Persistence

```nushell
# Export to SQLite file
stor export --file-name data.sqlite

# Import from SQLite file
stor import --file-name data.sqlite

# Reset in-memory database
stor reset
```

## File Formats

### CSV

```nushell
# Read CSV
open data.csv                      # Auto-detect
open data.csv --raw | from csv     # Explicit

# Read with options
open data.tsv | from csv --separator "\t"
open data.csv | from csv --noheaders

# Write CSV
$data | to csv | save output.csv
$data | to csv --noheaders | save output.csv

# Streaming large CSV
open large.csv | take 1000 | to csv | save sample.csv
```

### JSON

```nushell
# Read JSON
open data.json                     # Auto-detect
open config.json | get settings    # Navigate structure

# Write JSON
$data | to json | save output.json
$data | to json --indent 2 | save pretty.json

# JSON Lines (newline-delimited)
open events.jsonl | lines | each { from sideways | from json }
$records | each { |r| $r | to json } | str join "\n" | save events.jsonl
```

### Parquet

Parquet provides columnar storage with compression - ideal for large datasets:

```nushell
# Read parquet (requires polars or formats plugin)
open data.parquet

# Write parquet
$data | polars into-df | polars save output.parquet

# Read parquet with polars
polars open data.parquet

# Efficient large file handling
polars scan-parquet "data/*.parquet"
| polars filter ((polars col year) == 2024)
| polars collect
```

### TOML and YAML

```nushell
# Read TOML
open config.toml
open Cargo.toml | get package.name

# Write TOML
$config | to toml | save config.toml

# Read YAML
open data.yaml
open deployment.yaml | get spec.containers

# Write YAML
$data | to yaml | save output.yaml
```

### NUON (Nushell Object Notation)

NUON is Nushell's native format - preserves types exactly:

```nushell
# Read NUON
open data.nuon

# Write NUON
$data | to nuon | save data.nuon

# Benefits over JSON:
# - Preserves dates, durations, filesizes
# - Supports comments
# - More readable
```

### XML

```nushell
# Read XML
open feed.xml | from xml

# Navigate XML structure
open pom.xml | from xml | get project.dependencies.dependency

# Write XML (limited)
$data | to xml | save output.xml
```

## Format Conversion

### Common Conversions

```nushell
# CSV to Parquet (efficient storage)
open large.csv | polars into-df | polars save data.parquet

# JSON to CSV
open data.json | get items | to csv | save data.csv

# Parquet to JSON
polars open data.parquet | polars into-nu | to json | save data.json

# YAML to TOML
open config.yaml | to toml | save config.toml
```

### Batch Conversion

```nushell
# Convert all CSV files to parquet
ls *.csv | each { |f|
    let output = $f.name | str replace ".csv" ".parquet"
    open $f.name | polars into-df | polars save $output
    print $"Converted: ($f.name) -> ($output)"
}
```

## Storage Patterns

### Configuration Storage

```nushell
# config.nu - Store app configuration
export def "config load" [name: string] {
    let path = [$nu.home-path, ".config", $name, "config.toml"] | path join
    if ($path | path exists) {
        open $path
    } else {
        {}
    }
}

export def "config save" [name: string, data: record] {
    let dir = [$nu.home-path, ".config", $name] | path join
    mkdir $dir
    $data | to toml | save --force ([$dir, "config.toml"] | path join)
}

# Usage
let cfg = config load "myapp"
config save "myapp" {api_url: "https://api.example.com", timeout: 30}
```

### Cache Pattern

```nushell
# Cache expensive operations
def cached-fetch [url: string, --ttl: duration = 1hr] {
    let cache_dir = [$nu.home-path, ".cache", "nushell"] | path join
    let cache_file = [$cache_dir, ($url | hash md5)] | path join

    mkdir $cache_dir

    if ($cache_file | path exists) {
        let age = (date now) - (ls $cache_file | get 0.modified)
        if $age < $ttl {
            return (open $cache_file)
        }
    }

    let data = http get $url
    $data | to json | save --force $cache_file
    $data
}
```

### Session State

```nushell
# Persist state between shell sessions
export def "state save" [key: string, value: any] {
    stor create --table-name state --columns {key: str, value: str} | ignore
    stor delete --table-name state --where-clause $"key = '($key)'" | ignore
    stor insert --table-name state --data-record {key: $key, value: ($value | to nuon)}
}

export def "state load" [key: string, default?: any] {
    let result = stor open | query db $"SELECT value FROM state WHERE key = '($key)'"
    if ($result | is-empty) {
        $default
    } else {
        $result.0.value | from nuon
    }
}
```

## Database Patterns

### Schema Migrations

```nushell
# Track schema version
def migrate [target_version: int] {
    let current = stor open
    | query db "SELECT version FROM schema_version"
    | get 0?.version
    | default 0

    if $current < $target_version {
        for v in ($current + 1)..=$target_version {
            print $"Migrating to version ($v)..."
            run-migration $v
        }
    }
}

def run-migration [version: int] {
    match $version {
        1 => {
            stor create --table-name users --columns {id: int, name: str}
        }
        2 => {
            stor open | query db "ALTER TABLE users ADD COLUMN email TEXT"
        }
    }
    stor open | query db $"UPDATE schema_version SET version = ($version)"
}
```

### Bulk Operations

```nushell
# Efficient bulk insert
def bulk-insert [table: string, records: list] {
    # Build SQL for bulk insert
    let columns = $records.0 | columns | str join ", "
    let values = $records | each { |r|
        let vals = $r | values | each { |v| $"'($v)'" } | str join ", "
        $"(($vals))"
    } | str join ", "

    stor open | query db $"INSERT INTO ($table) (($columns)) VALUES ($values)"
}
```

## Performance Tips

1. **Use parquet for large datasets** - Columnar format with compression
2. **Prefer stor for temporary data** - Fast in-memory SQLite
3. **Export stor periodically** - Persist important data
4. **Use lazy loading** - `polars scan-parquet` for large files
5. **Index frequently queried columns** - In SQLite files

## Additional Resources

### Reference Files

For detailed techniques:
- **`references/sqlite-tips.md`** - SQLite optimization
- **`references/format-comparison.md`** - When to use each format

### Example Files

Working examples in `examples/`:
- **`etl-pipeline.nu`** - Extract, transform, load workflow
- **`data-migration.nu`** - Schema migration example
