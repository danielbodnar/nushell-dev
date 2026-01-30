# Nushell Testing Guide

Strategies and patterns for testing Nushell code effectively.

## Testing Philosophy

### Why Test Nushell Code?

1. **Catch regressions** - Ensure changes don't break existing functionality
2. **Document behavior** - Tests serve as executable documentation
3. **Enable refactoring** - Safe to improve code with tests in place
4. **Validate edge cases** - Ensure handling of unusual inputs

### What to Test

| Priority | What | Why |
|----------|------|-----|
| High | Public commands | User-facing API |
| High | Data transformations | Core logic |
| Medium | Error handling | User experience |
| Medium | Edge cases | Robustness |
| Low | Internal helpers | May change frequently |

---

## Basic Testing Patterns

### Assertion Helpers

```nushell
# tests/helpers.nu

# Assert equality
export def assert-eq [expected: any, actual: any, msg?: string] {
    if $expected != $actual {
        let message = $msg | default $"Expected ($expected), got ($actual)"
        error make { msg: $"Assertion failed: ($message)" }
    }
}

# Assert not equal
export def assert-ne [a: any, b: any, msg?: string] {
    if $a == $b {
        let message = $msg | default $"Expected ($a) != ($b)"
        error make { msg: $"Assertion failed: ($message)" }
    }
}

# Assert true
export def assert-true [condition: bool, msg?: string] {
    if not $condition {
        let message = $msg | default "Expected true"
        error make { msg: $"Assertion failed: ($message)" }
    }
}

# Assert false
export def assert-false [condition: bool, msg?: string] {
    if $condition {
        let message = $msg | default "Expected false"
        error make { msg: $"Assertion failed: ($message)" }
    }
}

# Assert error is thrown
export def assert-error [action: closure, msg?: string] {
    let threw = try {
        do $action
        false
    } catch {
        true
    }

    if not $threw {
        let message = $msg | default "Expected error to be thrown"
        error make { msg: $"Assertion failed: ($message)" }
    }
}

# Assert error message contains text
export def assert-error-contains [action: closure, expected: string] {
    try {
        do $action
        error make { msg: "Expected error to be thrown" }
    } catch { |err|
        if not ($err.msg | str contains $expected) {
            error make { msg: $"Expected error containing '($expected)', got: ($err.msg)" }
        }
    }
}

# Assert list contains element
export def assert-contains [list: list, element: any, msg?: string] {
    if $element not-in $list {
        let message = $msg | default $"Expected list to contain ($element)"
        error make { msg: $"Assertion failed: ($message)" }
    }
}

# Assert approximately equal (for floats)
export def assert-approx [expected: float, actual: float, epsilon: float = 0.0001] {
    let diff = ($expected - $actual) | math abs
    if $diff > $epsilon {
        error make { msg: $"Expected ($expected) ≈ ($actual) (diff: ($diff))" }
    }
}
```

### Simple Test File

```nushell
# tests/test_math.nu

use ../src/math.nu
use ./helpers.nu *

def "test double" [] {
    assert-eq 4 (math double 2) "double 2"
    assert-eq 0 (math double 0) "double 0"
    assert-eq -4 (math double -2) "double -2"
}

def "test square" [] {
    assert-eq 4 (math square 2)
    assert-eq 9 (math square 3)
    assert-eq 0 (math square 0)
    assert-eq 4 (math square -2) "negative input"
}

def "test divide" [] {
    assert-eq 2 (math divide 10 5)
    assert-approx 3.333 (math divide 10 3)
}

def "test divide by zero" [] {
    assert-error { math divide 10 0 } "divide by zero should error"
}

# Run all tests
export def main [] {
    print "Running math tests..."

    let tests = [
        "test double"
        "test square"
        "test divide"
        "test divide by zero"
    ]

    mut passed = 0
    mut failed = 0

    for test in $tests {
        try {
            do (scope commands | where name == $test | get 0.closure)
            print $"  ✓ ($test)"
            $passed += 1
        } catch { |e|
            print $"  ✗ ($test): ($e.msg)"
            $failed += 1
        }
    }

    print $"\nResults: ($passed) passed, ($failed) failed"

    if $failed > 0 {
        exit 1
    }
}
```

