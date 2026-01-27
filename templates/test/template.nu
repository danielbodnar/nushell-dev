# tests/test_{{NAME}}.nu - Tests for {{NAME}}
#
# Run with: nu tests/test_{{NAME}}.nu
#
# Author: {{AUTHOR}}
# Created: {{DATE}}

# Import the module being tested
use ../src/{{NAME}}.nu

# ============================================================================
# Assertion Helpers
# ============================================================================

# Assert two values are equal
def assert-eq [expected: any, actual: any, message?: string] {
    if $expected != $actual {
        let msg = $message | default $"Expected ($expected | to nuon), got ($actual | to nuon)"
        error make { msg: $"❌ FAIL: ($msg)" }
    }
}

# Assert condition is true
def assert [condition: bool, message?: string] {
    if not $condition {
        error make { msg: $"❌ FAIL: ($message | default 'Assertion failed')" }
    }
}

# Assert value is not null
def assert-not-null [value: any, message?: string] {
    if $value == null {
        error make { msg: $"❌ FAIL: ($message | default 'Expected non-null value')" }
    }
}

# Assert closure throws an error
def assert-throws [closure: closure, message?: string] {
    try {
        do $closure
        error make { msg: $"❌ FAIL: ($message | default 'Expected exception, but none thrown')" }
    } catch {
        # Expected - test passes
    }
}

# Assert string contains substring
def assert-contains [haystack: string, needle: string, message?: string] {
    if not ($haystack | str contains $needle) {
        let msg = $message | default $"Expected '($haystack)' to contain '($needle)'"
        error make { msg: $"❌ FAIL: ($msg)" }
    }
}

# ============================================================================
# Test Cases
# ============================================================================

# Test basic functionality
def "test basic" [] {
    # TODO: Add test cases
    let result = {{NAME}} primary-command "test-input"
    assert-not-null $result "primary-command should return a value"
}

# Test with different inputs
def "test inputs" [] {
    # Test with string input
    let str_result = {{NAME}} primary-command "string"
    assert-eq "string" $str_result.input "Should preserve input"

    # Test with empty input
    let empty_result = {{NAME}} primary-command ""
    assert-eq "" $empty_result.input "Should handle empty input"
}

# Test error handling
def "test errors" [] {
    # Test that invalid input throws
    # assert-throws { {{NAME}} invalid-command } "Should throw on invalid command"
    print "TODO: Add error handling tests"
}

# Test edge cases
def "test edge-cases" [] {
    # TODO: Test boundary conditions
    # - Very large inputs
    # - Special characters
    # - Unicode
    # - Null values
    print "TODO: Add edge case tests"
}

# ============================================================================
# Test Runner
# ============================================================================

# Run all tests
def "test all" [] {
    let tests = [
        "basic"
        "inputs"
        "errors"
        "edge-cases"
    ]

    mut passed = 0
    mut failed = 0

    print "Running tests for {{NAME}}...\n"

    for test_name in $tests {
        print -n $"  test ($test_name)... "
        try {
            match $test_name {
                "basic" => { test basic }
                "inputs" => { test inputs }
                "errors" => { test errors }
                "edge-cases" => { test edge-cases }
            }
            print "✅ PASS"
            $passed = $passed + 1
        } catch { |err|
            print $"($err.msg)"
            $failed = $failed + 1
        }
    }

    print $"\n($passed) passed, ($failed) failed"

    if $failed > 0 {
        exit 1
    }
}

# Entry point
def main [] {
    test all
}
