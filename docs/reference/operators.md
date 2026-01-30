# Nushell Operators Reference

## Arithmetic Operators

| Operator | Description | Example | Result |
|----------|-------------|---------|--------|
| `+` | Addition | `5 + 3` | `8` |
| `-` | Subtraction | `10 - 4` | `6` |
| `*` | Multiplication | `6 * 7` | `42` |
| `/` | Division | `15 / 4` | `3.75` |
| `//` | Floor division | `15 // 4` | `3` |
| `mod` | Modulo | `17 mod 5` | `2` |
| `**` | Exponentiation | `2 ** 10` | `1024` |

### Type-Specific Arithmetic

```nushell
# Integers
5 + 3                      # 8
10 - 4                     # 6

# Floats
5.0 / 2.0                  # 2.5
3.14 * 2                   # 6.28

# Durations
5min + 30sec               # 5min 30sec
1hr - 15min                # 45min
2 * 30min                  # 1hr

# Filesizes
1gb + 512mb                # 1.5 GiB
10gb / 2                   # 5.0 GiB

# Dates
(date now) + 1day          # Tomorrow
(date now) - 1wk           # Last week

# Strings (concatenation)
"hello" + " " + "world"    # "hello world"
```

---

## Comparison Operators

| Operator | Description | Example | Result |
|----------|-------------|---------|--------|
| `==` | Equal | `5 == 5` | `true` |
| `!=` | Not equal | `5 != 3` | `true` |
| `<` | Less than | `3 < 5` | `true` |
| `>` | Greater than | `5 > 3` | `true` |
| `<=` | Less or equal | `5 <= 5` | `true` |
| `>=` | Greater or equal | `5 >= 3` | `true` |

### Type-Specific Comparisons

```nushell
# Numbers
5 == 5                     # true
5 == 5.0                   # true (cross-type)

# Strings
"hello" == "hello"         # true
"abc" < "abd"              # true (lexicographic)

# Dates
(date now) > ((date now) - 1day)  # true

# Durations
5min > 4min                # true

# Filesizes
1gb > 512mb                # true

# Lists
[1, 2] == [1, 2]           # true
[1, 2] == [2, 1]           # false (order matters)

# Records
{a: 1} == {a: 1}           # true
{a: 1, b: 2} == {b: 2, a: 1}  # true (order doesn't matter)
```

---

## Logical Operators

| Operator | Description | Example | Result |
|----------|-------------|---------|--------|
| `and` | Logical AND | `true and false` | `false` |
| `or` | Logical OR | `true or false` | `true` |
| `not` | Logical NOT | `not true` | `false` |
| `xor` | Exclusive OR | `true xor false` | `true` |

### Short-Circuit Evaluation

```nushell
# `and` stops if first is false
false and (expensive_operation)  # expensive_operation not called

# `or` stops if first is true
true or (expensive_operation)    # expensive_operation not called
```

### In Conditions

```nushell
if $a > 0 and $b > 0 {
    "both positive"
}

if $x == null or ($x | is-empty) {
    "missing or empty"
}

if not ($list | is-empty) {
    "has items"
}
```

---

## String Operators

| Operator | Description | Example | Result |
|----------|-------------|---------|--------|
| `=~` | Regex match | `"hello" =~ "ell"` | `true` |
| `!~` | Regex not match | `"hello" !~ "xyz"` | `true` |
| `++` | Concatenation | `"a" ++ "b"` | `"ab"` |
| `in` | Contains | `"ll" in "hello"` | `true` |
| `not-in` | Not contains | `"x" not-in "hello"` | `true` |

### String Matching Examples

```nushell
# Regex matching
"hello world" =~ 'world$'          # true
"hello123" =~ '\d+'                # true
"email@example.com" =~ '@.*\.'     # true

# Negated regex
"hello" !~ '\d'                    # true (no digits)

# Substring check
"ell" in "hello"                   # true
"xyz" not-in "hello"               # true

# Concatenation
"hello" ++ " " ++ "world"          # "hello world"
["a", "b"] ++ ["c"]                # ["a", "b", "c"]
```

---

## List and Collection Operators

| Operator | Description | Example | Result |
|----------|-------------|---------|--------|
| `++` | Concatenation | `[1, 2] ++ [3]` | `[1, 2, 3]` |
| `in` | Membership | `2 in [1, 2, 3]` | `true` |
| `not-in` | Not member | `5 not-in [1, 2, 3]` | `true` |

### Collection Examples

