---
name: nushell-data-processing
description: This skill should be used when the user asks to "process data in Nushell", "use polars", "work with dataframes", "use lazyframes", "analyze CSV data", "transform large datasets", "aggregate data", "join tables", "pivot data", "melt dataframes", or mentions polars, dataframes, lazyframes, or high-performance data manipulation in Nushell.
version: 1.0.0
---

# Nushell Data Processing

High-performance data processing using Polars DataFrames and LazyFrames in Nushell. Polars provides blazing-fast operations on large datasets with a familiar DataFrame API.

## Why Polars?

| Feature | Native Nushell | Polars |
|---------|---------------|--------|
| Performance | Good for small data | Optimized for millions of rows |
| Memory | Eager evaluation | Lazy evaluation, query optimization |
| Operations | Basic transforms | Full SQL-like operations |
| Parallelism | `par-each` | Built-in multi-threading |

**Rule of thumb:** Use Polars for datasets > 10,000 rows or complex aggregations.

## Getting Started

### Enable Polars Plugin

```nushell
# Add polars plugin
plugin add polars

# Verify installation
plugin list | where name == polars
```

### DataFrame vs LazyFrame

| Type | Description | Use Case |
|------|-------------|----------|
| DataFrame | Eager evaluation, immediate results | Small data, exploration |
| LazyFrame | Lazy evaluation, optimized execution | Large data, complex queries |

```nushell
# DataFrame - evaluates immediately
let df = [[a, b]; [1, 2], [3, 4]] | polars into-df

# LazyFrame - deferred execution
let lf = [[a, b]; [1, 2], [3, 4]] | polars into-lazy

# Execute lazy frame
$lf | polars collect
```

## Core Operations

### Creating DataFrames

```nushell
# From Nushell table
[[name, age, city]; ["Alice", 30, "NYC"], ["Bob", 25, "LA"]]
| polars into-df

# From file
polars open data.csv
polars open data.parquet
polars open data.json --json-lines

# From record
{a: [1, 2, 3], b: [4, 5, 6]} | polars into-df
```

### Selection and Filtering

```nushell
# Select columns
$df | polars select [name, age]

# Filter rows
$df | polars filter ((polars col age) > 25)

# Combined
$df
| polars filter ((polars col city) == "NYC")
| polars select [name, age]
```

### Expressions

Polars expressions are the building blocks:

```nushell
# Column reference
polars col age

# Literal value
polars lit 100

# Arithmetic
(polars col price) * (polars col quantity)

# String operations
(polars col name) | polars str-slice 0 3

# Conditionals
polars when ((polars col age) > 30) "senior" | polars otherwise "junior"
```

### Transformations

```nushell
# Add column
$df | polars with-column [(
    (polars col age) * 2 | polars as "age_doubled"
)]

# Rename columns
$df | polars rename {old_name: new_name}

# Cast types
$df | polars cast {age: "f64"}

# Sort
$df | polars sort-by [age --descending]
```

### Aggregations

```nushell
# Group and aggregate
$df
| polars group-by [city]
| polars agg [
    ((polars col age) | polars mean | polars as "avg_age")
    ((polars col age) | polars count | polars as "count")
    ((polars col salary) | polars sum | polars as "total_salary")
]

# Available aggregations
polars sum       # Sum values
polars mean      # Average
polars median    # Median
polars min       # Minimum
polars max       # Maximum
polars count     # Count rows
polars std       # Standard deviation
polars var       # Variance
polars first     # First value
polars last      # Last value
polars n-unique  # Count unique
```

### Joins

```nushell
# Inner join
$df1 | polars join $df2 --left [id] --right [user_id]

# Left join
$df1 | polars join $df2 --left [id] --right [user_id] --how left

# Join types: inner, left, right, outer, cross, semi, anti
```

### Reshaping

