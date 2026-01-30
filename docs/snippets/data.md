# Data Manipulation Snippets

## Records

### Create Records

```nushell
# Literal record
let user = {name: "Alice", age: 30, active: true}

# Dynamic keys
let key = "status"
{$key: "active"}

# Merge records
{a: 1, b: 2} | merge {c: 3, b: 99}  # {a: 1, b: 99, c: 3}
```

### Access and Update

```nushell
# Access fields
$user.name                    # "Alice"
$user | get name              # "Alice"
$user.maybe? | default "N/A"  # Safe access

# Update fields
$user | update age 31
$user | update age { |r| $r.age + 1 }

# Insert new field
$user | insert created_at (date now)

# Remove field
$user | reject active

# Rename field
$user | rename {name: full_name}
```

### Record Operations

```nushell
# Get all keys
$record | columns

# Get all values
$record | values

# Check if key exists
"name" in ($record | columns)

# Transpose to table
{a: 1, b: 2, c: 3} | transpose key value
```

---

## Lists

### Create Lists

```nushell
# Literal list
let nums = [1, 2, 3, 4, 5]

# Range
1..10           # [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
1..5 | each { $in * 2 }

# Generate
seq 1 10
seq date --begin 2024-01-01 --end 2024-01-31 --increment 1day
```

### List Operations

```nushell
# Length
$list | length

# Access by index
$list | get 0
$list.2

# Slice
$list | range 0..5
$list | first 3
$list | last 3
$list | skip 2
$list | take 5

# Append/prepend
$list ++ [6, 7]
[0] ++ $list

# Flatten nested
[[1, 2], [3, 4]] | flatten

# Unique values
[1, 2, 2, 3, 3, 3] | uniq

# Sort
$list | sort
$list | sort --reverse

# Reverse
$list | reverse

# Shuffle
$list | shuffle
```

### List Transformations

```nushell
# Each (map)
[1, 2, 3] | each { |n| $n * 2 }

# Where (filter)
[1, 2, 3, 4, 5] | where { |n| $n > 2 }

# Reduce (fold)
[1, 2, 3, 4] | reduce { |acc, n| $acc + $n }
[1, 2, 3, 4] | reduce --fold 0 { |acc, n| $acc + $n }

# Enumerate
["a", "b", "c"] | enumerate
# [{index: 0, item: "a"}, {index: 1, item: "b"}, ...]

# Zip
[1, 2, 3] | zip [a, b, c]
# [[1, a], [2, b], [3, c]]

# Window
[1, 2, 3, 4, 5] | window 3
# [[1, 2, 3], [2, 3, 4], [3, 4, 5]]
```

---

## Tables

### Create Tables

```nushell
# Literal table
[[name, age]; ["Alice", 30], ["Bob", 25]]

# From records
[{name: "Alice", age: 30}, {name: "Bob", age: 25}]

# From columns
{name: ["Alice", "Bob"], age: [30, 25]} | into record | items-to-nu
```

### Table Operations

```nushell
# Select columns
$table | select name age

# Reject columns
$table | reject internal_id

# Rename columns
$table | rename {old_name: new_name}

# Add column
$table | insert full_name { |r| $"($r.first) ($r.last)" }

# Update column
$table | update age { |r| $r.age + 1 }

# Filter rows
$table | where age > 25

# Sort
$table | sort-by age
$table | sort-by age --reverse
$table | sort-by name --natural
```

### Grouping and Aggregation

```nushell
# Group by column
$table | group-by status

# Group and aggregate
$table
| group-by department
| transpose department employees
| each { |g|
    {
        department: $g.department
        count: ($g.employees | length)
        avg_salary: ($g.employees | get salary | math avg)
    }
}

# Built-in aggregations
$table | get salary | math sum
$table | get salary | math avg
$table | get salary | math median
$table | get salary | math min
$table | get salary | math max
$table | get salary | math stddev
```

### Joining Tables

```nushell
# SQL-like join (using polars)
$users | polars into-df | polars join ($orders | polars into-df) --left [id] --right [user_id]

# Manual join
$users | each { |u|
    let orders = $all_orders | where user_id == $u.id
    $u | insert orders $orders
}
```

### Reshaping

