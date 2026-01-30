# Module & Organization Snippets

## Basic Modules

### Single-File Module

```nushell
# math-utils.nu

# Double a number
export def double [n: int] -> int {
    $n * 2
}

# Square a number
export def square [n: int] -> int {
    $n * $n
}

# Exported constant
export const PI = 3.14159

# Private helper (not exported)
def validate-positive [n: int] {
    if $n < 0 {
        error make { msg: "Number must be positive" }
    }
}
```

### Using Modules

```nushell
# Import entire module with prefix
use math-utils.nu
math-utils double 5  # 10

# Import specific items
use math-utils.nu [double, square]
double 5  # 10
square 3  # 9

# Import all exports without prefix
use math-utils.nu *
double 5  # 10

# Import with alias (rename prefix)
use math-utils.nu
alias mu = math-utils
mu double 5
```

---

## Multi-File Modules

### Directory Structure

```
my-module/
├── mod.nu           # Entry point
├── core.nu          # Core functionality
├── utils.nu         # Utility functions
├── constants.nu     # Constants and config
└── types.nu         # Type definitions
```

### Entry Point (mod.nu)

```nushell
# my-module/mod.nu

# Re-export from submodules
export use ./core.nu *
export use ./utils.nu [format-output, validate-input]
export use ./constants.nu *

# Module-level initialization
export-env {
    $env.MY_MODULE_VERSION = "1.0.0"
}

# Module-level command
export def main [] {
    print "My Module v1.0.0"
    help my-module
}
```

### Core Functionality (core.nu)

```nushell
# my-module/core.nu

export def process [input: any] -> any {
    # Core processing logic
    $input | transform
}

export def transform [data: any] -> any {
    # Transformation logic
    $data
}

# Internal helper
def internal-helper [] {
    # Not exported
}
```

### Using Multi-File Module

```nushell
# Import the module
use ./my-module/

# Use exported commands
my-module process $data
my-module transform $data

# Access re-exported items
format-output $result
```

---

## Constants and Configuration

### Constants Module

```nushell
# constants.nu

export const VERSION = "1.0.0"
export const API_BASE_URL = "https://api.example.com"
export const DEFAULT_TIMEOUT = 30sec
export const MAX_RETRIES = 3

export const COLORS = {
    error: "red"
    warning: "yellow"
    success: "green"
    info: "blue"
}

export const SUPPORTED_FORMATS = ["json", "yaml", "toml", "csv"]
```

### Environment-Based Configuration

```nushell
# config.nu

export def get-config [] {
    {
        api_url: ($env.API_URL? | default "https://api.example.com")
        api_key: ($env.API_KEY? | default null)
        debug: ($env.DEBUG? | default "false" | into bool)
        timeout: ($env.TIMEOUT? | default "30" | $in + "sec" | into duration)
        environment: ($env.ENV? | default "development")
    }
}

export def require-config [key: string] {
    let config = get-config
    let value = $config | get -i $key

    if $value == null {
        error make { msg: $"Required config '($key)' is not set" }
    }

    $value
}
```

---

## Overlays

### Creating an Overlay Module

```nushell
# dev-env.nu

# Environment setup
export-env {
    $env.NODE_ENV = "development"
    $env.DEBUG = "true"
    $env.API_URL = "http://localhost:3000"
}

# Dev-specific commands
export def dev-server [] {
    print "Starting development server..."
    ^npm run dev
}

export def dev-db [] {
    print "Starting local database..."
    ^docker-compose up -d db
}

export def dev-logs [] {
    ^docker-compose logs -f
}
```

### Using Overlays

```nushell
# Load overlay
overlay use ./dev-env.nu

# List active overlays
overlay list

# Commands are now available
dev-server

# Hide overlay
overlay hide dev-env

# Load with custom name
overlay use ./dev-env.nu as dev

# Check if overlay is active
"dev-env" in (overlay list)
```

### Project-Specific Overlay

```nushell
# .nu-env (loaded automatically if configured)

export-env {
    # Project paths
    $env.PROJECT_ROOT = (pwd)
    $env.SRC_DIR = ([$env.PROJECT_ROOT, "src"] | path join)
    $env.BUILD_DIR = ([$env.PROJECT_ROOT, "build"] | path join)

    # Project tools
    $env.PATH = ($env.PATH | prepend ([$env.PROJECT_ROOT, "node_modules", ".bin"] | path join))
}

export def build [] {
    cd $env.PROJECT_ROOT
    ^npm run build
}

export def test [] {
    cd $env.PROJECT_ROOT
    ^npm test
}

export def lint [] {
    cd $env.PROJECT_ROOT
    ^npm run lint
}
```

