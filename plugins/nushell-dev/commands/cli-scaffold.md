---
description: Create a new CLI-compliant Nushell script from template
argument-hint: <name> [--type script|command|module] [--description "..."]
allowed-tools: Read, Write, Bash
---

Create a new Nushell file that follows all CLI guidelines from clig.dev.

**Arguments:**
- $1: Name for the new script/command/module
- --type: Type of file (script, command, module). Default: script
- --description: Description for documentation

**Process:**

1. Determine output path based on type and name

2. Read the CLI-compliant template from:
   ${CLAUDE_PLUGIN_ROOT}/skills/cli-guidelines/examples/cli-compliant-script.nu

3. Customize the template:
   - Replace placeholder name with $1
   - Add description if provided
   - Set appropriate shebang
   - Add timestamp and author

4. For modules, create directory structure:
   ```
   name/
   ├── mod.nu
   ├── commands.nu
   └── utils.nu
   ```

5. Write the file(s) with proper permissions

6. Report what was created and next steps

**Template features:**
- Proper documentation comments
- --help, --version, --verbose, --quiet flags
- --json output support
- NO_COLOR handling
- Error handling with try/catch
- Input validation
- Exit codes

**Example:**
`/nushell-dev:cli-scaffold my-tool --description "A tool for processing data"`
