#!/usr/bin/env nu
# cli-compliant-script.nu - File Batch Processor
#
# A comprehensive example implementing ALL clig.dev CLI guidelines in Nushell.
# Use this as THE template for building CLI tools.
#
# This tool processes files with various transformations (hash, analyze, convert)
# and demonstrates proper CLI patterns for help, arguments, output, errors,
# configuration, robustness, and interactivity.
#
# Usage:
#   nu cli-compliant-script.nu <command> [options]
#   nu cli-compliant-script.nu process <files...> [options]
#   nu cli-compliant-script.nu analyze <path> [options]
#
# Examples:
#   nu cli-compliant-script.nu process file.txt --output ./results
#   nu cli-compliant-script.nu analyze ./src --recursive --json
#   nu cli-compliant-script.nu --version
#   nu cli-compliant-script.nu --help
#
# Environment Variables:
#   FBP_CONFIG       Path to config file (default: ~/.config/fbp/config.toml)
#   FBP_OUTPUT_DIR   Default output directory
#   FBP_VERBOSE      Enable verbose output (set to "1" or "true")
#   NO_COLOR         Disable colored output
#
# Exit Codes:
#   0  Success
#   1  General error
#   2  Usage/argument error
#   78 Configuration error
#
# Author: Daniel Bodnar <daniel.bodnar@gmail.com>
# License: MIT
# Version: 1.0.0

# ==============================================================================
# CONSTANTS & CONFIGURATION
# ==============================================================================

const VERSION = "1.0.0"
const SCRIPT_NAME = "fbp"
const SCRIPT_DESCRIPTION = "File Batch Processor - Process files with various transformations"

# Exit codes following sysexits.h conventions
const EXIT_SUCCESS = 0
const EXIT_ERROR = 1
const EXIT_USAGE = 2
const EXIT_CONFIG = 78

# XDG-compliant default paths
def get-config-dir []: nothing -> string {
    $env.FBP_CONFIG_DIR?
        | default ($env.XDG_CONFIG_HOME? | default "~/.config")
        | path expand
        | path join $SCRIPT_NAME
}

def get-default-config-path []: nothing -> string {
    get-config-dir | path join "config.toml"
}

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

# Check if running in a terminal (TTY detection)
def is-terminal []: nothing -> bool {
    (term size | is-not-empty)
}

# Check if colors should be used
def use-colors []: nothing -> bool {
    ($env.NO_COLOR? | is-empty) and (is-terminal)
}

# Colorize text if colors are enabled
def colorize [color: string, text: string]: nothing -> string {
    if (use-colors) {
        match $color {
            "red" => $"(ansi red)($text)(ansi reset)"
            "green" => $"(ansi green)($text)(ansi reset)"
            "yellow" => $"(ansi yellow)($text)(ansi reset)"
            "blue" => $"(ansi blue)($text)(ansi reset)"
            "cyan" => $"(ansi cyan)($text)(ansi reset)"
            "bold" => $"(ansi bold)($text)(ansi reset)"
            _ => $text
        }
    } else {
        $text
    }
}

# ==============================================================================
# LOGGING FUNCTIONS
# ==============================================================================

# Log levels with proper stderr output
def "log info" [msg: string, --quiet] {
    if not $quiet {
        print -e $"(colorize 'blue' '[INFO]') ($msg)"
    }
}

def "log success" [msg: string, --quiet] {
    if not $quiet {
        print -e $"(colorize 'green' '[OK]') ($msg)"
    }
}

def "log warn" [msg: string] {
    print -e $"(colorize 'yellow' '[WARN]') ($msg)"
}

def "log error" [msg: string] {
    print -e $"(colorize 'red' '[ERROR]') ($msg)"
}

def "log debug" [msg: string, --verbose] {
    if $verbose {
        print -e $"(colorize 'cyan' '[DEBUG]') ($msg)"
    }
}

# ==============================================================================
# CONFIGURATION LOADING
# ==============================================================================