---

## Module Patterns

### Lazy Loading

```nushell
# Only load when needed
def heavy-feature [] {
    use ./heavy-module.nu
    heavy-module do-work
}
```

### Conditional Exports

```nushell
# Export based on platform
export def platform-command [] {
    match $nu.os-info.name {
        "linux" => { linux-specific }
        "macos" => { macos-specific }
        "windows" => { windows-specific }
    }
}

def linux-specific [] {
    ^systemctl status
}

def macos-specific [] {
    ^launchctl list
}

def windows-specific [] {
    ^sc query
}
```

### Plugin-Style Module

```nushell
# plugins/my-plugin.nu

# Plugin metadata
export const PLUGIN_INFO = {
    name: "my-plugin"
    version: "1.0.0"
    description: "A sample plugin"
    author: "Developer"
}

# Plugin initialization
export def init [] {
    print $"Initializing ($PLUGIN_INFO.name) v($PLUGIN_INFO.version)..."
    setup-environment
}

# Plugin commands
export def "my-plugin run" [args: list<string>] {
    # Run plugin logic
}

export def "my-plugin status" [] {
    # Check plugin status
}

def setup-environment [] {
    # Internal setup
}
```

---

## Testing Modules

### Test Module Structure

```nushell
# tests/test_utils.nu

use ../src/utils.nu

# Test helpers
def assert-eq [expected: any, actual: any, msg?: string] {
    if $expected != $actual {
        error make {
            msg: ($msg | default $"Expected ($expected), got ($actual)")
        }
    }
}

def assert-true [condition: bool, msg?: string] {
    if not $condition {
        error make { msg: ($msg | default "Assertion failed: expected true") }
    }
}

def assert-error [action: closure, msg?: string] {
    try {
        do $action
        error make { msg: ($msg | default "Expected error but none was thrown") }
    } catch {
        # Expected error occurred
    }
}

# Tests
def "test double" [] {
    assert-eq 4 (utils double 2) "double 2 should be 4"
    assert-eq 0 (utils double 0) "double 0 should be 0"
    assert-eq -4 (utils double -2) "double -2 should be -4"
}

def "test square" [] {
    assert-eq 4 (utils square 2)
    assert-eq 9 (utils square 3)
    assert-eq 0 (utils square 0)
}

# Run all tests
export def main [] {
    print "Running tests..."

    try {
        test double
        print "✓ test double"
    } catch { |e|
        print $"✗ test double: ($e.msg)"
    }

    try {
        test square
        print "✓ test square"
    } catch { |e|
        print $"✗ test square: ($e.msg)"
    }

    print "Tests complete!"
}
```

---

## Standard Library Usage

### Using std

```nushell
# Available std modules
use std

# Assert module
use std/assert
assert equal 1 1
assert not equal 1 2

# Log module
use std/log
log info "Information message"
log warning "Warning message"
log error "Error message"
log debug "Debug message"

# Path utilities
use std/util "path add"
path add "~/.local/bin"

# Help display
use std/help
```

### Configuration Themes

```nushell
# Use standard library themes
use std/config dark-theme
$env.config.color_config = (dark-theme)

# Or light theme
use std/config light-theme
$env.config.color_config = (light-theme)
```

---

## Module Best Practices

### Documentation Header

```nushell
# =========================================
# Module: data-processor
# Description: Data processing utilities
# Version: 1.0.0
# Author: Your Name
# License: MIT
# =========================================

# Dependencies:
# - polars plugin
# - http commands

export const VERSION = "1.0.0"
```

### Error Handling Pattern

```nushell
# Wrap errors with module context
def module-error [msg: string] {
    error make {
        msg: $"[data-processor] ($msg)"
    }
}

export def process [input: any] {
    if ($input | is-empty) {
        module-error "Input cannot be empty"
    }

    try {
        transform $input
    } catch { |e|
        module-error $"Transform failed: ($e.msg)"
    }
}
```

### Initialization Pattern

```nushell
# Module with required initialization
export-env {
    # Set up required environment
    if ($env.MY_MODULE_INIT? == null) {
        $env.MY_MODULE_INIT = false
    }
}

def ensure-initialized [] {
    if not $env.MY_MODULE_INIT {
        error make { msg: "Module not initialized. Call 'my-module init' first." }
    }
}

export def init [] {
    # Perform initialization
    print "Initializing module..."
    $env.MY_MODULE_INIT = true
}

export def command [] {
    ensure-initialized
    # Command logic
}
```
