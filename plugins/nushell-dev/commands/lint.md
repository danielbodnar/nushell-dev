---
description: Lint Nushell code and suggest fixes
argument-hint: [file-or-dir] [--fix] [--strict]
allowed-tools: Read, Write, Edit, Bash
---

Lint Nushell code for errors, warnings, and style issues.

**Arguments:**
- $1: File or directory to lint (default: current directory)
- --fix: Automatically fix issues where possible
- --strict: Treat warnings as errors

**Process:**

1. Determine target files:
   - If $1 is a file: lint that file
   - If $1 is a directory: find all .nu files recursively
   - If no argument: lint current directory

2. Run syntax validation:
   !`nu --commands "source '$1'" 2>&1`

   Note: Nushell doesn't have a standalone `nu-check` command.
   Use `nu --commands "source ..."` for syntax validation.

3. If nu-lint is available, run additional checks:
   !`nu-lint check $1 2>&1`

4. Analyze results and categorize issues:
   - **Errors**: Syntax errors, undefined variables, type mismatches
   - **Warnings**: Unused variables, deprecated commands, shadow variables
   - **Style**: Naming conventions, documentation, formatting

5. For each issue found:
   - Show file path and line number
   - Explain the issue clearly
   - Provide specific fix recommendation
   - If --fix is provided and fix is safe, apply automatically

6. Report summary:
   ```
   Linting complete:
   ✅ X files passed
   ❌ X files with errors
   ⚠️  X files with warnings

   Issues found:
   - file.nu:10 - Error: undefined variable $foo
   - file.nu:25 - Warning: unused variable $bar
   ```

**Common issues to check:**

| Issue | Description | Fix |
|-------|-------------|-----|
| Undefined variable | Variable used before definition | Define or check spelling |
| Type mismatch | Wrong type in operation | Add type conversion |
| Unused variable | Defined but never used | Remove or prefix with _ |
| Shadow variable | Redefined in same scope | Rename one instance |
| Missing parameter | Required param not provided | Add parameter or default |
| Deprecated command | Using old command name | Use new command |
| Missing type annotation | Export without types | Add type annotations |

**Style checks:**
- Command names should be kebab-case
- Variables should be snake_case
- Exported commands should have documentation
- Line length should be reasonable (< 120 chars)

If using the nushell-tooling skill, leverage its validation patterns.
Reference: ${CLAUDE_PLUGIN_ROOT}/skills/nushell-tooling/SKILL.md
