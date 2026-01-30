# File Operations Snippets

## Reading Files

### Basic File Reading

```nushell
# Auto-detect format
open data.json          # Parsed JSON
open data.csv           # Parsed CSV table
open data.toml          # Parsed TOML
open data.yaml          # Parsed YAML

# Raw content (no parsing)
open file.txt --raw

# Read lines
open log.txt | lines

# Read binary
open image.png | encode base64
```

### Reading with Options

```nushell
# CSV with custom delimiter
open data.tsv | from csv --separator "\t"

# CSV without headers
open data.csv | from csv --noheaders

# JSON Lines
open events.jsonl --raw | lines | each { from json }

# Specific encoding
open file.txt --raw  # UTF-8 by default
```

### Partial File Reading

```nushell
# First N lines
open large.log | lines | first 100

# Last N lines
open large.log | lines | last 50

# Byte range (using external tools)
^head -c 1000 large.bin
```

---

## Writing Files

### Basic File Writing

```nushell
# Write string
"Hello, World!" | save hello.txt

# Write with format conversion
$data | to json | save data.json
$data | to csv | save data.csv
$data | to toml | save config.toml
$data | to yaml | save data.yaml
$data | to nuon | save data.nuon

# Overwrite existing file
$data | save --force output.json
```

### Append to File

```nushell
# Append line
"New log entry" | save --append log.txt

# Append with newline
$"($message)\n" | save --append log.txt
```

### Pretty Printing

```nushell
# Indented JSON
$data | to json --indent 2 | save pretty.json

# Custom JSON formatting
$data | to json --indent 4 --tabs | save output.json
```

---

## File System Operations

### Listing Files

```nushell
# List current directory
ls

# List with details
ls -l

# List recursively
ls **/*

# List specific pattern
ls **/*.nu
ls src/**/*.{ts,js}

# Filter results
ls | where type == file
ls | where size > 1mb
ls | where modified > ((date now) - 7day)
```

### File Information

```nushell
# Check if exists
"file.txt" | path exists

# Get file type
"file.txt" | path type  # "file", "dir", "symlink"

# Get full path
"./relative/path" | path expand

# Parse path components
"/home/user/file.txt" | path parse
# {parent: "/home/user", stem: "file", extension: "txt"}

# Get specific component
"/home/user/file.txt" | path basename   # "file.txt"
"/home/user/file.txt" | path dirname    # "/home/user"
```

### Path Operations

```nushell
# Join paths
[$nu.home-path, ".config", "app"] | path join

# Change extension
"file.txt" | path parse | update extension "md" | path join

# Normalize path
"./foo/../bar/./baz" | path expand

# Relative path
"/home/user/project/src" | path relative-to "/home/user"
```

### Directory Operations

```nushell
# Create directory
mkdir new-dir
mkdir -p nested/path/here

# Remove directory
rm -r directory

# Move/rename
mv old-name new-name

# Copy
cp file.txt backup.txt
cp -r src-dir dest-dir
```

---

## File Format Handling

### JSON

```nushell
# Read and navigate
open config.json | get database.host

# Modify and save
open config.json
| update database.port 5433
| save --force config.json

# Create JSON
{
    name: "app"
    version: "1.0.0"
    dependencies: []
} | to json --indent 2 | save package.json
```

### CSV

```nushell
# Read CSV
let data = open sales.csv

# Transform and save
$data
| where amount > 100
| update amount { |r| $r.amount * 1.1 }
| to csv
| save filtered.csv

# Create CSV from scratch
[[name, email, active]; ["Alice", "alice@example.com", true], ["Bob", "bob@example.com", false]]
| to csv
| save users.csv
```

### TOML

```nushell
# Read TOML config
open Cargo.toml | get package

# Create TOML
{
    package: {
        name: "my-app"
        version: "0.1.0"
    }
    dependencies: {}
} | to toml | save Cargo.toml
```

