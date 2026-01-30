# Nushell Configuration Reference

> Generated from `config nu --doc` for Nushell v0.110.0
> See https://nushell.sh/book/configuration for complete documentation

## Overview

Nushell configuration is primarily managed through the `$env.config` record in your `config.nu` file. The configuration file is located at:
- **Linux/macOS**: `~/.config/nushell/config.nu`
- **Windows**: `%APPDATA%\nushell\config.nu`

When setting configuration values, update individual keys rather than replacing the entire `$env.config` record, as Nushell merges missing keys with internal defaults.

---

## History Settings

### File Format

```nushell
# "sqlite": SQLite database with timestamps and metadata
# "plaintext": One command per line, no metadata
$env.config.history.file_format = "plaintext"  # Default
```

### History Size

```nushell
# Maximum entries before oldest are removed
$env.config.history.max_size = 100_000  # Default
```

### Sync Behavior

```nushell
# Write to history after each command (plaintext only; SQLite always syncs)
$env.config.history.sync_on_enter = true  # Default
```

### Session Isolation

```nushell
# Isolate history between concurrent sessions (SQLite only)
# When true, Up/Down won't show commands from other open shells
$env.config.history.isolation = false  # Default
```

---

## Editor Settings

### Edit Mode

```nushell
# "emacs": Emacs-style keybindings (default)
# "vi": Vi-style with normal/insert modes
$env.config.edit_mode = "emacs"  # Default
```

### External Editor

```nushell
# Editor for Ctrl+O (edit current line in external editor)
# null: Use $VISUAL, then $EDITOR, then fallback
$env.config.buffer_editor = null  # Default

# With arguments:
$env.config.buffer_editor = ["vim", "-p"]
$env.config.buffer_editor = ["emacsclient", "-s", "light", "-t"]
```

### Cursor Shapes

```nushell
# Options: "block", "underscore", "line", "blink_block",
#          "blink_underscore", "blink_line", "inherit"
$env.config.cursor_shape.emacs = "inherit"      # Default
$env.config.cursor_shape.vi_insert = "inherit"  # Default
$env.config.cursor_shape.vi_normal = "inherit"  # Default
```

---

## Completion Settings

### Hints

```nushell
# Show inline completion hints as you type
$env.config.show_hints = true  # Default
```

### Algorithm

```nushell
# "prefix": Match from beginning
# "substring": Match anywhere
# "fuzzy": Fuzzy matching
$env.config.completions.algorithm = "prefix"  # Default
```

### Sorting

```nushell
# "smart": Depends on algorithm (prefix/substring = alphabetical, fuzzy = score)
# "alphabetical": Always alphabetical
$env.config.completions.sort = "smart"  # Default
```

### Case Sensitivity

```nushell
$env.config.completions.case_sensitive = false  # Default
```

### Auto-Select

```nushell
# Auto-select when only one completion remains
$env.config.completions.quick = true  # Default
```

### Partial Completion

```nushell
# Partially complete to longest common prefix
$env.config.completions.partial = true  # Default
```

### External Commands

```nushell
# Include external commands from PATH in completions
$env.config.completions.external.enable = true  # Default

# Maximum external commands to retrieve
$env.config.completions.external.max_results = 100  # Default

# Custom completer closure (e.g., for Carapace)
$env.config.completions.external.completer = null  # Default

# Example Carapace integration:
$env.config.completions.external.completer = {|spans|
    carapace $spans.0 nushell ...$spans | from json
}
```

### LS Colors in Completions

```nushell
# Apply LS_COLORS to file/path completions
$env.config.completions.use_ls_colors = true  # Default
```

---

## Display Settings

### Banner

```nushell
# true | "full": Show full banner with Ellie
# "short": Abbreviated banner with startup time
# false | "none": No banner
$env.config.show_banner = true  # Default
```

### ANSI Coloring

```nushell
# "auto": Detect based on FORCE_COLOR, NO_COLOR, CLICOLOR, or if stdout is terminal
# true: Always enable
# false: Disable (default foreground only)
$env.config.use_ansi_coloring = "auto"  # Default
```