```nushell
# Pivot (wide to long)
$table | polars into-df | polars melt --id-columns [id] --variable-name "metric" --value-name "value"

# Transpose
{a: 1, b: 2, c: 3} | transpose key value

# Flatten nested records
$table | flatten addresses  # If addresses is a list column

# Explode list column
$table | polars into-df | polars explode [tags]
```

---

## Type Conversions

### Basic Conversions

```nushell
# String conversions
123 | into string              # "123"
"456" | into int               # 456
"3.14" | into float            # 3.14
"true" | into bool             # true

# Date conversions
"2024-01-15" | into datetime
date now | format date "%Y-%m-%d"

# Filesize conversions
1024 | into filesize           # 1.0 KiB
"10mb" | into filesize         # 10.0 MiB
1gb | into int                 # 1073741824
```

### Format Conversions

```nushell
# JSON
$data | to json
$data | to json --indent 2
"{'key': 'value'}" | from json

# CSV
$table | to csv
"a,b\n1,2" | from csv

# YAML
$data | to yaml
"key: value" | from yaml

# TOML
$config | to toml
"[section]\nkey = 'value'" | from toml

# NUON (Nushell native)
$data | to nuon
"{a: 1, b: 2}" | from nuon
```

---

## String Operations

### Basic String Operations

```nushell
# Case conversion
"hello" | str upcase        # "HELLO"
"HELLO" | str downcase      # "hello"
"hello world" | str capitalize  # "Hello world"

# Trim
"  hello  " | str trim
"hello..." | str trim --right --char '.'

# Length
"hello" | str length

# Contains/starts/ends
"hello world" | str contains "world"
"hello" | str starts-with "he"
"hello" | str ends-with "lo"
```

### String Manipulation

```nushell
# Replace
"hello world" | str replace "world" "nushell"
"a-b-c" | str replace --all "-" "_"
"hello123world" | str replace --regex '\d+' "NUM"

# Split
"a,b,c" | split row ","
"hello" | split chars

# Join
["a", "b", "c"] | str join ", "

# Substring
"hello world" | str substring 0..5
"hello" | str substring 1..

# Pad
"42" | fill --alignment right --width 5 --character '0'
```

### String Parsing

```nushell
# Parse with format
"hello 123" | parse "{word} {number}"

# Parse with regex
"user_123_active" | parse --regex 'user_(?<id>\d+)_(?<status>\w+)'

# Extract matches
"hello@example.com" | str index-of "@"
```

---

## Math and Numbers

### Arithmetic

```nushell
# Basic operations
1 + 2        # 3
10 - 3       # 7
4 * 5        # 20
15 / 4       # 3.75
15 // 4      # 3 (floor division)
17 mod 5     # 2

# Power
2 ** 10      # 1024
9 | math sqrt # 3
```

### Aggregations

```nushell
[1, 2, 3, 4, 5] | math sum       # 15
[1, 2, 3, 4, 5] | math avg       # 3
[1, 2, 3, 4, 5] | math median    # 3
[1, 2, 3, 4, 5] | math min       # 1
[1, 2, 3, 4, 5] | math max       # 5
[1, 2, 3, 4, 5] | math stddev    # ~1.41
[1, 2, 3, 4, 5] | math variance  # 2
```

### Rounding

```nushell
3.7 | math floor    # 3
3.2 | math ceil     # 4
3.5 | math round    # 4
3.14159 | math round --precision 2  # 3.14
```

---

## Dates and Times

### Current Date/Time

```nushell
date now                          # Current datetime
date now | format date "%Y-%m-%d" # 2024-01-15
date now | format date "%H:%M:%S" # 14:30:45
```

### Date Arithmetic

```nushell
(date now) - 1day
(date now) + 2wk
(date now) - 3hr

# Difference between dates
let start = "2024-01-01" | into datetime
let end = "2024-12-31" | into datetime
$end - $start  # Duration
```

### Date Components

```nushell
let d = date now
$d | date to-record
# {year: 2024, month: 1, day: 15, hour: 14, ...}

$d | format date "%A"  # Day name
$d | format date "%B"  # Month name
```

### Date Parsing

```nushell
"2024-01-15" | into datetime
"15/01/2024" | into datetime --format "%d/%m/%Y"
"Jan 15, 2024 2:30 PM" | into datetime --format "%b %d, %Y %I:%M %p"
```