### YAML

```nushell
# Read Kubernetes manifest
open deployment.yaml | get spec.containers

# Create YAML
{
    apiVersion: "v1"
    kind: "ConfigMap"
    metadata: {name: "my-config"}
    data: {key: "value"}
} | to yaml | save configmap.yaml
```

### Parquet (with Polars)

```nushell
# Read parquet
polars open data.parquet

# Write parquet
$data | polars into-df | polars save output.parquet

# Efficient large file handling
polars scan-parquet "data/*.parquet"
| polars filter ((polars col year) == 2024)
| polars collect
```

### NUON (Nushell Object Notation)

```nushell
# Read NUON (preserves Nushell types)
open state.nuon

# Write NUON
{
    last_run: (date now)
    duration: 5min
    size: 1gb
} | to nuon | save state.nuon
```

---

## Streaming and Large Files

### Process Large Files Line by Line

```nushell
# Stream processing
open huge.log --raw
| lines
| where { |line| $line | str contains "ERROR" }
| first 100
```

### Chunked Processing

```nushell
# Process in chunks
open large.csv
| chunks 10000
| enumerate
| each { |chunk|
    print $"Processing chunk ($chunk.index)..."
    $chunk.item | transform | save $"output_($chunk.index).csv"
}
```

### Binary File Handling

```nushell
# Read binary and encode
open image.png | encode base64 | save image.b64

# Decode and write binary
open image.b64 --raw | decode base64 | save decoded.png

# Get file hash
open file.bin | hash sha256
```

---

## File Watching and Monitoring

### Watch for Changes (using external tools)

```nushell
# Using inotifywait (Linux)
^inotifywait -m -e modify,create,delete ./watched-dir

# Simple polling approach
def watch-file [path: path, action: closure, --interval: duration = 1sec] {
    let initial_modified = ls $path | get 0.modified

    loop {
        sleep $interval
        let current = ls $path | get 0.modified
        if $current != $initial_modified {
            do $action
        }
    }
}
```

### File Comparison

```nushell
# Compare file contents
def files-equal [a: path, b: path] -> bool {
    (open $a | hash sha256) == (open $b | hash sha256)
}

# Diff files
^diff file1.txt file2.txt
```

---

## Temporary Files

### Create Temp Files

```nushell
# Create temp file
let temp = $"($nu.temp-path)/(random uuid).tmp"
$data | save $temp

# Use and cleanup
try {
    process $temp
} catch { |e|
    rm $temp
    error make { msg: $e.msg }
}
rm $temp
```

### Temp Directory Pattern

```nushell
def with-temp-dir [action: closure] {
    let temp_dir = $"($nu.temp-path)/nushell-(random uuid)"
    mkdir $temp_dir

    try {
        cd $temp_dir
        do $action
    } catch { |e|
        rm -r $temp_dir
        error make { msg: $e.msg }
    }

    rm -r $temp_dir
}
```

---

## Glob Patterns

### Common Patterns

```nushell
# All files in directory
ls *

# Recursive search
ls **/*

# Specific extensions
ls **/*.nu
ls **/*.{ts,js,json}

# Exclude patterns (manual filter)
ls **/* | where name !~ "node_modules"

# Hidden files
ls -a | where name =~ "^\\."
```

### Pattern Matching in Code

```nushell
# Check if path matches pattern
"src/main.rs" =~ 'src/.*\.rs$'

# Find files matching pattern
glob "**/*.nu"
```

---

## Compression

### Using External Tools

```nushell
# Create tar.gz
^tar -czf archive.tar.gz directory/

# Extract tar.gz
^tar -xzf archive.tar.gz

# Create zip
^zip -r archive.zip directory/

# Extract zip
^unzip archive.zip
```

### Gzip Individual Files

```nushell
# Compress
^gzip file.txt  # Creates file.txt.gz

# Decompress
^gunzip file.txt.gz
```
