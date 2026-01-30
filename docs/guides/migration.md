# Migration Guide: Bash/Python/jq to Nushell

Practical guide for converting scripts from other languages to idiomatic Nushell.

## Bash to Nushell

### Variables

```bash
# Bash
name="Alice"
echo "Hello, $name"
readonly PI=3.14
export PATH="$HOME/bin:$PATH"
```

```nushell
# Nushell
let name = "Alice"
print $"Hello, ($name)"
const PI = 3.14
$env.PATH = ($env.PATH | prepend ($nu.home-path | path join "bin"))
```

### Conditionals

```bash
# Bash
if [ "$status" = "active" ]; then
    echo "Active"
elif [ "$status" = "pending" ]; then
    echo "Pending"
else
    echo "Unknown"
fi

# Test operators
if [ -f "$file" ]; then echo "exists"; fi
if [ -z "$var" ]; then echo "empty"; fi
if [ "$a" -gt "$b" ]; then echo "greater"; fi
```

```nushell
# Nushell
if $status == "active" {
    print "Active"
} else if $status == "pending" {
    print "Pending"
} else {
    print "Unknown"
}

# Test equivalents
if ($file | path exists) { print "exists" }
if ($var | is-empty) { print "empty" }
if $a > $b { print "greater" }
```

### Loops

```bash
# Bash
for file in *.txt; do
    echo "Processing $file"
done

while read -r line; do
    echo "$line"
done < input.txt

for i in {1..10}; do
    echo "$i"
done
```

```nushell
# Nushell
for file in (ls *.txt) {
    print $"Processing ($file.name)"
}

open input.txt | lines | each { |line|
    print $line
}

for i in 1..10 {
    print $i
}
```

### Command Substitution

```bash
# Bash
files=$(ls -la)
count=$(wc -l < file.txt)
today=$(date +%Y-%m-%d)
```

```nushell
# Nushell
let files = (ls -l)
let count = (open file.txt | lines | length)
let today = (date now | format date "%Y-%m-%d")
```

### Pipes and Redirection

```bash
# Bash
cat file.txt | grep "pattern" | sort | uniq
ls -la > output.txt
command 2>&1 | tee log.txt
```

```nushell
# Nushell
open file.txt | lines | where { $in =~ "pattern" } | sort | uniq
ls -l | to text | save output.txt
do { command } | complete | tee { save log.txt }
```

### Functions

```bash
# Bash
greet() {
    local name=$1
    local greeting=${2:-"Hello"}
    echo "$greeting, $name!"
}
greet "Alice" "Hi"
```

```nushell
# Nushell
def greet [name: string, greeting: string = "Hello"] {
    print $"($greeting), ($name)!"
}
greet "Alice" "Hi"
```

### Common Commands

| Bash | Nushell |
|------|---------|
| `echo "text"` | `print "text"` |
| `cat file` | `open file` |
| `grep pattern` | `where { $in =~ "pattern" }` |
| `grep -v pattern` | `where { $in !~ "pattern" }` |
| `head -n 10` | `first 10` |
| `tail -n 10` | `last 10` |
| `wc -l` | `lines \| length` |
| `sort` | `sort` |
| `sort -u` | `sort \| uniq` |
| `cut -d: -f1` | `split column ":" \| get column1` |
| `awk '{print $1}'` | `split row " " \| get 0` |
| `sed 's/old/new/g'` | `str replace --all "old" "new"` |
| `find . -name "*.txt"` | `ls **/*.txt` |
| `xargs` | `each { \|x\| ... }` |

---

## Python to Nushell

### Data Structures

```python
# Python
names = ["Alice", "Bob", "Carol"]
person = {"name": "Alice", "age": 30}
data = [{"id": 1, "value": "a"}, {"id": 2, "value": "b"}]
```

```nushell
# Nushell
let names = ["Alice", "Bob", "Carol"]
let person = {name: "Alice", age: 30}
let data = [{id: 1, value: "a"}, {id: 2, value: "b"}]
```

### List Operations

```python
# Python
doubled = [x * 2 for x in numbers]
filtered = [x for x in numbers if x > 10]
total = sum(numbers)
squares = list(map(lambda x: x**2, numbers))
```

```nushell
# Nushell
let doubled = $numbers | each { |x| $x * 2 }
let filtered = $numbers | where { |x| $x > 10 }
let total = $numbers | math sum
let squares = $numbers | each { |x| $x ** 2 }
```

### Dictionary Operations

```python
# Python
person["name"]
person.get("age", 0)
person["status"] = "active"
{**dict1, **dict2}
list(person.keys())
```

```nushell
# Nushell
$person.name
$person.age? | default 0
$person | insert status "active"
{...$dict1, ...$dict2}
$person | columns
```

### File Operations

```python
# Python
with open("file.txt") as f:
    content = f.read()

import json
with open("data.json") as f:
    data = json.load(f)

with open("output.json", "w") as f:
    json.dump(data, f, indent=2)
```