---

## Test Organization

### Directory Structure

```
project/
├── src/
│   ├── main.nu
│   ├── utils.nu
│   └── api.nu
└── tests/
    ├── helpers.nu      # Test utilities
    ├── test_utils.nu   # Tests for utils.nu
    ├── test_api.nu     # Tests for api.nu
    └── run_all.nu      # Test runner
```

### Test Runner

```nushell
# tests/run_all.nu

def main [] {
    print "Running all tests...\n"

    let test_files = ls tests/test_*.nu | get name

    mut total_passed = 0
    mut total_failed = 0

    for file in $test_files {
        print $"=== ($file) ==="
        let result = do { nu $file } | complete

        if $result.exit_code == 0 {
            print $result.stdout
        } else {
            print $result.stdout
            print $result.stderr
            $total_failed += 1
        }
        print ""
    }

    print $"=== Summary ==="
    print $"Test files: ($test_files | length)"
    print $"Failed: ($total_failed)"

    if $total_failed > 0 {
        exit 1
    }
}
```

---

## Testing Patterns

### Testing Pure Functions

```nushell
# Pure functions are easiest to test
def add [a: int, b: int] -> int {
    $a + $b
}

def "test add" [] {
    assert-eq 5 (add 2 3)
    assert-eq 0 (add 0 0)
    assert-eq -3 (add -5 2)
}
```

### Testing Commands with Side Effects

```nushell
# Use temp directories for file tests
def "test save and load" [] {
    let temp_dir = $"($nu.temp-path)/test_(random uuid)"
    mkdir $temp_dir

    try {
        let test_file = [$temp_dir, "test.json"] | path join

        # Test save
        {name: "test", value: 42} | to json | save $test_file

        # Test load
        let loaded = open $test_file
        assert-eq "test" $loaded.name
        assert-eq 42 $loaded.value
    } catch { |e|
        rm -r $temp_dir
        error make { msg: $e.msg }
    }

    rm -r $temp_dir
}
```

### Testing Error Cases

```nushell
def validate-email [email: string] {
    if not ($email | str contains "@") {
        error make { msg: "Invalid email format" }
    }
    $email
}

def "test validate-email valid" [] {
    assert-eq "test@example.com" (validate-email "test@example.com")
}

def "test validate-email invalid" [] {
    assert-error-contains { validate-email "invalid" } "Invalid email"
}
```

### Testing with Fixtures

```nushell
# tests/fixtures.nu

export def sample-users [] {
    [
        {id: 1, name: "Alice", active: true}
        {id: 2, name: "Bob", active: false}
        {id: 3, name: "Carol", active: true}
    ]
}

export def sample-config [] {
    {
        api_url: "https://test.example.com"
        timeout: 30sec
        retries: 3
    }
}

# In test file
use ./fixtures.nu

def "test filter active users" [] {
    let users = fixtures sample-users
    let active = $users | where active == true

    assert-eq 2 ($active | length)
    assert-contains ($active | get name) "Alice"
    assert-contains ($active | get name) "Carol"
}
```

### Testing HTTP/External Dependencies

```nushell
# Mock external calls for testing
def mock-http-get [url: string] {
    # Return mock data based on URL
    match $url {
        "https://api.example.com/users" => {
            [{id: 1, name: "Test User"}]
        }
        "https://api.example.com/status" => {
            {status: "ok", version: "1.0"}
        }
        _ => {
            error make { msg: $"Unknown mock URL: ($url)" }
        }
    }
}

def "test api client" [] {
    # Inject mock
    let users = mock-http-get "https://api.example.com/users"
    assert-eq 1 ($users | length)
    assert-eq "Test User" $users.0.name
}
```

---

## Integration Testing

### End-to-End Script Test

