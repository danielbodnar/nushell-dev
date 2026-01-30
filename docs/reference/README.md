# Nushell Reference Documentation

Comprehensive reference documentation for Nushell language features and APIs.

## Reference Files

| File | Description |
|------|-------------|
| [types.md](./types.md) | Complete type system reference |
| [operators.md](./operators.md) | All operators and their precedence |
| [configuration.md](./configuration.md) | `$env.config` settings reference |
| [commands.md](./commands.md) | Built-in command categories |
| [errors.md](./errors.md) | Error types and handling |

---

## Quick Type Reference

| Type | Example | Description |
|------|---------|-------------|
| `int` | `42`, `-17`, `0xff` | 64-bit signed integer |
| `float` | `3.14`, `1e-5` | 64-bit float |
| `string` | `"hello"`, `'world'` | UTF-8 string |
| `bool` | `true`, `false` | Boolean |
| `duration` | `5min`, `2hr` | Time duration |
| `filesize` | `10kb`, `1gb` | File size |
| `date` | `2024-01-15` | Datetime |
| `nothing` | `null` | Null value |
| `list` | `[1, 2, 3]` | Ordered list |
| `record` | `{a: 1, b: 2}` | Key-value record |
| `table` | `[[a]; [1]]` | List of records |
| `closure` | `{\|x\| $x}` | Anonymous function |
| `binary` | `0x[FF 00]` | Raw bytes |
| `range` | `1..10` | Numeric range |

---

## Quick Operator Reference

| Category | Operators |
|----------|-----------|
| Arithmetic | `+`, `-`, `*`, `/`, `//`, `mod`, `**` |
| Comparison | `==`, `!=`, `<`, `>`, `<=`, `>=` |
| Logical | `and`, `or`, `not`, `xor` |
| String | `=~`, `!~`, `++`, `in`, `not-in` |
| Pipeline | `\|`, `\|>`, `o>`, `e>`, `o+e>` |
| Assignment | `=`, `+=`, `-=`, `*=`, `/=`, `++=` |

---

## Command Categories

| Category | Examples |
|----------|----------|
| **Filesystem** | `ls`, `cd`, `cp`, `mv`, `rm`, `mkdir`, `open`, `save` |
| **Strings** | `str join`, `str split`, `str replace`, `str trim` |
| **Lists** | `each`, `where`, `select`, `first`, `last`, `flatten` |
| **Math** | `math sum`, `math avg`, `math round` |
| **Dates** | `date now`, `date to-record`, `format date` |
| **HTTP** | `http get`, `http post`, `http put`, `http delete` |
| **Formats** | `from json`, `to json`, `from csv`, `to csv` |
| **System** | `ps`, `sys`, `which`, `exec` |

---

## Related Resources

- [Snippets](../snippets/) - Copy-paste code examples
- [Guides](../guides/) - Step-by-step tutorials
- [Nushell Book](https://www.nushell.sh/book/) - Official documentation