```nushell
# Nushell
let content = open file.txt

let data = open data.json

$data | to json --indent 2 | save output.json
```

### HTTP Requests

```python
# Python
import requests

response = requests.get("https://api.example.com/data")
data = response.json()

response = requests.post(
    "https://api.example.com/users",
    json={"name": "Alice"},
    headers={"Authorization": f"Bearer {token}"}
)
```

```nushell
# Nushell
let data = http get "https://api.example.com/data"

let response = http post "https://api.example.com/users" {name: "Alice"} -H {
    Authorization: $"Bearer ($token)"
}
```

### Error Handling

```python
# Python
try:
    result = risky_operation()
except FileNotFoundError:
    print("File not found")
except Exception as e:
    print(f"Error: {e}")
```

```nushell
# Nushell
try {
    let result = risky_operation
} catch { |err|
    if ($err.msg | str contains "not found") {
        print "File not found"
    } else {
        print $"Error: ($err.msg)"
    }
}
```

---

## jq to Nushell

### Basic Selection

```bash
# jq
jq '.name' data.json
jq '.users[0]' data.json
jq '.items[].id' data.json
```

```nushell
# Nushell
open data.json | get name
open data.json | get users.0
open data.json | get items | get id
```

### Filtering

```bash
# jq
jq '.[] | select(.active == true)' data.json
jq '.[] | select(.age > 25)' data.json
jq 'map(select(.status == "active"))' data.json
```

```nushell
# Nushell
open data.json | where active == true
open data.json | where age > 25
open data.json | where status == "active"
```

### Transformation

```bash
# jq
jq '.[] | {id, name}' data.json
jq '.[] | {user: .name, years: .age}' data.json
jq 'map(.price * .quantity)' data.json
```

```nushell
# Nushell
open data.json | select id name
open data.json | each { |r| {user: $r.name, years: $r.age} }
open data.json | each { |r| $r.price * $r.quantity }
```

### Aggregation

```bash
# jq
jq 'length' data.json
jq '[.[] | .amount] | add' data.json
jq 'group_by(.category) | map({key: .[0].category, count: length})' data.json
```

```nushell
# Nushell
open data.json | length
open data.json | get amount | math sum
open data.json | group-by category | transpose key items | each { |g| {key: $g.key, count: ($g.items | length)} }
```

### Conditionals

```bash
# jq
jq 'if .status == "active" then "yes" else "no" end' data.json
jq '.value // "default"' data.json
```

```nushell
# Nushell
open data.json | if $in.status == "active" { "yes" } else { "no" }
open data.json | get value? | default "default"
```

### String Operations

```bash
# jq
jq '.name | ascii_upcase' data.json
jq '.items | join(", ")' data.json
jq '.text | split(" ")' data.json
```

```nushell
# Nushell
open data.json | get name | str upcase
open data.json | get items | str join ", "
open data.json | get text | split row " "
```

### Complex Transformations

```bash
# jq
jq '[.users[] | {name: .name, email: .email}] | sort_by(.name)' data.json
```

```nushell
# Nushell
open data.json | get users | select name email | sort-by name
```

---

## awk/sed to Nushell

### awk Patterns

```bash
# awk - print columns
awk '{print $1, $3}' file.txt
awk -F: '{print $1}' /etc/passwd
awk 'NR > 1 {print}' file.csv
awk '{sum += $1} END {print sum}' numbers.txt
```

```nushell
# Nushell
open file.txt | split column " " | select column1 column3
open /etc/passwd | split column ":" | get column1
open file.csv | skip 1
open numbers.txt | lines | into int | math sum
```

### sed Patterns

```bash
# sed - substitution
sed 's/old/new/g' file.txt
sed '/pattern/d' file.txt
sed -n '5,10p' file.txt
sed 's/^/prefix: /' file.txt
```

```nushell
# Nushell
open file.txt | str replace --all "old" "new"
open file.txt | lines | where { $in !~ "pattern" }
open file.txt | lines | range 4..9
open file.txt | lines | each { |l| $"prefix: ($l)" }
```

---

## Quick Reference Table

| Task | Bash | Python | jq | Nushell |
|------|------|--------|-----|---------|
| Read file | `cat f` | `open(f).read()` | - | `open f` |
| Parse JSON | `jq '.'` | `json.load(f)` | `jq '.'` | `open f.json` |
| Filter list | `grep p` | `[x for x if p]` | `select(p)` | `where p` |
| Map list | `xargs -I{}` | `map(fn, l)` | `map(.)` | `each { }` |
| Get field | `jq '.x'` | `d['x']` | `.x` | `get x` |
| Sum numbers | `awk '{s+=$1}'` | `sum(l)` | `add` | `math sum` |
| Sort | `sort` | `sorted(l)` | `sort` | `sort` |
| Unique | `sort -u` | `set(l)` | `unique` | `uniq` |
| Count lines | `wc -l` | `len(f.readlines())` | `length` | `lines \| length` |
| HTTP GET | `curl` | `requests.get()` | - | `http get` |
