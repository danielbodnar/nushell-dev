---
description: Generate documentation from Nushell code
argument-hint: [source] [--output dir] [--format md|json]
allowed-tools: Read, Write, Bash
---

Generate comprehensive documentation from Nushell source files.

**Arguments:**
- $1: Source file or directory to document
- --output: Output directory (default: ./docs)
- --format: Output format - md (markdown) or json

**Process:**

1. Identify files to document:
   - If $1 is a file: document that file
   - If $1 is a directory: find all .nu files with exports

2. For each file, extract documentation:
   - Parse comment blocks above `def` and `export def`
   - Extract parameter comments from signatures
   - Identify return type annotations
   - Find inline examples in comments

3. Parse function signatures:
   ```nushell
   # Extract from:
   # Description of the command
   #
   # Examples:
   #   process-data input.json
   export def process-data [
       input: path      # Input file path
       --format: string # Output format
   ] -> table {
   ```

4. Generate documentation structure:
   ```markdown
   # module-name

   ## Commands

   ### `process-data`

   Description of the command

   **Parameters:**
   | Name | Type | Description |
   |------|------|-------------|
   | input | path | Input file path |
   | --format | string | Output format |

   **Returns:** table

   **Examples:**
   ```nushell
   process-data input.json
   ```
   ```

5. For modules, document:
   - Module overview from top-level comments
   - Exported commands
   - Exported constants
   - Re-exports from submodules
   - Usage patterns

6. Create index file listing all documented modules/commands.

7. Report what was generated:
   ```
   Documentation generated:
   - docs/module-name.md (5 commands)
   - docs/utils.md (3 commands)
   - docs/index.md (summary)
   ```

**Documentation best practices:**
- Include description for every exported command
- Add parameter comments in signatures
- Provide at least one example per command
- Document return types
- Note any side effects

**Using with nushell-fundamentals skill:**
The skill provides patterns for well-documented commands.
Reference: ${CLAUDE_PLUGIN_ROOT}/skills/nushell-fundamentals/SKILL.md
