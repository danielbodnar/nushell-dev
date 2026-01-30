# Nushell Performance Guide

Techniques for writing fast, efficient Nushell scripts.

## Profiling and Measurement

### Timing Commands

```nushell
# Measure execution time
timeit { open large.csv | where amount > 100 }

# Compare approaches
let time1 = timeit { approach_one }
let time2 = timeit { approach_two }
print $"Approach 1: ($time1), Approach 2: ($time2)"
```

### Memory Awareness

```nushell
# Check data size before processing
let data = open large.json
print $"Records: ($data | length)"
print $"Size estimate: ($data | to json | str length | into filesize)"
```

---

## Data Processing Optimization

### Use where Instead of Manual Filtering

```nushell
# Slow: Manual filtering with each
ls **/*.nu | each { |f| if $f.size > 1kb { $f } } | compact

# Fast: Use where (optimized)
ls **/*.nu | where size > 1kb
```

### Use par-each for Parallelism

```nushell
# Sequential (slow for I/O-bound tasks)
ls **/*.json | each { |f| open $f.name | process }

# Parallel (much faster)
ls **/*.json | par-each { |f| open $f.name | process }

# Control thread count
ls **/*.json | par-each --threads 8 { |f| process $f }
```

### Avoid Repeated File Reads

```nushell
# Bad: Re-reads file in each iteration
for item in (open data.json | get items) {
    let full = open data.json  # Reads entire file again!
}

# Good: Read once, reuse
let data = open data.json
let items = $data | get items
for item in $items {
    # Use $data if needed
}
```

### Select Columns Early

```nushell
# Slow: Process all columns, then select
open large.csv | expensive_transform | select id name

# Fast: Select early, process less data
open large.csv | select id name amount | where amount > 0
```

### Filter Early

```nushell
# Slow: Process all, then filter
open huge.json | transform_all | where status == "active"

# Fast: Filter first, process less
open huge.json | where status == "active" | transform_all
```

---

## Polars for Large Data

### When to Use Polars

| Data Size | Recommendation |
|-----------|----------------|
| < 1,000 rows | Native Nushell |
| 1,000 - 100,000 rows | Either works |
| > 100,000 rows | Use Polars |
| Complex aggregations | Use Polars |

### LazyFrame Optimization

```nushell
# Lazy evaluation with query optimization
polars scan-parquet "data/*.parquet"
| polars filter ((polars col status) == "active")
| polars select [id, name, amount]
| polars group-by [category]
| polars agg [((polars col amount) | polars sum)]
| polars collect  # Executes optimized query
```

### Streaming for Large Files

```nushell
# Process files larger than RAM
polars scan-parquet "huge.parquet"
| polars filter ((polars col year) == 2024)
| polars collect --streaming
```

### Avoid into-nu on Large Results

```nushell
# Bad: Converts large DataFrame to Nushell table
polars open huge.parquet | polars into-nu | each { }

# Good: Process in Polars, convert only final result
polars open huge.parquet
| polars filter (...)
| polars group-by [...]
| polars agg [...]
| polars collect
| polars into-nu  # Small aggregated result
```

---

## String Processing

### Use str Commands Over Regex When Possible

```nushell
# Slower: Regex for simple operations
"hello world" | str replace --regex "world" "nushell"

# Faster: Literal replacement
"hello world" | str replace "world" "nushell"
```

### Batch String Operations

```nushell
# Slow: Multiple operations
$text | str trim | str downcase | str replace "a" "b"

# Equivalent but clearer (same performance)
$text
| str trim
| str downcase
| str replace "a" "b"
```

### Avoid Repeated Parsing

```nushell
# Bad: Parse same string multiple times
if ($text | parse "{name}:{value}").0?.name == "key" {
    let val = ($text | parse "{name}:{value}").0.value
}

# Good: Parse once
let parsed = $text | parse "{name}:{value}" | get 0?
if $parsed?.name == "key" {
    let val = $parsed.value
}
```

---

## File I/O Optimization

### Use Appropriate Formats