### Float Precision

```nushell
# Decimal places for float values in output
$env.config.float_precision = 2  # Default
```

---

## Table Display

### Mode (Border Style)

```nushell
# Options: "rounded", "basic", "compact", "compact_double", "light",
#          "thin", "with_love", "reinforced", "heavy", "none", "psql",
#          "markdown", "dots", "restructured", "ascii_rounded",
#          "basic_compact", "single", "double"
$env.config.table.mode = "rounded"  # Default
```

### Index Column

```nushell
# "always": Always show
# "never": Never show
# "auto": Show only when explicit "index" column exists
$env.config.table.index_mode = "always"  # Default
```

### Footer

```nushell
# "always", "never", "auto", or (int) for row threshold
$env.config.footer_mode = 25  # Default
```

### Empty Tables

```nushell
# Show "empty list"/"empty record" for empty values
$env.config.table.show_empty = true  # Default
```

### Cell Padding

```nushell
$env.config.table.padding.left = 1   # Default
$env.config.table.padding.right = 1  # Default
```

### Content Trimming

```nushell
# methodology: "wrapping" or "truncating"
$env.config.table.trim = {
    methodology: "wrapping"
    wrapping_try_keep_words: true
}  # Default

# Truncating example:
$env.config.table.trim = {
    methodology: "truncating"
    truncating_suffix: "..."
}
```

### Headers on Separator

```nushell
# Embed headers in top/bottom border
$env.config.table.header_on_separator = false  # Default
```

### Abbreviated Tables

```nushell
# Show first N and last N rows with ellipsis (null = all rows)
$env.config.table.abbreviated_row_count = null  # Default
```

### Missing Values

```nushell
$env.config.table.missing_value_symbol = "❎"  # Default
```

### Streaming

```nushell
# Wait time before showing streaming batch
$env.config.table.batch_duration = 1sec  # Default

# Max items per batch
$env.config.table.stream_page_size = 1000  # Default
```

---

## Date/Time Display

```nushell
# null: Humanize ("now", "a day ago")
# string: Format string (see `into datetime --list` for specifiers)
$env.config.datetime_format.table = null   # In tables (default)
$env.config.datetime_format.normal = null  # Raw output (default)
```

---

## Filesize Display

```nushell
# "metric": Auto-scale (kB, MB, GB)
# "binary": Auto-scale (KiB, MiB, GiB)
# Fixed: "B", "kB", "KB", "MB", "MiB", "GB", "GiB", "TB", "TiB", "PB", "PiB", "EB", "EiB"
$env.config.filesize.unit = "metric"  # Default

# Show unit suffix
$env.config.filesize.show_unit = true  # Default

# Decimal places (null = all significant)
$env.config.filesize.precision = 1  # Default
```

---

## Error Display

### Error Style

```nushell
# "fancy": Line-drawing characters pointing to error span
# "plain": Plain text (screen-reader friendly)
# "short": Single-line concise messages
# "nested": Fancy with nesting for related errors
$env.config.error_style = "fancy"  # Default
```

### Exit Code Errors

```nushell
# Show Nushell error when external command returns non-zero
$env.config.display_errors.exit_code = false  # Default
```

### Signal Termination Errors

```nushell
# Show error when child process terminated by signal
$env.config.display_errors.termination_signal = true  # Default
```

### Context Lines

```nushell
# Number of context lines in error output
$env.config.error_lines = 1  # Default
```

---

## Terminal Integration

### Kitty Protocol

```nushell
# Enable Kitty keyboard enhancement (Kitty, WezTerm, etc.)
# Enables additional keybindings (e.g., Ctrl+I vs Tab)
$env.config.use_kitty_protocol = false  # Default
```

### Bracketed Paste

```nushell
# Allow pasting multiple lines without immediate execution
$env.config.bracketed_paste = true  # Default
```

### Shell Integration (OSC Sequences)