```nushell
# Pivot (wide format)
$df | polars pivot --on category --index date --values amount

# Melt (long format)
$df | polars melt --id-columns [id, date] --variable-name "metric" --value-name "value"

# Explode list column
$df | polars explode [tags]

# Unique rows
$df | polars unique --subset [name, email]
```

## LazyFrame Optimization

### Query Planning

LazyFrames optimize queries before execution:

```nushell
let query = polars open data.parquet
| polars lazy
| polars filter ((polars col status) == "active")
| polars select [id, name, created_at]
| polars sort-by [created_at]

# View the optimized plan
$query | polars explain

# Execute
$query | polars collect
```

### Predicate Pushdown

Filters are pushed to file readers when possible:

```nushell
# Polars only reads matching rows from parquet
polars scan-parquet "large_data/*.parquet"
| polars filter ((polars col year) == 2024)
| polars collect
```

### Streaming Mode

Process data larger than memory:

```nushell
polars scan-parquet "huge_data.parquet"
| polars filter ((polars col value) > 0)
| polars group-by [category]
| polars agg [((polars col value) | polars sum)]
| polars collect --streaming
```

## Common Patterns

### Data Cleaning

```nushell
# Handle missing values
$df
| polars with-column [
    ((polars col age) | polars fill-null 0)
    ((polars col name) | polars fill-null "Unknown")
]

# Drop nulls
$df | polars drop-nulls --subset [required_field]

# Remove duplicates
$df | polars unique --subset [email] --keep first
```

### Time Series

```nushell
# Parse dates
$df | polars with-column [
    ((polars col date_str) | polars str-to-date "%Y-%m-%d")
]

# Group by time periods
$df
| polars group-by-dynamic "timestamp" --every "1d"
| polars agg [((polars col value) | polars sum)]

# Rolling windows
$df | polars with-column [
    ((polars col value) | polars rolling mean 7 | polars as "rolling_avg")
]
```

### Large File Processing

```nushell
# Efficient parquet processing
def process-large-data [input_path: path, output_path: path] {
    polars scan-parquet $input_path
    | polars filter ((polars col status) != "deleted")
    | polars with-column [
        ((polars col amount) * (polars col quantity) | polars as "total")
    ]
    | polars group-by [customer_id]
    | polars agg [
        ((polars col total) | polars sum | polars as "customer_total")
    ]
    | polars collect --streaming
    | polars save $output_path
}
```

## Integration with Native Nushell

### Converting Between Formats

```nushell
# DataFrame to Nushell table
$df | polars into-nu

# Nushell to DataFrame
$nushell_table | polars into-df

# Round-trip
$data
| polars into-df
| polars filter (...)
| polars into-nu
| each { |row| ... }  # Native Nushell processing
```

### Hybrid Pipelines

```nushell
# Use polars for heavy lifting, Nushell for final formatting
open large_data.csv
| polars into-lazy
| polars group-by [category]
| polars agg [((polars col value) | polars sum | polars as "total")]
| polars collect
| polars into-nu
| each { |row|
    {
        category: $row.category
        total: $"$($row.total | into string --decimals 2)"
    }
}
```

## Performance Tips

1. **Use LazyFrames** for complex queries on large data
2. **Prefer parquet** over CSV for repeated reads
3. **Filter early** to reduce data volume
4. **Select needed columns only** to reduce memory
5. **Use streaming** for datasets larger than RAM
6. **Avoid `into-nu` on large results** - process in Polars

## Additional Resources

### Reference Files

For detailed techniques and advanced patterns:
- **`references/polars-api.md`** - Complete Polars command reference
- **`references/performance.md`** - Performance optimization guide
- **`references/recipes.md`** - Common data processing recipes

### Example Files

Working examples in `examples/`:
- **`csv-analysis.nu`** - CSV file analysis workflow
- **`parquet-etl.nu`** - ETL pipeline with parquet
- **`timeseries.nu`** - Time series processing

### Scripts

Utility scripts in `scripts/`:
- **`benchmark.nu`** - Compare Polars vs native performance
