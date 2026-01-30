# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Claude Code plugin marketplace** containing the `nushell-dev` plugin - a comprehensive toolkit for professional Nushell development. The plugin provides skills, commands, agents, hooks, and templates for building robust, well-documented Nushell scripts, commands, modules, overlays, and pipelines.

## Repository Structure

```
nushell-dev/                          # Marketplace root
├── .claude-plugin/marketplace.json   # Marketplace manifest
├── plugins/nushell-dev/              # Main plugin
│   ├── .claude-plugin/plugin.json    # Plugin manifest
│   ├── skills/                       # Auto-activating knowledge domains
│   ├── commands/                     # Slash commands (/nushell-dev:*)
│   ├── agents/                       # Autonomous task agents
│   ├── hooks/                        # PreToolUse/PostToolUse validation
│   │   ├── hooks.json                # Hook configuration
│   │   └── scripts/                  # Nushell validation scripts
│   └── templates/                    # Scaffolding templates
```

## Plugin Validation & Testing

```bash
# Test plugin in isolation
claude --plugin-dir ./plugins/nushell-dev

# Validate marketplace structure
claude plugin validate .

# From within Claude Code
/plugin validate .
```

## Hook System Architecture

The plugin enforces strict Nushell code quality through hooks:

### PreToolUse (pre-write-validate.nu)
Runs BEFORE .nu files are written. Blocks writes that fail:
- **Syntax validation** via `nu --commands "source ..."`
- **Type annotations** on all export def functions
- **Documentation** comments on all exports
- **CLI guidelines** enforcement (--help flags, no hardcoded secrets)

### PostToolUse (post-write-validate.nu)
Runs AFTER .nu files are written. Orchestrates multiple validators in parallel:
- syntax-check.nu → IDE diagnostics via `nu --ide-check`
- lint-check.nu → nu-lint integration (if available)
- format-check.nu → nufmt formatting (if available)
- aggregate-report.nu → Combines results into unified report

### Hook Response Format
Hooks communicate via JSON:
- Approve: `{"action": "approve"}` + exit 0
- Deny: `{"action": "deny", "message": "..."}` + exit 2
- PostToolUse feedback: `{"systemMessage": "..."}` + exit 2

## Key Code Patterns

### Validation Script Structure
```nushell
#!/usr/bin/env nu
# Read JSON from stdin
let input = $in | from json
let file_path = $input.tool_input?.file_path?

# Skip non-.nu files early
if not ($file_path | str ends-with ".nu") { exit 0 }

# Validation logic...

# Return result
{action: "approve"} | to json | print
exit 0
```

### Aggregate Report Module
The `aggregate-report.nu` exports reusable utilities:
```nushell
use aggregate-report.nu [aggregate, make-result, make-error]

# Create validation result
make-result "my-validator" $errors $warnings --file $path

# Create error record
make-error 10 "Missing type" --severity "critical" --fix "Add -> type"

# Aggregate multiple validator results
aggregate $results  # Returns: {passed, critical, warnings, style, summary}
```

## Skills Reference

| Skill | Domain |
|-------|--------|
| nushell-fundamentals | Pipelines, closures, types, modules, overlays |
| nushell-data-processing | Polars, DataFrames, structured data |
| nushell-http-api | HTTP commands, webhooks, API integration |
| nushell-storage | stor, SQLite, parquet, CSV/JSON |
| nushell-cloudflare | Workers, R2, Queues, wrangler |
| nushell-tooling | LSP, MCP server, linting, testing |
| cli-guidelines | clig.dev principles for CLI design |

## CLI Guidelines Enforcement

The plugin enforces CLI best practices from clig.dev:

**Required for export def:**
- Return type annotation: `export def name [] -> string {`
- Parameter type annotations: `[arg: type]`
- Documentation comment above function
- --help flag for main commands

**Severity levels:**
- `critical` → Blocks write (missing types)
- `required` → Blocks write (missing docs)
- `warning` → Allows write with feedback

## Template Variables

When creating templates, use these placeholders:
- `{{NAME}}` - Script/command name
- `{{DESCRIPTION}}` - Brief description
- `{{DETAILED_DESCRIPTION}}` - Full documentation
- `{{AUTHOR}}` - Author name
- `{{DATE}}` - Creation date

## MCP Integration

The plugin leverages Nushell's MCP server for validation:
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

Available MCP tools: `evaluate`, `command_help`, `list_commands`

## Development Dependencies

- **Required:** Nushell 0.100+
- **Recommended:** nu-lint, nufmt
- **Optional:** polars plugin, formats plugin (parquet), query plugin

## Agent Capabilities

| Agent | Purpose | Tools |
|-------|---------|-------|
| generator | Create Nushell code from descriptions | Read, Write, Bash, Grep, Glob |
| code-reviewer | Review .nu files for best practices | Read, Grep, Glob |
| refactorer | Modernize existing Nushell code | Read, Write, Edit |
