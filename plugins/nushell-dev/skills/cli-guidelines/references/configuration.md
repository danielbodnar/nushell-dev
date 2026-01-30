# CLI Configuration Reference

> Based on [clig.dev](https://clig.dev/) guidelines adapted for Nushell

---

## Configuration Philosophy

Configuration should be **predictable**, **layered**, and **transparent**. Users should
always understand where a setting comes from and how to override it.

---

## Configuration Categories

### 1. Per-Invocation Configuration

Settings that change frequently, typically via **flags** or **environment variables**:

```nushell
# Flags for per-invocation settings
def serve [
    --port (-p): int = 3000    # Changes often
    --verbose (-v)              # Debug this run only
    --dry-run                   # One-time test
] {
    # These override everything
}
```

### 2. Generally Stable Configuration

Settings that rarely change, stored in **environment variables** or **config files**:

```nushell
# User's shell config sets these once
# ~/.config/nushell/env.nu
$env.MY_APP_DEFAULT_EDITOR = "nvim"
$env.MY_APP_LOG_LEVEL = "info"
```

### 3. Project-Specific Configuration

Settings that are **version-controlled** with the project:

```nushell
# .myapp.nuon or myapp.config.nuon in project root
{
    build: {
        target: "release"
        features: ["serde", "async"]
    }
    deploy: {
        environment: "staging"
    }
}
```

---

## Configuration Precedence

**Most specific wins.** From highest to lowest priority:

1. **Command-line flags** (explicit user intent)
2. **Environment variables** (session/user preference)
3. **Project config file** (version-controlled, shared)
4. **User config file** (personal preferences)
5. **System config file** (admin defaults)
6. **Built-in defaults** (hardcoded fallbacks)

### Implementing Precedence in Nushell

```nushell
# Configuration loading with proper precedence
def load-config [
    --config (-c): path  # Explicit config file (highest priority)
] {
    # Start with defaults
    mut config = {
        timeout: 30
        verbose: false
        format: "json"
        output_dir: "."
    }

    # Layer 5: System config
    let system_config = "/etc/myapp/config.nuon"
    if ($system_config | path exists) {
        $config = ($config | merge (open $system_config))
    }

    # Layer 4: User config (XDG compliant)
    let user_config = ($env.XDG_CONFIG_HOME? | default ($nu.home-path | path join ".config"))
        | path join "myapp" "config.nuon"
    if ($user_config | path exists) {
        $config = ($config | merge (open $user_config))
    }

    # Layer 3: Project config (walk up to find)
    let project_config = find-project-config
    if $project_config != null {
        $config = ($config | merge (open $project_config))
    }

    # Layer 2: Environment variables
    if ($env.MY_APP_TIMEOUT? | is-not-empty) {
        $config.timeout = ($env.MY_APP_TIMEOUT | into int)
    }
    if ($env.MY_APP_VERBOSE? | is-not-empty) {
        $config.verbose = ($env.MY_APP_VERBOSE == "1" or $env.MY_APP_VERBOSE == "true")
    }

    # Layer 1: Explicit config file (overrides everything)
    if $config != null and ($config | path exists) {
        $config = ($config | merge (open $config))
    }

    $config
}

# Find project config by walking up directory tree
def find-project-config [] {
    let config_names = [".myapp.nuon", "myapp.config.nuon", ".myapp/config.nuon"]
    mut current = (pwd)

    loop {
        for name in $config_names {
            let path = $current | path join $name
            if ($path | path exists) {
                return $path
            }
        }

        let parent = $current | path dirname
        if $parent == $current {
            return null  # Reached root
        }
        $current = $parent
    }
}
```

---

## XDG Base Directory Specification

Follow the XDG spec for predictable config locations:

| Variable | Default | Purpose |
|----------|---------|---------|
| `XDG_CONFIG_HOME` | `~/.config` | User configuration |
| `XDG_DATA_HOME` | `~/.local/share` | User data files |
| `XDG_STATE_HOME` | `~/.local/state` | User state (logs, history) |
| `XDG_CACHE_HOME` | `~/.cache` | Non-essential cached data |
| `XDG_RUNTIME_DIR` | `/run/user/$UID` | Runtime files (sockets, pid) |

### XDG Paths in Nushell

```nushell
# Get XDG directories with fallbacks
def xdg-config-home [] {
    $env.XDG_CONFIG_HOME? | default ($nu.home-path | path join ".config")
}

def xdg-data-home [] {
    $env.XDG_DATA_HOME? | default ($nu.home-path | path join ".local" "share")
}

def xdg-state-home [] {
    $env.XDG_STATE_HOME? | default ($nu.home-path | path join ".local" "state")
}

def xdg-cache-home [] {
    $env.XDG_CACHE_HOME? | default ($nu.home-path | path join ".cache")
}

# Complete XDG paths for an app
def get-app-paths [app_name: string] {
    {
        config: (xdg-config-home | path join $app_name)
        data: (xdg-data-home | path join $app_name)
        state: (xdg-state-home | path join $app_name)
        cache: (xdg-cache-home | path join $app_name)
    }
}

# Example: Initialize app directories
def init-app-dirs [app_name: string] {
    let paths = get-app-paths $app_name

    for dir in ($paths | values) {
        if not ($dir | path exists) {
            mkdir $dir
        }
    }

    $paths
}
```

---

## Environment Variables

### Naming Conventions

- **UPPERCASE** with **UNDERSCORES**
- Prefix with your app name: `MYAPP_*`
- Be consistent across your tooling

```nushell
# Good naming
$env.MYAPP_CONFIG_PATH
$env.MYAPP_LOG_LEVEL
$env.MYAPP_API_ENDPOINT

# Bad naming
$env.myapp_config        # lowercase
$env.MyAppConfig         # mixed case
$env.MYAPP-CONFIG        # hyphens
```

### Standard Environment Variables

Respect these widely-used variables:

| Variable | Purpose | Your CLI Should... |
|----------|---------|-------------------|
| `NO_COLOR` | Disable color output | Check and disable ANSI codes |
| `FORCE_COLOR` | Force color output | Enable colors even without TTY |
| `DEBUG` | Enable debug mode | Show verbose/debug output |
| `VERBOSE` | Enable verbose mode | Show more information |
| `EDITOR` | Preferred text editor | Use for interactive editing |
| `VISUAL` | Preferred visual editor | Prefer over EDITOR if set |
| `PAGER` | Preferred pager | Use for long output |
| `TERM` | Terminal type | Adjust output capabilities |
| `HOME` | User home directory | Find user files |
| `TMPDIR` | Temporary directory | Write temp files |
| `HTTP_PROXY` | HTTP proxy URL | Route HTTP requests |
| `HTTPS_PROXY` | HTTPS proxy URL | Route HTTPS requests |
| `NO_PROXY` | Proxy bypass list | Skip proxy for listed hosts |

### Implementing Standard Variables

```nushell
# Check NO_COLOR
def should-use-color [] {
    if ($env.NO_COLOR? | is-not-empty) {
        false
    } else if ($env.FORCE_COLOR? | is-not-empty) {
        true
    } else {
        # Check if stdout is a terminal
        (term size | get columns) > 0
    }
}

# Get user's preferred editor
def get-editor [] {
    $env.VISUAL? | default ($env.EDITOR? | default "vi")
}

# Open file in editor
def edit-file [file: path] {
    let editor = get-editor
    run-external $editor $file
}

# Get pager for long output
def get-pager [] {
    $env.PAGER? | default "less"
}

# Page long output
def page-output [content: string] {
    if (term size | get rows) < ($content | lines | length) {
        $content | run-external (get-pager)
    } else {
        print $content
    }
}

# Debug mode check
def is-debug [] {
    let debug = $env.DEBUG? | default ""
    $debug == "1" or $debug == "true" or $debug =~ $env.MY_APP_NAME?
}
```

---

## Reading .env Files

Many projects use `.env` files for configuration. Handle them properly:

```nushell
# Basic .env reader
def load-dotenv [file: path = ".env"] {
    if not ($file | path exists) {
        return
    }

    open $file
    | lines
    | where { |line|
        let trimmed = $line | str trim
        # Skip empty lines and comments
        ($trimmed | is-not-empty) and (not ($trimmed | str starts-with "#"))
    }
    | each { |line|
        # Handle KEY=VALUE format
        let parts = $line | split row "=" --max-splits 1
        if ($parts | length) == 2 {
            let key = $parts.0 | str trim
            let value = $parts.1 | str trim | str trim --char '"' | str trim --char "'"
            { key: $key, value: $value }
        }
    }
    | reduce -f {} { |it, acc|
        $acc | insert $it.key $it.value
    }
}

# Load .env into environment
def --env source-dotenv [file: path = ".env"] {
    let vars = load-dotenv $file

    for key in ($vars | columns) {
        let value = $vars | get $key
        load-env { $key: $value }
    }
}

# Example: Load multiple .env files with precedence
def --env load-env-files [] {
    # Load in order (later files override earlier)
    let files = [
        ".env"           # Base settings
        ".env.local"     # Local overrides (gitignored)
        $".env.($env.NODE_ENV? | default 'development')"  # Environment-specific
    ]

    for file in $files {
        if ($file | path exists) {
            source-dotenv $file
        }
    }
}
```

---

## Security: Never Read Secrets from Environment

Environment variables are **visible** to:
- Process listings (`ps auxe`)
- Child processes (inherited by default)
- Crash dumps and logs
- Container orchestration systems

### Secure Secret Handling

```nushell
# BAD: Secrets in environment
$env.MY_APP_API_KEY = "sk-secret-key"  # Visible to all child processes!

# GOOD: Read from file with restricted permissions
def get-secret [name: string] {
    let secret_file = xdg-config-home
        | path join "myapp" "secrets" $name

    if not ($secret_file | path exists) {
        error make {
            msg: $"Secret not found: ($name)"
            help: $"Create file at ($secret_file) with permissions 600"
        }
    }

    # Check permissions (should be 600 or 400)
    let perms = ls -l $secret_file | get mode | first
    if not ($perms | str starts-with "-r") or ($perms =~ "r..r") {
        error make {
            msg: $"Secret file has unsafe permissions: ($secret_file)"
            help: "Run: chmod 600 $secret_file"
        }
    }

    open $secret_file | str trim
}

# GOOD: Use credential helpers
def get-api-key [] {
    # Try system keychain first
    try {
        run-external "secret-tool" "lookup" "service" "myapp" "key" "api"
    } catch {
        # Fall back to file
        get-secret "api-key"
    }
}
```

---

## Auto-Modification Consent

If your CLI modifies config files, **always ask** or use `--yes`:

```nushell
# Ask before modifying config
def update-config [key: string, value: any, --yes (-y)] {
    let config_path = xdg-config-home | path join "myapp" "config.nuon"

    if not $yes {
        print $"Will update ($key) = ($value) in ($config_path)"
        let response = input "Proceed? [y/N] "
        if ($response | str downcase) != "y" {
            print "Aborted."
            return
        }
    }

    let config = if ($config_path | path exists) {
        open $config_path
    } else {
        {}
    }

    $config | upsert $key $value | save -f $config_path
    print $"Updated ($key) in ($config_path)"
}
```

---

## Configuration Documentation

Always tell users where config comes from:

```nushell
# Show where configuration was loaded from
def config-info [] {
    let sources = []

    # Check each source
    let system = "/etc/myapp/config.nuon"
    let user = xdg-config-home | path join "myapp" "config.nuon"
    let project = find-project-config

    print "Configuration sources (in precedence order):\n"

    print $"  1. Command-line flags:   (ansi cyan)--flag value(ansi reset)"
    print $"  2. Environment vars:     (ansi cyan)MY_APP_*(ansi reset)"

    if $project != null {
        print $"  3. Project config:       (ansi green)($project)(ansi reset) [FOUND]"
    } else {
        print $"  3. Project config:       (ansi dim).myapp.nuon [not found](ansi reset)"
    }

    if ($user | path exists) {
        print $"  4. User config:          (ansi green)($user)(ansi reset) [FOUND]"
    } else {
        print $"  4. User config:          (ansi dim)($user) [not found](ansi reset)"
    }

    if ($system | path exists) {
        print $"  5. System config:        (ansi green)($system)(ansi reset) [FOUND]"
    } else {
        print $"  5. System config:        (ansi dim)($system) [not found](ansi reset)"
    }

    print $"\n  6. Built-in defaults:    (ansi cyan)[hardcoded](ansi reset)"
}

# Show effective configuration
def config-show [] {
    let config = load-config

    print "Effective configuration:\n"
    print ($config | to nuon --indent 2)
}
```

---

## Complete Configuration Example

```nushell
#!/usr/bin/env nu

# A well-configured CLI application

const APP_NAME = "myapp"
const VERSION = "1.0.0"

# Default configuration
const DEFAULTS = {
    timeout: 30
    verbose: false
    format: "json"
    color: "auto"
}

# Load configuration with full precedence chain
def load-full-config [
    --config (-c): path
    --timeout: int
    --verbose (-v)
    --format (-f): string
] {
    # Start with defaults
    mut config = $DEFAULTS

    # System config
    let sys_config = $"/etc/($APP_NAME)/config.nuon"
    if ($sys_config | path exists) {
        $config = ($config | merge (open $sys_config))
    }

    # User config
    let user_config = xdg-config-home | path join $APP_NAME "config.nuon"
    if ($user_config | path exists) {
        $config = ($config | merge (open $user_config))
    }

    # Project config
    let proj_config = find-project-config
    if $proj_config != null {
        $config = ($config | merge (open $proj_config))
    }

    # Environment variables
    let env_map = {
        timeout: ($env.MYAPP_TIMEOUT? | if ($in | is-not-empty) { $in | into int })
        verbose: ($env.MYAPP_VERBOSE? | if ($in | is-not-empty) { $in in ["1", "true"] })
        format: $env.MYAPP_FORMAT?
    }

    for key in ($env_map | columns) {
        let val = $env_map | get $key
        if $val != null {
            $config = ($config | upsert $key $val)
        }
    }

    # Explicit config file
    if $config != null and ($config | path exists) {
        $config = ($config | merge (open $config))
    }

    # Command-line flags (highest priority)
    if $timeout != null { $config.timeout = $timeout }
    if $verbose { $config.verbose = true }
    if $format != null { $config.format = $format }

    $config
}

def main [
    command: string
    --config (-c): path
    --timeout: int
    --verbose (-v)
    --format (-f): string
] {
    let config = load-full-config --config $config --timeout $timeout --verbose $verbose --format $format

    match $command {
        "config" => { config-show }
        "config-info" => { config-info }
        _ => { print $"Running with config: ($config | to nuon)" }
    }
}
```

---

## Summary Checklist

- [ ] Support configuration at multiple levels (flags, env, project, user, system)
- [ ] Implement clear precedence (flags override env override config files)
- [ ] Follow XDG Base Directory Specification
- [ ] Use proper environment variable naming (UPPERCASE_WITH_UNDERSCORES)
- [ ] Respect standard variables (NO_COLOR, EDITOR, PAGER, etc.)
- [ ] Support .env files for project-specific configuration
- [ ] NEVER store secrets in environment variables
- [ ] Ask consent before auto-modifying config files
- [ ] Provide commands to show config sources and effective values
- [ ] Document where configuration is loaded from
