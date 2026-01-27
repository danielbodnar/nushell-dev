# nushell-dev

A comprehensive Claude Code plugin for professional Nushell development. Provides skills, commands, agents, and hooks for architecting robust, well-documented Nushell scripts, commands, modules, overlays, and pipelines.

## Features

### Skills (Auto-activating Knowledge)

| Skill | Description |
|-------|-------------|
| `nushell-fundamentals` | Core language patterns: pipelines, closures, types, modules, overlays |
| `nushell-data-processing` | Polars, DataFrames, LazyFrames, structured data manipulation |
| `nushell-http-api` | HTTP commands, API integration, webhooks, request/response handling |
| `nushell-storage` | stor, SQLite queries, parquet, CSV/JSON file handling |
| `nushell-cloudflare` | Workers, R2, Queues, Workflows, Durable Objects + wrangler integration |
| `nushell-tooling` | LSP, MCP server, linting, testing, documentation generation |

### Commands (User-initiated Actions)

| Command | Description |
|---------|-------------|
| `/nu:new` | Scaffold new script, module, command, overlay, plugin, or test |
| `/nu:lint` | Run linting and suggest fixes |
| `/nu:docs` | Generate documentation from code |
| `/nu:test` | Create or run tests for Nushell code |
| `/nu:convert` | Convert from bash, Python, JS, jq, awk, sed to Nushell |

### Agents (Autonomous Tasks)

| Agent | Description |
|-------|-------------|
| `nushell-code-reviewer` | Review .nu files for best practices, performance, idiomatic patterns |
| `nushell-generator` | Generate complete Nushell scripts from natural language (MCP-validated) |
| `nushell-refactorer` | Modernize and optimize existing Nushell code |

### Hooks (Automatic Validation)

- **PreToolUse**: Validates syntax before writing .nu files (strict mode - blocks on warnings)
- **PostToolUse**: Auto-formats .nu files after writes using Nushell official style

## Installation

### Already Installed
This plugin is already installed at `~/.claude/plugins/nushell-dev/`.
It should be auto-discovered by Claude Code.

### Manual Installation
```bash
# Clone or copy to your plugins directory
git clone https://github.com/danielbodnar/nushell-dev ~/.claude/plugins/nushell-dev
```

### Test in Isolation
```bash
# Run Claude Code with only this plugin
cc --plugin-dir ~/.claude/plugins/nushell-dev
```

## Prerequisites

- **Nushell 0.100+** with LSP support
- **nu-lint** for linting (optional but recommended)
- **Polars plugin** for data processing features
- **Cloudflare wrangler** for Workers integration

### Recommended Nushell Plugins

```bash
# Install via cargo or plugin add
plugin add polars
plugin add formats  # parquet support
plugin add query    # SQL-like queries
```

## Configuration

Create `~/.claude/nushell-dev.local.md` to customize behavior:

```markdown
# Nushell Dev Settings

## Code Style
- indent: 4 spaces
- line_length: 100
- trailing_newline: true

## Linting
- strictness: high
- auto_fix: true

## Templates
- default_author: Your Name
- default_license: MIT
```

## Usage Examples

### Generate a New Module

```
/nu:new module --name data-utils --description "Data transformation utilities"
```

### Convert Bash Script

```
/nu:convert ./legacy-script.sh
```

### Review Code Quality

Ask Claude: "Review my Nushell module for best practices and performance"

### Generate from Description

Ask Claude: "Create a Nushell command that fetches GitHub stars and saves them to parquet"

## Integration with nu --mcp

This plugin leverages the Nushell MCP server for:
- **Code validation**: Generated code is checked via `nu-check`
- **Live evaluation**: Test snippets directly through MCP
- **Command discovery**: Access to `list_commands` and `command_help`

Ensure your MCP configuration includes:

```json
{
  "mcpServers": {
    "nushell": {
      "command": "nu",
      "args": ["--mcp"]
    }
  }
}
```

## Directory Structure

```
nushell-dev/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── skills/                   # Auto-activating knowledge
│   ├── nushell-fundamentals/
│   ├── nushell-data-processing/
│   ├── nushell-http-api/
│   ├── nushell-storage/
│   ├── nushell-cloudflare/
│   └── nushell-tooling/
├── commands/                 # Slash commands
│   ├── new.md
│   ├── lint.md
│   ├── docs.md
│   ├── test.md
│   └── convert.md
├── agents/                   # Autonomous agents
│   ├── code-reviewer.md
│   ├── generator.md
│   └── refactorer.md
├── hooks/                    # Event handlers
│   ├── hooks.json
│   └── scripts/
├── templates/                # Scaffolding templates
│   ├── script/
│   ├── command/
│   ├── module/
│   ├── overlay/
│   ├── plugin/
│   ├── test/
│   └── config/
└── README.md
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run validation: `cc --plugin-dir . --validate`
5. Submit a pull request

## License

MIT License - See LICENSE file for details.

## Related Projects

- [Nushell](https://nushell.sh) - The shell itself
- [nu_scripts](https://github.com/nushell/nu_scripts) - Community scripts
- [nupm](https://github.com/nushell/nupm) - Package manager
