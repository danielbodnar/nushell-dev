# Nushell Marketplace

A curated collection of Claude Code plugins for Nushell development, shell scripting, and data processing.

## Structure

- **`/plugins`** - Plugins developed and maintained in this marketplace

## Available Plugins

| Plugin | Description | Category |
|--------|-------------|----------|
| [nushell-dev](./plugins/nushell-dev) | Comprehensive toolkit for Nushell development with skills, commands, agents, and hooks | development |

## Installation

### Add the Marketplace

```bash
# From GitHub
/plugin marketplace add danielbodnar/nushell-dev

# From local path (for development)
/plugin marketplace add ~/.claude/plugins/nushell-dev
```

### Install Plugins

Once the marketplace is added, install individual plugins:

```bash
/plugin install nushell-dev@nushell-marketplace
```

Or browse available plugins:

```bash
/plugin > Discover
```

## Plugin Structure

Each plugin follows the standard Claude Code plugin structure:

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json      # Plugin metadata (required)
├── skills/              # Auto-activating skills
├── commands/            # Slash commands
├── agents/              # Agent definitions
├── hooks/               # Event handlers
└── README.md            # Documentation
```

## Development

### Testing Plugins Locally

Test a specific plugin in isolation:

```bash
claude --plugin-dir ./plugins/nushell-dev
```

### Validating the Marketplace

```bash
claude plugin validate .
```

Or from within Claude Code:

```bash
/plugin validate .
```

## Contributing

### Adding a New Plugin

1. Create a plugin directory under `/plugins/`
2. Add the required `.claude-plugin/plugin.json` manifest
3. Add your skills, commands, agents, or hooks
4. Update the marketplace.json to include your plugin
5. Test locally with `claude --plugin-dir`
6. Submit a pull request

### Plugin Guidelines

- Follow [Claude Code plugin best practices](https://code.claude.com/docs/en/plugins)
- Include comprehensive documentation
- Add meaningful descriptions for discovery
- Test all components before submitting

## Documentation

For more information on developing Claude Code plugins, see:
- [Create plugins](https://code.claude.com/docs/en/plugins)
- [Plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference)

## Author

**Daniel Bodnar**
- GitHub: [@danielbodnar](https://github.com/danielbodnar)
- Email: daniel.bodnar@gmail.com

## License

MIT License - See [LICENSE](./LICENSE) file for details.
