---
description: Convert code from other languages to Nushell
argument-hint: [source-file] [--from lang] [--output file]
allowed-tools: Read, Write
---

Convert scripts from other languages to idiomatic Nushell.

**Arguments:**
- $1: Source file to convert
- --from: Source language (auto-detected if not specified)
- --output: Output file (default: source with .nu extension)

**Supported source languages:**
- bash, sh, zsh (shell scripts)
- fish (fish shell)
- python (simple scripts)
- javascript, js (Node.js scripts)
- jq (jq filters)
- awk (awk programs)
- sed (sed commands)

**Process:**

1. Read the source file: @$1

2. Detect source language if not specified:
   - Check shebang line
   - Check file extension
   - Analyze syntax patterns

3. Apply language-specific conversion rules:

### Shell (bash/sh/zsh) Conversions:

| Bash | Nushell |
|------|---------|
| `$VAR` | `$var` or `$env.VAR` |
| `$(command)` | `(command)` |
| `if [ ]; then fi` | `if condition { }` |
| `for i in ...; do done` | `for i in ... { }` |
| `[[ -f file ]]` | `($file \| path exists)` |
| `grep pattern` | `where ($it \| str contains pattern)` |
| `awk '{print $1}'` | `split row ' ' \| get 0` |
| `sed 's/old/new/'` | `str replace 'old' 'new'` |
| `cat file \| cmd` | `open file \| cmd` |
| `echo "text"` | `print "text"` or `"text"` |
| `export VAR=val` | `$env.VAR = val` |
| `\`command\`` | `(command)` |

### Python Conversions:

| Python | Nushell |
|--------|---------|
| `for x in list:` | `for x in $list { }` |
| `if x:` | `if $x { }` |
| `def func(a, b):` | `def func [a, b] { }` |
| `dict['key']` | `$record.key` |
| `list.append(x)` | `$list ++ [$x]` |
| `with open(f) as f:` | `open $f` |
| `json.loads(s)` | `$s \| from json` |
| `f"string {var}"` | `$"string ($var)"` |

### JavaScript Conversions:

| JavaScript | Nushell |
|------------|---------|
| `const x = ...` | `let x = ...` |
| `let x = ...` | `mut x = ...` |
| `arr.map(x => ...)` | `$arr \| each {\|x\| ... }` |
| `arr.filter(x => ...)` | `$arr \| where { ... }` |
| `arr.reduce(...)` | `$arr \| reduce { ... }` |
| `obj.key` | `$obj.key` |
| `async/await` | (explain Nushell is sync) |
| `console.log()` | `print` |

### jq Conversions:

| jq | Nushell |
|----|---------|
| `.key` | `get key` |
| `.[]` | `each { }` |
| `select(.x > 1)` | `where x > 1` |
| `map(.x)` | `each {\|r\| $r.x }` |
| `keys` | `columns` |
| `length` | `length` |
| `@csv` | `to csv` |

### awk Conversions:

| awk | Nushell |
|-----|---------|
| `$1, $2` | `split row ' ' \| get 0 1` |
| `NR` | Line number via enumerate |
| `NF` | `split \| length` |
| `BEGIN {}` | Code before pipeline |
| `END {}` | Code after pipeline |
| `/pattern/` | `where ($it \| str contains pattern)` |

### sed Conversions:

| sed | Nushell |
|-----|---------|
| `s/old/new/` | `str replace 'old' 'new'` |
| `s/old/new/g` | `str replace --all 'old' 'new'` |
| `/pattern/d` | `where not ($it \| str contains pattern)` |
| `1,5p` | `first 5` |
| `$p` | `last` |

4. Generate idiomatic Nushell:
   - Use proper type annotations
   - Leverage structured data instead of text parsing
   - Use native Nushell commands where possible
   - Add comments explaining non-obvious conversions
   - Handle edge cases and errors properly

5. Add warnings for:
   - Features that don't translate directly
   - Async/concurrent patterns
   - Complex regex that needs adjustment
   - External tool dependencies

6. Output the converted code with:
   - Original code as comments (optional)
   - Explanatory comments for complex conversions
   - TODO markers for manual review needed

**Example conversion (bash to nu):**

```bash
#!/bin/bash
# Original: fetch-users.sh
for user in $(cat users.txt); do
  result=$(curl -s "https://api.example.com/users/$user")
  echo "$result" | jq '.name'
done
```

```nushell
#!/usr/bin/env nu
# Converted from: fetch-users.sh
open users.txt
| lines
| each { |user|
    http get $"https://api.example.com/users/($user)"
    | get name
}
```