# Load configuration with proper hierarchy:
# 1. Command-line flags (highest priority)
# 2. Environment variables
# 3. User config file (~/.config/fbp/config.toml)
# 4. Built-in defaults (lowest priority)
#
# Parameters:
#   config_path: Explicit config file path (overrides all)
#
# Returns: record with merged configuration
def load-config [
    config_path?: path    # Explicit config file path
]: nothing -> record {
    # Built-in defaults
    let defaults = {
        output_dir: "."
        format: "table"
        max_files: 1000
        timeout: 30sec
        recursive: false
        verbose: false
    }

    # Determine config file path
    let config_file = if ($config_path | is-not-empty) {
        $config_path
    } else if ($env.FBP_CONFIG? | is-not-empty) {
        $env.FBP_CONFIG
    } else {
        get-default-config-path
    }

    # Load config file if exists
    let file_config = if ($config_file | path exists) {
        try {
            open $config_file
        } catch {
            log warn $"Could not load config from ($config_file), using defaults"
            {}
        }
    } else {
        {}
    }

    # Environment variable overrides
    let env_config = {
        output_dir: ($env.FBP_OUTPUT_DIR? | default null)
        verbose: ($env.FBP_VERBOSE? | default null | if ($in in ["1", "true"]) { true } else { null })
    } | reject-nulls

    # Merge: defaults <- file <- env
    $defaults | merge $file_config | merge $env_config
}

# Helper to remove null values from record
def reject-nulls []: record -> record {
    let filtered = $in | transpose key value | where value != null
    if ($filtered | is-empty) {
        {}
    } else {
        $filtered | transpose -r -d
    }
}

# ==============================================================================
# INPUT VALIDATION
# ==============================================================================

# Validate file path exists and is accessible
def validate-path [
    path: string          # Path to validate
    --type: string = "any"  # Expected type: file, dir, any
] {
    if ($path | is-empty) {
        error make {
            msg: "Path cannot be empty"
            help: "Provide a valid file or directory path"
        }
    }

    let expanded = $path | path expand

    if not ($expanded | path exists) {
        error make {
            msg: $"Path not found: ($path)"
            help: "Check that the path exists and you have permission to access it"
        }
    }

    let actual_type = $expanded | path type

    if $type != "any" and $actual_type != $type {
        let help_msg = if $type == "file" {
            "Provide a file path, not a directory"
        } else {
            "Provide a directory path, not a file"
        }
        error make {
            msg: $"Expected ($type), got ($actual_type): ($path)"
            help: $help_msg
        }
    }

    $expanded
}

# ==============================================================================
# PROGRESS INDICATORS
# ==============================================================================

# Display progress bar for known-length operations
def progress-bar [current: int, total: int, width: int = 30]: nothing -> string {
    let percent = if $total > 0 { $current / $total } else { 0 }
    let filled = ($percent * $width | math round | into int)
    let empty = $width - $filled

    let filled_bar = '' | fill --character '=' --width $filled
    let empty_bar = '' | fill --character '.' --width $empty
    let bar = $"[($filled_bar)($empty_bar)]"
    let pct = ($percent * 100 | math round | into int)
    $"($bar) ($pct)% (($current)/($total))"
}

# ==============================================================================
# CONFIRMATION PROMPTS
# ==============================================================================

# Interactive confirmation with TTY awareness
#
# Parameters:
#   message: Prompt message
#   --default: Default value when non-interactive
#   --force: Skip confirmation entirely
#
# Returns: bool indicating user's choice
def confirm [
    message: string
    --default              # Default to yes when non-interactive
    --force                # Skip confirmation entirely
]: nothing -> bool {
    if $force {
        return true
    }

    if not (is-terminal) {
        return $default
    }

    let suffix = if $default { " [Y/n]: " } else { " [y/N]: " }
    let response = input $"($message)($suffix)" | str trim | str downcase

    if ($response | is-empty) {
        $default
    } else {
        $response in ["y", "yes"]
    }
}

# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