| Format | Read Speed | Write Speed | Size | Best For |
|--------|------------|-------------|------|----------|
| Parquet | Fast | Fast | Small | Analytics |
| CSV | Slow | Fast | Medium | Interchange |
| JSON | Medium | Medium | Large | APIs |
| NUON | Fast | Fast | Medium | Nushell state |

### Batch File Operations

```nushell
# Slow: Process one at a time
for file in (ls *.csv) {
    open $file.name | process | save $"processed_($file.name)"
}

# Fast: Parallel processing
ls *.csv | par-each { |f|
    open $f.name | process | save $"processed_($f.name)"
}
```

### Stream Large Files

```nushell
# Memory efficient: Process line by line
open huge.log --raw | lines | where { |l| $l =~ "ERROR" } | first 100

# Avoid loading entire file for simple searches
```

---

## Pipeline Optimization

### Reduce Pipeline Stages

```nushell
# More stages (slightly slower)
$data | where a > 0 | where b > 0 | where c > 0

# Combined condition (faster)
$data | where { |r| $r.a > 0 and $r.b > 0 and $r.c > 0 }
```

### Use chunks for Batch Processing

```nushell
# Process in batches for memory efficiency
open huge.json | get items
| chunks 1000
| each { |batch|
    $batch | par-each { |item| process $item }
}
| flatten
```

### Avoid Unnecessary Conversions

```nushell
# Bad: Unnecessary round-trip
$data | to json | from json | process

# Good: Direct processing
$data | process
```

---

## Memory Management

### Process Incrementally

```nushell
# Bad: Load all into memory
let all_data = ls **/*.json | each { |f| open $f.name }
$all_data | flatten | process

# Good: Stream and process
ls **/*.json | each { |f|
    open $f.name | process | save $"out_($f.name)"
}
```

### Clear Large Variables

```nushell
# Let variables go out of scope
def process-large [] {
    let data = open huge.json  # Large allocation
    let result = $data | summarize
    # $data goes out of scope here
    $result  # Only small result returned
}
```

### Use Generators for Sequences

```nushell
# Bad: Create full list in memory
let nums = 1..1000000 | each { |n| $n * 2 }

# Better: Process lazily
1..1000000 | each { |n| $n * 2 } | take 10
```

---

## External Commands

### Prefer Native Commands

```nushell
# Slower: External command
^grep "pattern" file.txt

# Faster: Native Nushell
open file.txt | lines | where { $in =~ "pattern" }
```

### Batch External Calls

```nushell
# Slow: Many external calls
for f in (ls *.txt) {
    ^wc -l $f.name
}

# Fast: Single external call
^wc -l ...(ls *.txt | get name)
```

### Use complete for Error Handling

```nushell
# Efficient error handling
let result = do { ^risky-command } | complete
if $result.exit_code == 0 {
    $result.stdout
}
```

---

## Caching Strategies

### Cache Expensive Operations

```nushell
def cached-fetch [url: string, --ttl: duration = 1hr] {
    let cache_dir = [$nu.home-path, ".cache", "myapp"] | path join
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

### Memoization Pattern

```nushell
# Store computed results
mut cache = {}

def expensive-compute [key: string] {
    if $key in ($cache | columns) {
        return ($cache | get $key)
    }

    let result = do-expensive-work $key
    $cache = ($cache | insert $key $result)
    $result
}
```

---

## Benchmarking Tips

### Compare Approaches

```nushell
def benchmark [name: string, iterations: int, action: closure] {
    let times = 1..$iterations | each { |_|
        timeit { do $action }
    }

    {
        name: $name
        iterations: $iterations
        total: ($times | math sum)
        avg: ($times | math avg)
        min: ($times | math min)
        max: ($times | math max)
    }
}

# Usage
benchmark "approach1" 100 { approach_one }
benchmark "approach2" 100 { approach_two }
```

### Profile Real Workloads

```nushell
# Test with realistic data sizes
let small = generate-data 100
let medium = generate-data 10000
let large = generate-data 1000000

[small, medium, large] | each { |data|
    timeit { $data | your-function }
}
```
