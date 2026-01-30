# Pipeline Snippets

## Basic Pipelines

### Chained Transformations

```nushell
# Transform data step by step
open users.json
| get data
| where status == "active"
| select name email created_at
| sort-by created_at --reverse
| first 10
```

### Pipeline with Multiple Filters

```nushell
ls **/*
| where type == file
| where size > 1mb
| where modified > ((date now) - 7day)
| sort-by size --reverse
```

### Map-Filter-Reduce Pattern

```nushell
[1, 2, 3, 4, 5]
| each { |n| $n * 2 }           # map
| where { |n| $n > 4 }          # filter
| reduce { |acc, n| $acc + $n } # reduce
```

---

## Data Flow Patterns

### Branching Pipeline

```nushell
let data = open input.json

# Process in parallel branches
let summary = $data | summarize
let details = $data | get items | select id name

# Combine results
{summary: $summary, details: $details}
```

### Conditional Pipeline

```nushell
let data = open input.json

let result = if $env.VERBOSE? != null {
    $data | debug | process
} else {
    $data | process
}
```

### Pipeline with Side Effects

```nushell
open data.csv
| tee { |data| $data | to json | save backup.json }  # Side effect
| where amount > 100
| save filtered.csv
```

---

## Parallel Processing

### Using par-each

```nushell
# Process files in parallel
ls **/*.json | par-each { |f|
    open $f.name | get items | length
}
```

### Parallel with Thread Limit

```nushell
# Limit parallelism
ls **/*.nu | par-each --threads 4 { |f|
    open $f.name | lines | length
}
```

### Parallel Batch Processing

```nushell
# Process in batches for memory efficiency
let files = ls **/*.csv | get name

$files
| chunks 10
| each { |batch|
    $batch | par-each { |f| open $f | process }
}
| flatten
```

---

## Streaming Patterns

### Process Large Files

```nushell
# Stream lines without loading entire file
open large.log --raw
| lines
| where { |line| $line | str contains "ERROR" }
| first 100
```

### Stream JSON Lines

```nushell
# Process JSONL file
open events.jsonl --raw
| lines
| each { |line| $line | from json }
| where event_type == "purchase"
```

### Chunked Processing

```nushell
# Process in fixed-size chunks
open huge.csv
| chunks 1000
| enumerate
| each { |chunk|
    print $"Processing chunk ($chunk.index)..."
    $chunk.item | process-batch
}
```

---

## Pipeline Inspection

### Debugging Pipelines

```nushell
# Inspect intermediate values
open data.json
| debug                    # Print and pass through
| get items
| debug                    # Print again
| where active == true
```

### Type Inspection

```nushell
# Check data shape
open data.json | describe

# Check column types
open data.csv | schema
```

### Pipeline Timing

```nushell
# Measure execution time
timeit {
    open large.csv | where amount > 100 | length
}
```

---

## Error Recovery in Pipelines

### Try in Pipeline

```nushell
ls **/*.json
| each { |f|
    try {
        {file: $f.name, data: (open $f.name)}
    } catch {
        {file: $f.name, data: null, error: true}
    }
}
| where data != null
```

### Skip Errors

```nushell
# Skip failed items
$urls | each { |url|
    try { http get $url } catch { null }
} | compact
```

### Collect Errors

```nushell
# Collect both successes and failures
$items | each { |item|
    try {
        {ok: true, result: (process $item)}
    } catch { |e|
        {ok: false, error: $e.msg, item: $item}
    }
}
| group-by ok
```

---

## Pipeline Composition

### Reusable Pipeline Segments

```nushell
# Define reusable transformations
def clean-data [] {
    where value != null | update value { into float }
}

def aggregate [] {
    group-by category | each { |g| {category: $g.category, total: ($g.items | get value | math sum)} }
}

# Compose
open data.csv | clean-data | aggregate
```

### Pipeline as Argument

```nushell
# Pass pipeline as closure
def process-with [data: any, transform: closure] {
    $data | do $transform
}

process-with (open data.json) { where active == true | select name }
```

### Dynamic Pipeline Construction

```nushell
# Build pipeline based on conditions
def dynamic-filter [data: any, filters: record] {
    mut result = $data

    if $filters.min_amount? != null {
        $result = ($result | where amount >= $filters.min_amount)
    }

    if $filters.status? != null {
        $result = ($result | where status == $filters.status)
    }

    $result
}
```