```nushell
# OSC 2: Set window/tab title
$env.config.shell_integration.osc2 = true  # Default

# OSC 7: Report current directory (new tabs open same dir)
$env.config.shell_integration.osc7 = ($nu.os-info.name != windows)

# OSC 8: Clickable links in ls output
$env.config.shell_integration.osc8 = true  # Default

# OSC 9;9: ConEmu/Windows Terminal current path
$env.config.shell_integration.osc9_9 = ($nu.os-info.name == windows)

# OSC 133: Prompt markers (collapsible output, prompt scrolling)
$env.config.shell_integration.osc133 = true  # Default

# OSC 633: VS Code shell integration
$env.config.shell_integration.osc633 = true  # Default

# Reset application mode for SSH cursor keys
$env.config.shell_integration.reset_application_mode = true  # Default
```

---

## Miscellaneous

### Trash vs Permanent Delete

```nushell
# true: rm uses trash by default
# false: rm permanently deletes by default
$env.config.rm.always_trash = false  # Default
```

### Recursion Limit

```nushell
# Max recursive calls before error
$env.config.recursion_limit = 50  # Default
```

### Right Prompt Position

```nushell
# With multi-line left prompt:
# true: Right prompt on last line
# false: Right prompt on first line
$env.config.render_right_prompt_on_last_line = false  # Default
```

### External Command Highlighting

```nushell
# Highlight confirmed external commands differently
$env.config.highlight_resolved_externals = false  # Default
```

### LS Colors

```nushell
# Apply LS_COLORS to ls output
$env.config.ls.use_ls_colors = true  # Default

# Clickable links (now controlled by shell_integration.osc8)
$env.config.ls.clickable_links = true  # Default
```

---

## Hooks

Hooks run code at specific shell events. They accept strings (code), closures, or lists thereof.

### Pre-Prompt Hook

```nushell
# Run before each prompt is displayed
$env.config.hooks.pre_prompt = []  # Default

# Example:
$env.config.hooks.pre_prompt = [
    { print "Ready for input!" }
]
```

### Pre-Execution Hook

```nushell
# Run after Enter, before command execution
$env.config.hooks.pre_execution = []  # Default
```

### Environment Change Hook

```nushell
# Run when specific env vars change
$env.config.hooks.env_change = {}  # Default

# Example:
$env.config.hooks.env_change = {
    PWD: [{|before, after| print $"Changed from ($before) to ($after)"}]
}
```

### Display Output Hook

```nushell
# Process output before display (WARNING: can suppress all output if malformed)
$env.config.hooks.display_output = "if (term size).columns >= 100 { table -e } else { table }"
```

### Command Not Found Hook

```nushell
# Suggest packages or handle missing commands
$env.config.hooks.command_not_found = null  # Default
```

---

## Keybindings

```nushell
$env.config.keybindings = []  # Default

# Example: Alt+. to insert last token from previous command
$env.config.keybindings ++= [
    {
        name: insert_last_token
        modifier: alt
        keycode: char_.
        mode: [emacs vi_normal vi_insert]
        event: [
            { edit: InsertString, value: "!$" }
            { send: Enter }
        ]
    }
]
```

---

## Menus

```nushell
$env.config.menus = []  # Default

# Example completion menu:
$env.config.menus ++= [{
    name: completion_menu
    only_buffer_difference: false
    marker: "| "
    type: {
        layout: columnar
        columns: 4
        col_width: 20
        col_padding: 2
    }
    style: {
        text: green
        selected_text: green_reverse
        description_text: yellow
    }
}]
```

---

## Plugins

### Plugin Configuration

```nushell
# Per-plugin settings (keys must match registered plugin names)
$env.config.plugins = {}  # Default
```

### Plugin Garbage Collection

```nushell
# Stop inactive plugins automatically
$env.config.plugin_gc.default.enabled = true  # Default

# Time before stopping inactive plugins
$env.config.plugin_gc.default.stop_after = 10sec  # Default

# Per-plugin overrides
$env.config.plugin_gc.plugins = {}  # Default

# Example: Disable GC for specific plugin
$env.config.plugin_gc.plugins = {
    gstat: { enabled: false }
}
```

---

## Color Configuration