```nushell
# tests/test_integration.nu

def "test full workflow" [] {
    let temp_dir = $"($nu.temp-path)/integration_(random uuid)"
    mkdir $temp_dir

    try {
        # Setup test data
        let input = [$temp_dir, "input.csv"] | path join
        [[name, amount]; ["Alice", 100], ["Bob", 200]] | to csv | save $input

        # Run the script
        let result = do { nu src/process.nu $input } | complete

        assert-eq 0 $result.exit_code "Script should succeed"

        # Verify output
        let output = [$temp_dir, "output.json"] | path join
        assert-true ($output | path exists) "Output file should exist"

        let data = open $output
        assert-eq 2 ($data | length)

    } catch { |e|
        rm -r $temp_dir
        error make { msg: $e.msg }
    }

    rm -r $temp_dir
}
```

### CLI Testing

```nushell
def "test cli help" [] {
    let result = do { nu mytool.nu --help } | complete
    assert-eq 0 $result.exit_code
    assert-true ($result.stdout | str contains "Usage:")
}

def "test cli version" [] {
    let result = do { nu mytool.nu version } | complete
    assert-eq 0 $result.exit_code
    assert-true ($result.stdout | str contains "1.0")
}

def "test cli invalid command" [] {
    let result = do { nu mytool.nu invalid-command } | complete
    assert-ne 0 $result.exit_code
}
```

---

## Property-Based Testing

### Generating Test Data

```nushell
# Generate random test cases
def random-string [length: int = 10] {
    let chars = "abcdefghijklmnopqrstuvwxyz"
    1..$length | each { |_|
        let idx = random int 0..25
        $chars | str substring $idx..($idx + 1)
    } | str join
}

def random-user [] {
    {
        id: (random int 1..10000)
        name: (random-string 8)
        age: (random int 18..80)
        active: (random bool)
    }
}

def "test with random data" [] {
    # Generate many random inputs
    let users = 1..100 | each { |_| random-user }

    # Test invariants
    for user in $users {
        let processed = process-user $user

        # Invariant: ID should be preserved
        assert-eq $user.id $processed.id

        # Invariant: Processed users have computed field
        assert-true ($processed.computed? != null)
    }
}
```

### Roundtrip Testing

```nushell
def "test json roundtrip" [] {
    let original = {
        string: "hello"
        number: 42
        float: 3.14
        list: [1, 2, 3]
        nested: {a: 1, b: 2}
    }

    let roundtripped = $original | to json | from json

    assert-eq $original $roundtripped "JSON roundtrip should preserve data"
}

def "test nuon roundtrip" [] {
    let original = {
        date: (date now)
        duration: 5min
        size: 1gb
    }

    let roundtripped = $original | to nuon | from nuon

    assert-eq $original.duration $roundtripped.duration
    assert-eq $original.size $roundtripped.size
}
```

---

## Test Coverage Considerations

### Critical Paths to Test

1. **Happy path** - Normal successful operation
2. **Edge cases** - Empty inputs, boundary values
3. **Error cases** - Invalid inputs, missing data
4. **Null handling** - Optional fields, missing values

### Test Checklist

```nushell
# For each public command, test:
# □ Normal operation with valid input
# □ Empty input handling
# □ Invalid type input
# □ Boundary values (0, max int, empty string)
# □ Missing optional parameters
# □ Error conditions and messages
# □ Return type is correct
```

---

## Continuous Integration

### CI Script

```nushell
#!/usr/bin/env nu

# ci/test.nu

def main [] {
    print "=== Linting ==="
    let lint_result = do { nu-lint src/ } | complete
    if $lint_result.exit_code != 0 {
        print "Lint failed!"
        exit 1
    }

    print "\n=== Running Tests ==="
    let test_result = do { nu tests/run_all.nu } | complete
    print $test_result.stdout
    if $test_result.exit_code != 0 {
        print "Tests failed!"
        exit 1
    }

    print "\n=== All checks passed ==="
}
```

### GitHub Actions

```yaml
# .github/workflows/test.yml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hustcer/setup-nu@v3
      - run: nu ci/test.nu
```
