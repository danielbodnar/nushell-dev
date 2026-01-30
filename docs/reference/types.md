# Nushell Type System Reference

## Primitive Types

### int (Integer)

64-bit signed integer.

```nushell
# Literals
42
-17
1_000_000      # Underscores for readability
0xff           # Hexadecimal
0o77           # Octal
0b1010         # Binary

# Conversion
"42" | into int
3.14 | into int           # Truncates to 3
true | into int           # 1
false | into int          # 0

# Operations
5 + 3          # 8
10 - 4         # 6
6 * 7          # 42
15 / 4         # 3 (integer division)
15 // 4        # 3 (explicit floor division)
17 mod 5       # 2
2 ** 10        # 1024
```

### float (Floating Point)

64-bit IEEE 754 floating point.

```nushell
# Literals
3.14
-0.001
1e-5           # Scientific notation
1.5e10

# Special values
inf            # Infinity
-inf           # Negative infinity
nan            # Not a number

# Conversion
"3.14" | into float
42 | into float

# Operations
5.0 / 2.0      # 2.5
3.14 | math round --precision 1  # 3.1
```

### string (String)

UTF-8 encoded text.

```nushell
# Literals
"double quoted"
'single quoted'
`backtick for paths`
$"interpolated ($var)"
$'interpolated ($var)'

# Raw strings (no escapes)
r#'raw "string" with quotes'#
r##'contains r#'nested'#'##

# Escape sequences (double quotes only)
"line\nbreak"
"tab\there"
"quote: \""
"backslash: \\"

# Conversion
42 | into string
[1, 2, 3] | str join ", "  # "1, 2, 3"

# Common operations
"hello" | str length       # 5
"hello" | str upcase       # "HELLO"
"  trim  " | str trim      # "trim"
"hello" | str contains "ll" # true
```

### bool (Boolean)

```nushell
# Literals
true
false

# Conversion
1 | into bool              # true
0 | into bool              # false
"true" | into bool         # true
"" | is-empty              # true

# Operations
true and false             # false
true or false              # true
not true                   # false
true xor false             # true
```

### duration (Duration)

Time duration with units.

```nushell
# Units
1ns            # nanosecond
1us            # microsecond
1ms            # millisecond
1sec           # second
1min           # minute
1hr            # hour
1day           # day
1wk            # week

# Arithmetic
5min + 30sec               # 5min 30sec
1hr - 15min                # 45min
2 * 30min                  # 1hr
1hr / 4                    # 15min

# Conversion
"5min" | into duration
300 | into duration        # 300ns by default

# Comparison
5min > 4min                # true
sleep 1sec                 # Wait for duration
```

### filesize (File Size)

File size with units.

```nushell
# Units (binary, base 1024)
1b             # byte
1kb            # kilobyte (1024 bytes)
1mb            # megabyte
1gb            # gigabyte
1tb            # terabyte
1pb            # petabyte
1eb            # exabyte

# Alternative units (metric)
1kib           # kibibyte
1mib           # mebibyte
1gib           # gibibyte

# Conversion
"10mb" | into filesize
1048576 | into filesize    # 1.0 MiB

# Operations
1gb + 512mb                # 1.5 GiB
10gb - 2gb                 # 8.0 GiB
```

### datetime (Date/Time)

Date and time with timezone.

```nushell
# Current time
date now

# Literals
2024-01-15
2024-01-15T14:30:00
2024-01-15T14:30:00+05:00  # With timezone

# Conversion
"2024-01-15" | into datetime
"Jan 15, 2024" | into datetime --format "%b %d, %Y"

# Formatting
date now | format date "%Y-%m-%d"
date now | format date "%A, %B %d, %Y"

# Components
date now | date to-record
# {year: 2024, month: 1, day: 15, hour: 14, minute: 30, ...}

# Arithmetic
(date now) - 1day
(date now) + 2wk
```

### nothing (Null)

Absence of value.

```nushell
# Literal
null

# Checking
$value == null
$value | is-empty

# Default fallback
$maybe_null | default "fallback"
$record.field? | default "missing"
```

### binary (Binary Data)

Raw byte sequences.

```nushell
# Literals
0x[FF 00 AB CD]
0b[11111111 00000000]      # Binary notation

# From string
"hello" | into binary

# To string
0x[68 65 6c 6c 6f] | decode utf-8

# Base64
"hello" | encode base64
"aGVsbG8=" | decode base64

# Hashing
open file.bin | hash sha256
```

### range (Range)

Numeric ranges for iteration.