# File Batch Processor - Process files with various transformations
#
# A CLI tool following clig.dev best practices for processing files.
# Supports multiple output formats, progress indication, and both
# interactive and scripted usage modes.
#
# Examples:
#   fbp process *.txt --output ./results
#   fbp analyze ./src --recursive --json
#   echo "data" | fbp process --stdin
def main [
    --version             # Show version information
    --help (-h)           # Show this help message
    --verbose (-v)        # Enable verbose output
    --quiet (-q)          # Suppress non-essential output
    --json (-j)           # Output as JSON (machine-readable)
    --config (-c): path   # Path to config file
    --no-input            # Disable all interactive prompts
    --dry-run (-n)        # Show what would be done without doing it
] {
    # Handle --version
    if $version {
        print $"($SCRIPT_NAME) ($VERSION)"
        exit $EXIT_SUCCESS
    }

    # Handle --help or no arguments (show usage)
    print $"($SCRIPT_NAME) - ($SCRIPT_DESCRIPTION)"
    print ""
    print "Usage:"
    print $"  ($SCRIPT_NAME) <command> [options]"
    print ""
    print "Commands:"
    print "  process   Process files with transformations"
    print "  analyze   Analyze files and show statistics"
    print "  config    Manage configuration"
    print ""
    print "Options:"
    print "  --version        Show version and exit"
    print "  --help, -h       Show this help message"
    print "  --verbose, -v    Enable verbose output"
    print "  --quiet, -q      Suppress non-essential output"
    print "  --json, -j       Output as JSON"
    print "  --config, -c     Path to config file"
    print "  --no-input       Disable interactive prompts"
    print "  --dry-run, -n    Preview changes without applying"
    print ""
    print $"Run '($SCRIPT_NAME) <command> --help' for command-specific help"
}

# ==============================================================================
# PROCESS COMMAND
# ==============================================================================

