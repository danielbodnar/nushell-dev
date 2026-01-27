# {{NAME}} - Nushell Plugin

{{DESCRIPTION}}

## Overview

This is a Nushell plugin written in Rust. Nushell plugins extend the shell with custom commands that run as external processes.

## Prerequisites

- Rust toolchain (rustup)
- Nushell 0.90.0 or later
- `nu-plugin` crate

## Project Structure

```
{{NAME}}/
├── Cargo.toml          # Rust project configuration
├── src/
│   ├── main.rs         # Plugin entry point
│   └── commands/       # Command implementations
│       └── mod.rs
├── README.md           # This file
└── .gitignore
```

## Getting Started

### 1. Create Cargo.toml

```toml
[package]
name = "nu_plugin_{{NAME}}"
version = "0.1.0"
edition = "2021"

[dependencies]
nu-plugin = "0.90"
nu-protocol = "0.90"

[[bin]]
name = "nu_plugin_{{NAME}}"
path = "src/main.rs"
```

### 2. Create src/main.rs

```rust
use nu_plugin::{serve_plugin, MsgPackSerializer};
use nu_plugin::{Plugin, PluginCommand, SimplePluginCommand};
use nu_protocol::{Category, LabeledError, Signature, Value};

struct {{NamePascal}}Plugin;

impl Plugin for {{NamePascal}}Plugin {
    fn commands(&self) -> Vec<Box<dyn PluginCommand<Plugin = Self>>> {
        vec![Box::new({{NamePascal}}Command)]
    }
}

struct {{NamePascal}}Command;

impl SimplePluginCommand for {{NamePascal}}Command {
    type Plugin = {{NamePascal}}Plugin;

    fn name(&self) -> &str {
        "{{NAME}}"
    }

    fn usage(&self) -> &str {
        "{{DESCRIPTION}}"
    }

    fn signature(&self) -> Signature {
        Signature::build(self.name())
            .category(Category::Experimental)
    }

    fn run(
        &self,
        _plugin: &{{NamePascal}}Plugin,
        _engine: &nu_plugin::EngineInterface,
        call: &nu_plugin::EvaluatedCall,
        _input: &Value,
    ) -> Result<Value, LabeledError> {
        // TODO: Implement your command logic here
        Ok(Value::string("Hello from {{NAME}} plugin!", call.head))
    }
}

fn main() {
    serve_plugin(&{{NamePascal}}Plugin, MsgPackSerializer);
}
```

### 3. Build the Plugin

```bash
cargo build --release
```

### 4. Register with Nushell

```nushell
plugin add ./target/release/nu_plugin_{{NAME}}
plugin use {{NAME}}
```

### 5. Test

```nushell
{{NAME}}
# Should output: Hello from {{NAME}} plugin!
```

## Development

### Adding Commands

1. Create new command struct
2. Implement `SimplePluginCommand` or `PluginCommand` trait
3. Register in `Plugin::commands()`

### Handling Input

```rust
fn run(
    &self,
    _plugin: &{{NamePascal}}Plugin,
    _engine: &nu_plugin::EngineInterface,
    call: &nu_plugin::EvaluatedCall,
    input: &Value,
) -> Result<Value, LabeledError> {
    // Access positional arguments
    let arg: String = call.req(0)?;

    // Access flags
    let verbose: bool = call.has_flag("verbose")?;

    // Process pipeline input
    match input {
        Value::String { val, .. } => {
            // Handle string input
        }
        Value::List { vals, .. } => {
            // Handle list input
        }
        _ => {}
    }

    Ok(Value::nothing(call.head))
}
```

### Returning Structured Data

```rust
// Return a record
let record = Value::record(
    vec!["name", "value"],
    vec![
        Value::string("example", span),
        Value::int(42, span),
    ],
    span,
);

// Return a list
let list = Value::list(
    vec![item1, item2, item3],
    span,
);
```

## Resources

- [Nushell Plugin Documentation](https://www.nushell.sh/book/plugins.html)
- [nu-plugin crate docs](https://docs.rs/nu-plugin)
- [nu-protocol crate docs](https://docs.rs/nu-protocol)
- [Example plugins](https://github.com/nushell/nushell/tree/main/crates/nu_plugin_example)

## License

{{LICENSE}}