Colors can be specified as:
- Color names: `"red"`, `"green"`, `"blue"` (see `ansi -l`)
- RGB hex: `"#C4C9C6"`
- Records with attributes:
  ```nushell
  {
      fg: "red"
      bg: "white"
      attr: "bu"  # b=bold, u=underline, i=italic, r=reverse, d=dim, n=normal
  }
  ```

### Using Themes

```nushell
# Standard library themes
use std/config dark-theme
$env.config.color_config = (dark-theme)

# Community themes: https://github.com/nushell/nu_scripts/tree/main/themes
```

### Syntax Highlighting (Shapes)

```nushell
$env.config.color_config.shape_string = "green"
$env.config.color_config.shape_string_interpolation = "cyan_bold"
$env.config.color_config.shape_raw_string = "light_purple"
$env.config.color_config.shape_record = "cyan_bold"
$env.config.color_config.shape_list = "cyan_bold"
$env.config.color_config.shape_table = "blue_bold"
$env.config.color_config.shape_bool = "light_cyan"
$env.config.color_config.shape_int = "purple_bold"
$env.config.color_config.shape_float = "purple_bold"
$env.config.color_config.shape_range = "yellow_bold"
$env.config.color_config.shape_binary = "purple_bold"
$env.config.color_config.shape_datetime = "cyan_bold"
$env.config.color_config.shape_nothing = "light_cyan"
$env.config.color_config.shape_operator = "yellow"
$env.config.color_config.shape_filepath = "cyan"
$env.config.color_config.shape_directory = "cyan"
$env.config.color_config.shape_globpattern = "cyan_bold"
$env.config.color_config.shape_variable = "purple"
$env.config.color_config.shape_vardecl = "purple"
$env.config.color_config.shape_pipe = "purple_bold"
$env.config.color_config.shape_internalcall = "cyan_bold"
$env.config.color_config.shape_external = "cyan"
$env.config.color_config.shape_external_resolved = "light_yellow_bold"
$env.config.color_config.shape_externalarg = "green_bold"
$env.config.color_config.shape_flag = "blue_bold"
$env.config.color_config.shape_block = "blue_bold"
$env.config.color_config.shape_closure = "green_bold"
$env.config.color_config.shape_signature = "green_bold"
$env.config.color_config.shape_redirection = "purple_bold"
$env.config.color_config.shape_garbage = { fg: "default", bg: "red", attr: "b" }
$env.config.color_config.shape_matching_brackets = { attr: "u" }
```

### Output Type Colors

```nushell
$env.config.color_config.bool = "light_cyan"
$env.config.color_config.int = "default"
$env.config.color_config.string = "default"
$env.config.color_config.float = "default"
$env.config.color_config.datetime = "purple"
$env.config.color_config.filesize = "cyan"
$env.config.color_config.duration = "default"
$env.config.color_config.binary = "default"
$env.config.color_config.glob = "cyan_bold"
$env.config.color_config.closure = "green_bold"

# Dynamic styling with closures:
$env.config.color_config.bool = {||
    if $in { { fg: 'green', attr: 'b' } } else { { fg: 'red' } }
}
```

### UI Element Colors

```nushell
$env.config.color_config.hints = "dark_gray"
$env.config.color_config.search_result = { bg: "red", fg: "default" }
$env.config.color_config.header = "green_bold"
$env.config.color_config.separator = "default"
$env.config.color_config.row_index = "green_bold"
$env.config.color_config.empty = "blue"
$env.config.color_config.leading_trailing_space_bg = { attr: "n" }
```

### Banner Colors

```nushell
$env.config.color_config.banner_foreground = "attr_normal"
$env.config.color_config.banner_highlight1 = "green"
$env.config.color_config.banner_highlight2 = "purple"
```

---

## Explore Command

```nushell
$env.config.explore = {}  # Default

# Full configuration example:
$env.config.explore = {
    status_bar_background: { fg: "#1D1F21", bg: "#C4C9C6" }
    command_bar_text: { fg: "#C4C9C6" }
    highlight: { fg: "black", bg: "yellow" }
    status: {
        error: { fg: "white", bg: "red" }
        warn: {}
        info: {}
    }
    selected_cell: { bg: light_blue }
    config: { cursor_color: 'red' }
    table: {
        selected_cell: { bg: 'blue' }
        show_cursor: false
    }
    try: { reactive: true }
}
```