# Process files with various transformations
#
# Applies transformations to one or more files, with progress indication
# and support for both interactive and batch processing modes.
#
# Examples:
#   fbp process file.txt
#   fbp process *.log --output ./processed --recursive
#   fbp process data.csv --transform hash --json
#   cat file.txt | fbp process --stdin --output result.txt
def "main process" [
    ...files: path              # Files to process (supports globs)
    --output (-o): path         # Output directory or file
    --recursive (-r)            # Process directories recursively
    --transform (-t): string = "hash"  # Transformation: hash, count, size
    --verbose (-v)              # Enable verbose output
    --quiet (-q)                # Suppress progress output
    --json (-j)                 # Output as JSON
    --force (-f)                # Overwrite existing files without prompting
    --dry-run (-n)              # Show what would be done
    --no-input                  # Disable interactive prompts
    --stdin                     # Read file list from stdin
    --config (-c): path         # Path to config file
] {
    # Load configuration
    let config = load-config $config

    # Merge config with flags (flags take priority)
    let verbose = $verbose or $config.verbose
    let output_dir = $output | default $config.output_dir

    log debug "Starting process command" --verbose=$verbose

    # Validate transform type
    let valid_transforms = ["hash", "count", "size", "lines"]
    if $transform not-in $valid_transforms {
        log error $"Invalid transform: ($transform)"
        print -e $"Valid transforms: ($valid_transforms | str join ', ')"
        exit $EXIT_USAGE
    }

    # Collect files from arguments or stdin
    let file_list = if $stdin {
        if ($files | is-not-empty) {
            log warn "Ignoring positional arguments when --stdin is used"
        }
        $in | lines | where { $in | is-not-empty }
    } else if ($files | is-empty) {
        log error "No files specified"
        print -e "Usage: fbp process <files...> [options]"
        print -e "       echo 'file.txt' | fbp process --stdin"
        exit $EXIT_USAGE
    } else {
        $files
    }

    # Expand globs and validate files
    let expanded_files = $file_list | each { |f|
        if ($f | str contains "*") {
            glob $f
        } else {
            [$f]
        }
    } | flatten | uniq

    if ($expanded_files | is-empty) {
        log error "No matching files found"
        exit $EXIT_ERROR
    }

    # Validate all files exist
    let valid_files = $expanded_files | each { |f|
        if not ($f | path exists) {
            log warn $"File not found, skipping: ($f)"
            null
        } else if ($f | path type) == "dir" {
            if $recursive {
                glob $"($f)/**/*" | where { ($in | path type) == "file" }
            } else {
                log warn $"Skipping directory, use --recursive: ($f)"
                null
            }
        } else {
            $f
        }
    } | flatten | compact

    let total = $valid_files | length

    if $total == 0 {
        log error "No valid files to process"
        exit $EXIT_ERROR
    }

    log info $"Processing ($total) file(s) with transform: ($transform)" --quiet=$quiet

    # Dry run mode
    if $dry_run {
        print (colorize "yellow" "DRY RUN - No changes will be made")
        $valid_files | each { |f|
            print $"  Would process: ($f)"
        }
        return
    }

    # Check for existing output and confirm overwrite
    if ($output | is-not-empty) and ($output | path exists) and not $force {
        if $no_input {
            log error $"Output exists and --force not specified: ($output)"
            exit $EXIT_ERROR
        }
        if not (confirm $"Output '($output)' exists. Overwrite?") {
            print "Aborted."
            exit $EXIT_SUCCESS
        }
    }

    # Process files with progress indication
    let results = $valid_files | enumerate | each { |item|
        let file = $item.item
        let idx = $item.index + 1

        # Show progress on stderr (not mixed with data output)
        if not $quiet and (is-terminal) {
            print -n -e $"\r(progress-bar $idx $total) Processing: ($file | path basename)"
        }

        # Apply transformation
        let result = try {
            match $transform {
                "hash" => {
                    let hash = open --raw $file | hash sha256
                    { file: $file, hash: $hash }
                }
                "count" => {
                    let content = open --raw $file
                    {
                        file: $file
                        bytes: ($content | str length)
                        chars: ($content | str length)
                    }
                }
                "size" => {
                    let stat = $file | path expand | ls $in | first
                    { file: $file, size: $stat.size, modified: $stat.modified }
                }
                "lines" => {
                    let lines = open --raw $file | lines | length
                    { file: $file, lines: $lines }
                }
            }
        } catch { |err|
            log warn $"Failed to process ($file): ($err.msg)"
            { file: $file, error: $err.msg }
        }

        $result
    }

    # Clear progress line
    if not $quiet and (is-terminal) {
        print -e ""
    }

    log success $"Processed ($total) file(s)" --quiet=$quiet

    # Output results
    if $json {
        $results | to json
    } else {
        $results
    }
}

# ==============================================================================
# ANALYZE COMMAND
# ==============================================================================