```nushell
# List concatenation
[1, 2] ++ [3, 4]                   # [1, 2, 3, 4]

# List membership
"apple" in ["apple", "banana"]     # true
42 in [1, 2, 3]                    # false

# Record key check
"name" in ($record | columns)      # true

# Table row check (using where)
($table | where id == 5 | is-not-empty)
```

---

## Pipeline Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `\|` | Pipe | `ls \| where size > 1mb` |
| `\|>` | Pipe (same as `\|`) | `data \|> transform` |

### Redirection Operators

| Operator | Description |
|----------|-------------|
| `o>` | Redirect stdout to file |
| `e>` | Redirect stderr to file |
| `o+e>` | Redirect both to file |
| `o>\|` | Pipe stdout |
| `e>\|` | Pipe stderr |
| `o+e>\|` | Pipe both |

### Redirection Examples

```nushell
# Redirect stdout
ls o> files.txt

# Redirect stderr
command e> errors.txt

# Redirect both
command o+e> output.txt

# Pipe stderr to another command
command e>| process-errors

# Discard output
command o+e>| ignore
```

---

## Assignment Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `=` | Assign | `let x = 5` |
| `+=` | Add and assign | `$x += 1` |
| `-=` | Subtract and assign | `$x -= 1` |
| `*=` | Multiply and assign | `$x *= 2` |
| `/=` | Divide and assign | `$x /= 2` |
| `++=` | Append and assign | `$list ++= [item]` |

### Assignment Examples

```nushell
# Basic assignment
let x = 5
mut y = 10

# Compound assignment (mutable only)
mut counter = 0
$counter += 1              # counter = 1
$counter -= 1              # counter = 0
$counter *= 5              # counter = 0

mut list = [1, 2]
$list ++= [3]              # list = [1, 2, 3]

mut record = {a: 1}
$record = ($record | insert b 2)
```

---

## Spread Operator

| Operator | Description | Example |
|----------|-------------|---------|
| `...` | Spread | `[...$list1, ...$list2]` |

### Spread Examples

```nushell
# List spreading
let a = [1, 2]
let b = [3, 4]
[...$a, ...$b]             # [1, 2, 3, 4]

# Record spreading
let base = {a: 1, b: 2}
{...$base, c: 3}           # {a: 1, b: 2, c: 3}

# Override with spread
let defaults = {timeout: 30, retries: 3}
let custom = {timeout: 60}
{...$defaults, ...$custom} # {timeout: 60, retries: 3}

# In function calls
def sum [...nums: int] { $nums | math sum }
let values = [1, 2, 3]
sum ...$values             # 6
```

---

## Range Operator

| Operator | Description | Example | Result |
|----------|-------------|---------|--------|
| `..` | Inclusive range | `1..5` | `[1,2,3,4,5]` |
| `..<` | Half-open range | `1..<5` | `[1,2,3,4]` |

### Range Examples

```nushell
# Basic ranges
1..5                       # [1, 2, 3, 4, 5]
1..<5                      # [1, 2, 3, 4]

# Reverse range
5..1                       # [5, 4, 3, 2, 1]

# Step range
1..2..10                   # [1, 3, 5, 7, 9]

# Character range
'a'..'e'                   # ['a', 'b', 'c', 'd', 'e']

# In for loops
for i in 1..5 { print $i }

# In slicing
[a, b, c, d, e] | range 1..3  # [b, c, d]
```

---

## Optional Access Operator

| Operator | Description | Example |
|----------|-------------|---------|
| `?` | Optional/safe access | `$record.field?` |

### Optional Access Examples

```nushell
# Safe field access
$record.maybe_field?               # null if missing
$record.nested?.deep?              # Chain optional

# With default
$record.field? | default "fallback"

# Environment variables
$env.OPTIONAL_VAR?

# In conditions
if $record.field? != null {
    process $record.field
}
```

---

## Operator Precedence

From highest to lowest:

1. `**` (exponentiation)
2. `*`, `/`, `//`, `mod`
3. `+`, `-`
4. `++` (concatenation)
5. `..`, `..<` (ranges)
6. `in`, `not-in`, `=~`, `!~`
7. `<`, `>`, `<=`, `>=`
8. `==`, `!=`
9. `not`
10. `and`
11. `xor`
12. `or`
13. `=`, `+=`, `-=`, `*=`, `/=`, `++=`

### Using Parentheses

```nushell
# Clarify precedence
(5 + 3) * 2                # 16
5 + (3 * 2)                # 11

# Complex conditions
($a > 0) and ($b < 10 or $c == 0)

# Nested expressions
((1 + 2) * 3) ** 2         # 81
```