```nushell
# Inclusive range
1..5           # [1, 2, 3, 4, 5]

# Half-open range
1..<5          # [1, 2, 3, 4]

# Step range
1..2..10       # [1, 3, 5, 7, 9]

# Reverse range
5..1           # [5, 4, 3, 2, 1]

# In iterations
for i in 1..5 { print $i }

# Slicing
[a, b, c, d, e] | range 1..3  # [b, c, d]
```

---

## Structured Types

### list (List)

Ordered collection of values.

```nushell
# Literals
[1, 2, 3]
["a", "b", "c"]
[1, "mixed", true]         # Heterogeneous

# Type annotation
list<int>
list<string>
list<any>

# Operations
$list | length             # Count items
$list | first              # First item
$list | last               # Last item
$list | get 2              # Index access
$list.2                    # Shorthand index
$list | reverse
$list | sort
$list | uniq
$list | flatten            # Flatten nested

# Transformations
$list | each { |x| $x * 2 }
$list | where { |x| $x > 0 }
$list | reduce { |acc, x| $acc + $x }

# Building
[...$list1, ...$list2]     # Spread/concat
$list ++ [new_item]        # Append
[new_item] ++ $list        # Prepend
```

### record (Record)

Key-value mapping with string keys.

```nushell
# Literals
{name: "Alice", age: 30}
{
    nested: {
        deep: "value"
    }
}

# Type annotation
record                     # Any record
record<name: string, age: int>  # Specific fields

# Access
$record.name
$record | get name
$record.nested.deep        # Nested access
$record.maybe?             # Optional access

# Modification
$record | insert new_field "value"
$record | update name "Bob"
$record | reject age       # Remove field
$record | rename {old: new}

# Operations
$record | columns          # Get keys
$record | values           # Get values
$record | transpose key value  # To table

# Merging
{a: 1} | merge {b: 2}      # {a: 1, b: 2}
{...$rec1, ...$rec2}       # Spread merge
```

### table (Table)

List of records with consistent columns.

```nushell
# Literals
[[name, age]; ["Alice", 30], ["Bob", 25]]

# From records
[{name: "Alice", age: 30}, {name: "Bob", age: 25}]

# Operations
$table | select name age   # Select columns
$table | reject internal   # Drop columns
$table | where age > 25    # Filter rows
$table | sort-by age       # Sort
$table | first 10          # Limit rows
$table | rename {old: new} # Rename columns

# Aggregation
$table | group-by status
$table | get age | math avg

# Schema inspection
$table | columns           # Column names
$table | describe          # Type info
```

### closure (Closure)

Anonymous function capturing environment.

```nushell
# Syntax
{|x| $x * 2}              # Explicit parameter
{ $in * 2 }               # Implicit $in parameter
{|a, b| $a + $b}          # Multiple parameters

# Type annotation
closure                    # Any closure

# Usage
let double = {|x| $x * 2}
do $double 5               # 10

# In commands
[1, 2, 3] | each { |n| $n * 2 }
{a: 1} | update a { |r| $r.a + 1 }

# Capturing environment
let multiplier = 3
let multiply = {|x| $x * $multiplier}
do $multiply 5             # 15
```

---

## Type Annotations

### In Function Signatures

```nushell
def process [
    input: string              # Required typed parameter
    count?: int                # Optional parameter
    --flag: bool               # Boolean flag
    --value: string = "default" # Flag with default
    ...rest: int               # Rest parameter
] -> record {                  # Return type
    # Implementation
}
```

### Type Checking

```nushell
# Check type at runtime
$value | describe              # Returns type name
($value | describe) == "int"   # Type comparison

# Type coercion
$value | into int
$value | into string
$value | into bool
```

### Generic Types

```nushell
# List with element type
list<string>
list<record<name: string>>

# Record with field types
record<id: int, name: string, active: bool>

# Table (implied from record)
table<id: int, name: string>
```

---

## Type Conversion Summary

| From | To | Method |
|------|-----|--------|
| string | int | `into int` |
| string | float | `into float` |
| string | bool | `into bool` |
| string | datetime | `into datetime` |
| string | duration | `into duration` |
| string | filesize | `into filesize` |
| string | binary | `into binary` |
| int | string | `into string` |
| int | float | `into float` |
| int | bool | `into bool` |
| int | filesize | `into filesize` |
| float | int | `into int` |
| float | string | `into string` |
| list | string | `str join` |
| record | table | `transpose` |
| any | json | `to json` |
| json | any | `from json` |