# Analyze files and directories, showing statistics
#
# Provides detailed analysis of file contents including line counts,
# size distribution, and file type breakdown.
#
# Examples:
#   fbp analyze ./src
#   fbp analyze . --recursive --json
#   fbp analyze ./logs --pattern "*.log"
def "main analyze" [
    path: path = "."           # Path to analyze
    --recursive (-r)           # Analyze subdirectories
    --pattern (-p): string     # Filter by glob pattern (e.g., "*.rs")
    --verbose (-v)             # Show detailed output
    --quiet (-q)               # Minimal output
    --json (-j)                # Output as JSON
    --config (-c): path        # Path to config file
] {
    # Validate path
    let target = validate-path $path --type "dir"

    log info $"Analyzing: ($target)" --quiet=$quiet
    log debug $"Recursive: ($recursive), Pattern: ($pattern | default 'all')" --verbose=$verbose

    # Collect files
    let files = if $recursive {
        if ($pattern | is-not-empty) {
            glob $"($target)/**/($pattern)"
        } else {
            glob $"($target)/**/*" | where { ($in | path type) == "file" }
        }
    } else {
        if ($pattern | is-not-empty) {
            glob $"($target)/($pattern)"
        } else {
            ls $target | where type == "file" | get name
        }
    }

    if ($files | is-empty) {
        log warn "No files found matching criteria"
        return { files: 0, total_size: 0b, extensions: {} }
    }

    let total = $files | length

    # Analyze with progress
    let analysis = $files | enumerate | each { |item|
        if not $quiet and (is-terminal) and ($total > 10) {
            print -n -e $"\r(progress-bar ($item.index + 1) $total) Analyzing..."
        }

        let f = $item.item
        let stat = ls $f | first
        let ext = $f | path parse | get extension | default "none"

        {
            file: $f
            size: $stat.size
            extension: $ext
            modified: $stat.modified
        }
    }

    if not $quiet and (is-terminal) and ($total > 10) {
        print -e ""
    }

    # Compute statistics
    let total_size = $analysis | get size | math sum
    let by_extension = $analysis
        | group-by extension
        | transpose ext files
        | each { |g|
            {
                extension: $g.ext
                count: ($g.files | length)
                total_size: ($g.files | get size | math sum)
            }
        }
        | sort-by count --reverse

    let result = {
        path: $target
        files: $total
        total_size: $total_size
        by_extension: $by_extension
        newest: ($analysis | sort-by modified | last | get file)
        oldest: ($analysis | sort-by modified | first | get file)
    }

    if $json {
        $result | to json
    } else {
        print $"(colorize 'bold' 'Analysis Results')"
        print $"  Path: ($result.path)"
        print $"  Files: ($result.files)"
        print $"  Total Size: ($result.total_size)"
        print ""
        print (colorize "bold" "By Extension:")
        $result.by_extension | table
    }
}

# ==============================================================================
# CONFIG COMMAND
# ==============================================================================

# Manage configuration settings
#
# View, edit, and reset configuration. Configuration follows XDG standards
# and supports environment variable overrides.
#
# Examples:
#   fbp config show
#   fbp config path
#   fbp config init
def "main config" [] {
    print "Usage: fbp config <command>"
    print ""
    print "Commands:"
    print "  show    Display current configuration"
    print "  path    Show configuration file path"
    print "  init    Create default configuration file"
}

# Display current configuration
def "main config show" [
    --json (-j)    # Output as JSON
] {
    let config = load-config

    if $json {
        $config | to json
    } else {
        print (colorize "bold" "Current Configuration:")
        $config | table
    }
}

# Show configuration file path
def "main config path" [] {
    let config_path = get-default-config-path
    let exists = $config_path | path exists

    print $"Config path: ($config_path)"
    print $"Exists: ($exists)"

    if not $exists {
        print ""
        print "Run 'fbp config init' to create default configuration"
    }
}

# Create default configuration file
def "main config init" [
    --force (-f)    # Overwrite existing config
] {
    let config_path = get-default-config-path
    let config_dir = get-config-dir

    if ($config_path | path exists) and not $force {
        log error $"Config already exists: ($config_path)"
        print -e "Use --force to overwrite"
        exit $EXIT_ERROR
    }

    # Ensure directory exists
    if not ($config_dir | path exists) {
        mkdir $config_dir
    }

    # Write default config
    let default_config = {
        output_dir: "."
        format: "table"
        max_files: 1000
        timeout: "30sec"
        recursive: false
        verbose: false
    }

    $default_config | to toml | save -f $config_path

    log success $"Created config at: ($config_path)"
}

# ==============================================================================
# COMPLETIONS (for shell integration)
# ==============================================================================

# Tab completion for transform types
def "nu-complete transforms" [] {
    ["hash", "count", "size", "lines"] | each { |t|
        { value: $t, description: (match $t {
            "hash" => "SHA256 hash of file contents"
            "count" => "Byte and character count"
            "size" => "File size and modification time"
            "lines" => "Line count"
        })}
    }
}

# Tab completion for output formats
def "nu-complete formats" [] {
    ["table", "json", "csv", "yaml"]
}

# ==============================================================================
# STDIN HANDLING
# ==============================================================================

