---
description: Audit a Nushell script against CLI guidelines from clig.dev
argument-hint: <file.nu> [--strict] [--fix]
allowed-tools: Read, Write, Bash
---

Audit a Nushell file for CLI guidelines compliance.

**Arguments:**
- $1: Path to .nu file to check
- --strict: Treat warnings as errors
- --fix: Auto-fix formatting issues

**Process:**

1. Validate the file exists and is a .nu file

2. Run all validation checks:
   - Syntax: nu-check --debug
   - Lint: nu-lint (if available)
   - Format: nufmt --check (if available)
   - IDE: nu --ide-check

3. Check CLI-specific guidelines:
   - Help documentation present
   - Standard flag names used
   - Type annotations on exports
   - Error handling present
   - Output formatting appropriate

4. Generate compliance report:
   - List all violations by severity
   - Show line numbers and code snippets
   - Provide fix suggestions
   - Calculate compliance score

5. If --fix, run auto-fixes:
   - nufmt for formatting
   - Suggest manual fixes for others

**Example output:**

```
CLI Guidelines Compliance Report: script.nu
═══════════════════════════════════════════

✗ ERRORS (2)
  Line 15: [ARG-006] Secret passed via flag --api-key
  Line 42: [ERR-001] Unhandled error in try block

⚠ WARNINGS (3)
  Line 8:  [HELP-003] No example in documentation
  Line 23: [ARG-003] Missing long form for -v flag
  Line 56: [OUT-003] Color output without NO_COLOR check

ℹ INFO (1)
  Line 1:  [STY-FORMAT] Formatting differs from nufmt

Score: 65/100 (Needs Improvement)

Run '/nushell-dev:cli-check script.nu --fix' to auto-fix formatting.
```
