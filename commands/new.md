---
description: Scaffold new Nushell script, module, command, overlay, plugin, test, or config
argument-hint: [type] [name] [--description "..."]
allowed-tools: Read, Write, Bash
---

Scaffold a new Nushell file based on the requested type.

**Arguments:**
- $1: Type (script, command, module, overlay, plugin, test, config)
- $2: Name for the new file/module
- $3+: Optional description or additional options

**Template locations:**
${CLAUDE_PLUGIN_ROOT}/templates/

**Process:**

1. Determine the type from $1:
   - `script` → Standalone executable script with main function
   - `command` → Exportable custom command definition
   - `module` → Full module structure with mod.nu
   - `overlay` → Overlay environment configuration
   - `plugin` → Plugin boilerplate (Rust-based)
   - `test` → Test file with assertions
   - `config` → Configuration snippet for config.nu

2. Read the appropriate template:
   - script: @${CLAUDE_PLUGIN_ROOT}/templates/script/template.nu
   - command: @${CLAUDE_PLUGIN_ROOT}/templates/command/template.nu
   - module: @${CLAUDE_PLUGIN_ROOT}/templates/module/mod.nu
   - overlay: @${CLAUDE_PLUGIN_ROOT}/templates/overlay/template.nu
   - plugin: @${CLAUDE_PLUGIN_ROOT}/templates/plugin/README.md
   - test: @${CLAUDE_PLUGIN_ROOT}/templates/test/template.nu
   - config: @${CLAUDE_PLUGIN_ROOT}/templates/config/template.nu

3. Customize the template:
   - Replace placeholder names with $2
   - Add description from $3 if provided
   - Update timestamps and author info
   - Set appropriate permissions for scripts

4. Create the file(s):
   - For modules: create directory structure
   - For scripts: make executable
   - For tests: place in tests/ directory

5. Report what was created and suggest next steps.

**Example outputs:**

For `/nu:new script fetch-data`:
Create `fetch-data.nu` with main function, argument parsing, and documentation.

For `/nu:new module utils`:
Create `utils/` directory with `mod.nu` and example exports.

For `/nu:new command process-json`:
Create `process-json.nu` with export def and proper type annotations.

If type is not recognized, list available types and show usage examples.
