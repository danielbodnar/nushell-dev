---
description: Create or run tests for Nushell code
argument-hint: [action] [target] [--coverage]
allowed-tools: Read, Write, Bash
---

Create or run tests for Nushell code.

**Arguments:**
- $1: Action - create, run, or watch
- $2: Target file or test directory
- --coverage: Generate coverage report (when running)

**Actions:**

### create - Generate test file

If $1 is "create":

1. Read the target source file: @$2

2. Analyze exported functions and their signatures

3. Generate test file with:
   - Import statement for the module
   - Test function for each exported command
   - Assertion helpers
   - Test runner function

4. Create test file at `tests/test_[module-name].nu`:

```nushell
# tests/test_utils.nu - Generated tests for utils.nu
use ../src/utils.nu

# Assertion helpers
def assert-eq [expected: any, actual: any, message?: string] {
    if $expected != $actual {
        error make { msg: ($message | default $"Expected ($expected), got ($actual)") }
    }
}

def assert [condition: bool, message?: string] {
    if not $condition {
        error make { msg: ($message | default "Assertion failed") }
    }
}

# Tests for each exported function
def "test function-name" [] {
    # TODO: Add test cases
    let result = function-name args
    assert-eq expected $result "function-name should return expected"
}

# Test runner
def "test all" [] {
    test function-name
    # Add more tests...
    print "✅ All tests passed"
}
```

### run - Execute tests

If $1 is "run":

1. Find test files:
   - If $2 specified: run that test file
   - Otherwise: find all test_*.nu files in tests/

2. Execute each test file:
   !`nu $test_file`

3. Collect results and report:
   ```
   Running tests...
   ✅ tests/test_utils.nu - 5 passed
   ❌ tests/test_api.nu - 3 passed, 1 failed
      - test fetch-data: Expected 200, got 404

   Summary: 8 passed, 1 failed
   ```

4. If --coverage: analyze which functions were tested

### watch - Continuous testing

If $1 is "watch":

Explain that continuous testing requires external tools like:
- `watchexec -e nu -- nu tests/test_all.nu`
- Custom file watcher script

Provide a simple watcher script if requested.

**Test patterns:**

Reference the nushell-tooling skill for testing patterns:
${CLAUDE_PLUGIN_ROOT}/skills/nushell-tooling/SKILL.md

**Generated test structure:**
- One test function per exported command
- Test both success and error cases
- Include edge cases (empty input, nulls, etc.)
- Test type conversions and validations