# Read input from stdin or file, handling TTY detection
#
# Demonstrates proper stdin handling per clig.dev guidelines:
# - Detect if stdin is a TTY (interactive) or pipe
# - Support "-" as filename for stdin
# - Provide helpful errors when stdin expected but TTY
#
# Parameters:
#   input: Input file path or "-" for stdin
#
# Returns: Content from file or stdin
def read-input [
    input: string           # File path or "-" for stdin
] {
    if $input == "-" {
        # Check if we're receiving piped input
        if (is-terminal) {
            error make {
                msg: "No input provided on stdin"
                help: "Pipe data to this command: echo 'data' | fbp process -"
            }
        }
        $in
    } else {
        if not ($input | path exists) {
            error make {
                msg: $"File not found: ($input)"
                help: "Check the file path exists and you have read permissions"
            }
        }
        open $input
    }
}

# ==============================================================================
# SIGNAL HANDLING & CLEANUP
# ==============================================================================

# Register cleanup handler for graceful shutdown
#
# Per clig.dev: Handle signals gracefully, clean up temp files,
# and provide status on interrupt
def register-cleanup [
    temp_files: list<path>   # List of temp files to clean up
] {
    # Note: Nushell doesn't have built-in signal handlers like Bash
    # This is a placeholder showing the pattern
    # In practice, use try/catch with cleanup in finally-like pattern
    {
        cleanup: { |files|
            for f in $files {
                if ($f | path exists) {
                    rm -f $f
                }
            }
        }
        files: $temp_files
    }
}

# ==============================================================================
# OUTPUT FORMATTING
# ==============================================================================

# Format output based on context and flags
#
# Follows clig.dev output guidelines:
# - Default to human-readable when TTY
# - Default to machine-readable (JSON) when piped
# - Respect explicit --json flag
# - Respect NO_COLOR environment variable
#
# Parameters:
#   data: Data to format
#   format: Output format override
#   json_flag: Whether --json was explicitly set
#
# Returns: Formatted string
def format-output [
    data: any                      # Data to format
    --format: string = "auto"      # Format: auto, json, table, csv, yaml
    --json                         # Force JSON output
] {
    let actual_format = if $json {
        "json"
    } else if $format == "auto" {
        if (is-terminal) { "table" } else { "json" }
    } else {
        $format
    }

    match $actual_format {
        "json" => ($data | to json)
        "csv" => ($data | to csv)
        "yaml" => ($data | to yaml)
        "table" => ($data | table | into string)
        _ => ($data | to json)
    }
}

# ==============================================================================
# VERSION INFORMATION
# ==============================================================================

# Show detailed version information
#
# Per clig.dev: --version should show program name and version.
# Optionally include build info, dependencies, etc.
def show-version [] {
    let info = {
        name: $SCRIPT_NAME
        version: $VERSION
        nushell_version: (version | get version)
        built_with: "Nushell"
        author: "Daniel Bodnar <daniel.bodnar@gmail.com>"
        license: "MIT"
    }

    if (is-terminal) {
        print $"($SCRIPT_NAME) ($VERSION)"
        print $"Built with Nushell (version | get version)"
    } else {
        $info | to json
    }
}

# ==============================================================================
# ENVIRONMENT VARIABLE DOCUMENTATION
# ==============================================================================

# Show environment variables used by this tool
#
# Per clig.dev: Document all environment variables the tool respects
def show-env-vars [] {
    let env_vars = [
        { var: "FBP_CONFIG", description: "Path to config file", default: "~/.config/fbp/config.toml" }
        { var: "FBP_CONFIG_DIR", description: "Config directory", default: "~/.config/fbp" }
        { var: "FBP_OUTPUT_DIR", description: "Default output directory", default: "." }
        { var: "FBP_VERBOSE", description: "Enable verbose output", default: "false" }
        { var: "NO_COLOR", description: "Disable colored output", default: "(not set)" }
    ]

    print "Environment Variables:"
    print ""
    $env_vars | table
}
