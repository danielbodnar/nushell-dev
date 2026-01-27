# custom-command.nu - Examples of well-documented custom commands
#
# Demonstrates proper command definition with:
# - Type annotations
# - Documentation comments
# - Flag handling
# - Error handling
# - Pipeline integration

# Fetch and parse JSON from a URL
#
# Makes an HTTP GET request and returns parsed JSON data.
# Supports authentication, custom headers, and timeout configuration.
#
# Examples:
#   fetch-json https://api.example.com/users
#   fetch-json https://api.example.com/data --timeout 60sec
#   fetch-json $url --headers {Authorization: "Bearer token"}
export def fetch-json [
    url: string                          # The URL to fetch
    --headers: record = {}               # Additional HTTP headers
    --timeout: duration = 30sec          # Request timeout
    --retry: int = 0                     # Number of retry attempts
] -> any {
    mut attempts = 0
    let max_attempts = $retry + 1

    loop {
        try {
            let response = http get $url --headers $headers --max-time $timeout
            return $response
        } catch { |err|
            $attempts = $attempts + 1
            if $attempts >= $max_attempts {
                error make {
                    msg: $"Failed to fetch ($url) after ($max_attempts) attempts"
                    label: {
                        text: "HTTP request failed"
                        span: (metadata $url).span
                    }
                }
            }
            sleep 1sec
        }
    }
}

# Filter and transform table data
#
# Applies common transformations to tabular data:
# selecting columns, filtering rows, and sorting results.
#
# Examples:
#   open data.csv | filter-data --columns [name, email]
#   ls | filter-data --where "size > 1mb" --sort-by size
export def filter-data [
    --columns: list<string> = []         # Columns to select (empty = all)
    --where: string = ""                 # Filter condition
    --sort-by: string = ""               # Column to sort by
    --reverse (-r)                       # Reverse sort order
    --limit: int = 0                     # Max rows (0 = unlimited)
] -> table {
    let input = $in

    # Select columns
    let selected = if ($columns | is-empty) {
        $input
    } else {
        $input | select ...$columns
    }

    # Apply filter (simplified - real implementation would parse condition)
    let filtered = $selected  # TODO: Apply $where condition

    # Sort
    let sorted = if $sort_by != "" {
        if $reverse {
            $filtered | sort-by $sort_by --reverse
        } else {
            $filtered | sort-by $sort_by
        }
    } else {
        $filtered
    }

    # Limit
    if $limit > 0 {
        $sorted | first $limit
    } else {
        $sorted
    }
}

# Convert between data formats
#
# Supports JSON, YAML, TOML, CSV, and Nushell formats.
# Reads from pipeline or file, outputs to stdout or file.
#
# Examples:
#   open data.json | convert-format yaml
#   convert-format json --input data.yaml --output data.json
export def convert-format [
    format: string                       # Target format: json, yaml, toml, csv, nuon
    --input (-i): path                   # Input file (or use pipeline)
    --output (-o): path                  # Output file (or stdout)
    --pretty (-p)                        # Pretty-print output
] {
    # Get input data
    let data = if $input != null {
        open $input
    } else {
        $in
    }

    # Convert to target format
    let converted = match $format {
        "json" => { if $pretty { $data | to json --indent 2 } else { $data | to json } }
        "yaml" => { $data | to yaml }
        "toml" => { $data | to toml }
        "csv" => { $data | to csv }
        "nuon" => { $data | to nuon }
        _ => { error make { msg: $"Unknown format: ($format). Use: json, yaml, toml, csv, nuon" } }
    }

    # Output
    if $output != null {
        $converted | save --force $output
        print $"Saved to ($output)"
    } else {
        $converted
    }
}

# Group command: configuration management
#
# Subcommand group for managing application configuration.

# Get a configuration value
#
# Examples:
#   config get api.url
#   config get timeout --default 30
export def "config get" [
    key: string                          # Configuration key (dot-notation)
    --default: any                       # Default value if not found
    --config-file: path                  # Config file path
] -> any {
    let config_path = $config_file | default ([$nu.home-path, ".config", "myapp", "config.toml"] | path join)

    if not ($config_path | path exists) {
        if $default != null { return $default }
        error make { msg: $"Config file not found: ($config_path)" }
    }

    let config = open $config_path

    # Navigate nested keys
    let parts = $key | split row "."
    mut value = $config

    for part in $parts {
        if ($value | describe) == "record" and ($part in $value) {
            $value = $value | get $part
        } else {
            if $default != null { return $default }
            error make { msg: $"Key not found: ($key)" }
        }
    }

    $value
}

# Set a configuration value
#
# Examples:
#   config set api.url "https://api.example.com"
#   config set timeout 60
export def "config set" [
    key: string                          # Configuration key (dot-notation)
    value: any                           # Value to set
    --config-file: path                  # Config file path
] {
    let config_path = $config_file | default ([$nu.home-path, ".config", "myapp", "config.toml"] | path join)

    # Ensure directory exists
    let config_dir = $config_path | path dirname
    if not ($config_dir | path exists) {
        mkdir $config_dir
    }

    # Load existing or create new
    let config = if ($config_path | path exists) {
        open $config_path
    } else {
        {}
    }

    # Set nested value (simplified - only handles one level)
    let updated = $config | upsert $key $value

    # Save
    $updated | to toml | save --force $config_path
    print $"Set ($key) = ($value | to nuon)"
}