---

## Environment Variables

These are environment variables (not `$env.config` settings) that affect Nushell.

### Prompt Variables

```nushell
# Main prompt (accepts string or closure)
$env.PROMPT_COMMAND = {||
    let dir = match (do -i { $env.PWD | path relative-to $nu.home-dir }) {
        null => $env.PWD
        '' => '~'
        $relative_pwd => ([~ $relative_pwd] | path join)
    }
    let path_color = (if (is-admin) { ansi red_bold } else { ansi green_bold })
    let separator_color = (if (is-admin) { ansi light_red_bold } else { ansi light_green_bold })
    $"($path_color)($dir)(ansi reset)" | str replace --all (char path_sep) $"($separator_color)(char path_sep)($path_color)"
}

# Right-aligned prompt
$env.PROMPT_COMMAND_RIGHT = {||
    let time = (date now | format date '%x %X')
    let exit = if ($env.LAST_EXIT_CODE != 0) { $"(ansi rb)($env.LAST_EXIT_CODE) " } else { "" }
    $"($exit)(ansi magenta)($time)"
}

# Prompt indicators
$env.PROMPT_INDICATOR = "> "
$env.PROMPT_INDICATOR_VI_NORMAL = "> "
$env.PROMPT_INDICATOR_VI_INSERT = ": "
$env.PROMPT_MULTILINE_INDICATOR = "::: "
```

### Transient Prompts

Replace the prompt after command execution (useful for cleaner scrollback):

```nushell
$env.TRANSIENT_PROMPT_COMMAND = "🚀 "
$env.TRANSIENT_PROMPT_INDICATOR = ""
$env.TRANSIENT_PROMPT_INDICATOR_VI_INSERT = ""
$env.TRANSIENT_PROMPT_INDICATOR_VI_NORMAL = ""
$env.TRANSIENT_PROMPT_MULTILINE_INDICATOR = ""
$env.TRANSIENT_PROMPT_COMMAND_RIGHT = ""
```

### Environment Conversions

```nushell
# Convert env vars to/from Nushell types
$env.ENV_CONVERSIONS = {}  # Default

# Example: Convert XDG_DATA_DIRS to/from list
$env.ENV_CONVERSIONS = $env.ENV_CONVERSIONS | merge {
    "XDG_DATA_DIRS": {
        from_string: { |s| $s | split row (char esep) | path expand --no-symlink }
        to_string: { |v| $v | path expand --no-symlink | str join (char esep) }
    }
}
```

### Library Directories

```nushell
# Directories for `use` and `source` commands
const NU_LIB_DIRS = [
    ($nu.default-config-dir | path join 'scripts')
    ($nu.data-dir | path join 'completions')
]

# Plugin binary directories
const NU_PLUGIN_DIRS = [
    ($nu.default-config-dir | path join 'plugins')
]
```

### PATH Manipulation

```nushell
# PATH is automatically converted to a list before config.nu loads

# Append to PATH
$env.PATH ++= ["~/.local/bin"]

# Prepend to PATH
$env.PATH = ["~/.local/bin"] ++ $env.PATH

# Using std library
use std/util "path add"
path add "~/.local/bin"
path add ($env.CARGO_HOME | path join "bin")

# Remove duplicates
$env.PATH = ($env.PATH | uniq)
```

---

## Quick Reference

| Setting | Default | Description |
|---------|---------|-------------|
| `history.file_format` | `"plaintext"` | History storage format |
| `history.max_size` | `100_000` | Max history entries |
| `edit_mode` | `"emacs"` | Editor keybindings |
| `completions.algorithm` | `"prefix"` | Completion matching |
| `table.mode` | `"rounded"` | Table border style |
| `show_banner` | `true` | Show startup banner |
| `error_style` | `"fancy"` | Error display format |
| `rm.always_trash` | `false` | Use trash by default |
