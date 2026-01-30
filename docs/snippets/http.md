# HTTP & API Snippets

## Basic Requests

### GET Requests

```nushell
# Simple GET (auto-parses JSON)
http get https://api.example.com/users

# Access response fields
http get https://api.example.com/user/1 | get name

# With query parameters
let query = "nushell"
http get $"https://api.github.com/search/repositories?q=($query)&per_page=10"

# Raw response (no parsing)
http get https://example.com/page.html --raw
```

### POST Requests

```nushell
# POST JSON body
http post https://api.example.com/users {
    name: "Alice"
    email: "alice@example.com"
}

# POST with explicit content type
http post --content-type application/json https://api.example.com/data {
    key: "value"
}

# POST form data
http post --content-type application/x-www-form-urlencoded https://api.example.com/form $"username=($user)&password=($pass)"

# POST with empty body and headers
http post https://api.example.com/sync -H {X-API-Key: "secret"} (bytes build)
```

### Other HTTP Methods

```nushell
# PUT - replace resource
http put https://api.example.com/users/1 {name: "Updated Name"}

# PATCH - partial update
http patch https://api.example.com/users/1 {status: "active"}

# DELETE
http delete https://api.example.com/users/1

# HEAD - headers only
http head https://example.com

# OPTIONS
http options https://api.example.com/endpoint
```

---

## Headers and Authentication

### Custom Headers

```nushell
# Single header
http get https://api.example.com/data -H {Accept: "application/json"}

# Multiple headers
http get https://api.example.com/data -H {
    Accept: "application/json"
    X-Request-ID: (random uuid)
    User-Agent: "nushell-client/1.0"
}
```

### Bearer Token Auth

```nushell
http get https://api.example.com/protected -H {
    Authorization: $"Bearer ($env.API_TOKEN)"
}
```

### Basic Auth

```nushell
let auth = [$username, $password] | str join ":" | encode base64
http get https://api.example.com/data -H {
    Authorization: $"Basic ($auth)"
}
```

### API Key Auth

```nushell
# In header
http get https://api.example.com/data -H {
    X-API-Key: $env.API_KEY
}

# In query string
http get $"https://api.example.com/data?api_key=($env.API_KEY)"
```

### OAuth2 Token Refresh

```nushell
def refresh-token [] {
    http post https://oauth.example.com/token -H {
        Content-Type: "application/x-www-form-urlencoded"
    } $"grant_type=refresh_token&refresh_token=($env.REFRESH_TOKEN)&client_id=($env.CLIENT_ID)"
    | get access_token
}
```

---

## Request Configuration

### Timeouts

```nushell
# Set timeout
http get https://api.example.com/slow --max-time 30sec
```

### Redirects

```nushell
# Follow redirects (default)
http get https://example.com --redirect-mode follow

# Don't follow redirects
http get https://example.com --redirect-mode manual
```

### Insecure (skip TLS verification)

```nushell
# Skip certificate verification (development only!)
http get https://localhost:8443/api --insecure
```

---

## Error Handling

### Try-Catch Pattern

```nushell
try {
    http get https://api.example.com/resource
} catch { |err|
    if ($err.msg | str contains "404") {
        print "Resource not found"
        null
    } else if ($err.msg | str contains "429") {
        print "Rate limited"
        null
    } else {
        error make { msg: $"API error: ($err.msg)" }
    }
}
```

### Retry with Backoff

```nushell
def fetch-with-retry [url: string, --max-retries: int = 3] {
    mut delay = 1sec

    for attempt in 1..=$max_retries {
        try {
            return (http get $url)
        } catch { |err|
            if $attempt == $max_retries {
                error make { msg: $"Failed after ($max_retries) attempts: ($err.msg)" }
            }

            print $"Attempt ($attempt) failed, retrying in ($delay)..."
            sleep $delay
            $delay = $delay * 2
        }
    }
}
```

### Validate Response

```nushell
def safe-fetch [url: string] {
    let response = http get $url

    if ($response | describe) == "nothing" {
        error make { msg: "Empty response" }
    }

    if ($response.error? != null) {
        error make { msg: $"API error: ($response.error)" }
    }

    $response
}
```

---

## Pagination

### Offset-Based Pagination

```nushell
def fetch-all-pages [base_url: string, --page-size: int = 100] {
    mut all_items = []
    mut offset = 0

    loop {
        let url = $"($base_url)?limit=($page_size)&offset=($offset)"
        let response = http get $url
        let items = $response | get items

        if ($items | is-empty) {
            break
        }

        $all_items = $all_items ++ $items

        if ($items | length) < $page_size {
            break
        }

        $offset = $offset + $page_size
        sleep 100ms  # Rate limiting
    }

    $all_items
}
```

### Cursor-Based Pagination

```nushell
def fetch-with-cursor [base_url: string] {
    mut all_items = []
    mut cursor: string = ""

    loop {
        let url = if ($cursor | is-empty) {
            $base_url
        } else {
            $"($base_url)?cursor=($cursor)"
        }

        let response = http get $url
        $all_items = $all_items ++ ($response | get data)

        if ($response | get has_more) == false {
            break
        }

        $cursor = $response | get next_cursor
    }

    $all_items
}
```

### Page Number Pagination

```nushell
def fetch-pages [base_url: string, total_pages: int] {
    1..$total_pages | each { |page|
        print $"Fetching page ($page)..."
        let result = http get $"($base_url)?page=($page)"
        sleep 100ms
        $result
    } | flatten
}
```

---

## API Clients

### Reusable API Client

```nushell
# GitHub API client
def github-api [
    endpoint: string
    --method: string = "GET"
    --body: any = null
] {
    let base = "https://api.github.com"
    let headers = {
        Accept: "application/vnd.github.v3+json"
        Authorization: $"Bearer ($env.GITHUB_TOKEN)"
        User-Agent: "nushell-client"
    }

    match $method {
        "GET" => { http get $"($base)($endpoint)" -H $headers }
        "POST" => { http post $"($base)($endpoint)" $body -H $headers }
        "PUT" => { http put $"($base)($endpoint)" $body -H $headers }
        "PATCH" => { http patch $"($base)($endpoint)" $body -H $headers }
        "DELETE" => { http delete $"($base)($endpoint)" -H $headers }
        _ => { error make { msg: $"Unknown method: ($method)" } }
    }
}

# Usage
github-api "/user/repos" | select name description stargazers_count
github-api "/repos/nushell/nushell/issues" --method POST --body {title: "Bug report", body: "Details..."}
```

### Generic REST Client

```nushell
def rest-client [base_url: string, token?: string] {
    {
        base_url: $base_url
        headers: (if $token != null {
            {Authorization: $"Bearer ($token)"}
        } else {
            {}
        })
    }
}

def "rest get" [client: record, path: string] {
    http get $"($client.base_url)($path)" -H $client.headers
}

def "rest post" [client: record, path: string, body: any] {
    http post $"($client.base_url)($path)" $body -H $client.headers
}

# Usage
let api = rest-client "https://api.example.com" $env.API_TOKEN
rest get $api "/users"
rest post $api "/users" {name: "Alice"}
```

---

## Webhooks

### Send Webhook Notification

```nushell
# Slack webhook
def notify-slack [message: string, --channel: string = "#general"] {
    http post $env.SLACK_WEBHOOK_URL {
        channel: $channel
        text: $message
        username: "Nushell Bot"
        icon_emoji: ":robot_face:"
    }
}

# Discord webhook
def notify-discord [message: string] {
    http post $env.DISCORD_WEBHOOK_URL {
        content: $message
    }
}
```

### Parse Webhook Payload

```nushell
def handle-github-webhook [payload: string] {
    let data = $payload | from json
    let event = $data.action

    match $event {
        "opened" => { handle-pr-opened $data }
        "closed" => { handle-pr-closed $data }
        "synchronize" => { handle-pr-updated $data }
        _ => { print $"Unknown event: ($event)" }
    }
}
```

---

## Parallel Requests

### Concurrent Fetches

```nushell
# Fetch multiple URLs in parallel
let urls = [
    "https://api.example.com/users"
    "https://api.example.com/products"
    "https://api.example.com/orders"
]

$urls | par-each { |url|
    {url: $url, data: (http get $url)}
}
```

### Batch Requests with Rate Limiting

```nushell
def fetch-batch [urls: list<string>, --batch-size: int = 10, --delay: duration = 1sec] {
    $urls
    | chunks $batch_size
    | each { |batch|
        let results = $batch | par-each { |url|
            try {
                {url: $url, data: (http get $url), error: null}
            } catch { |e|
                {url: $url, data: null, error: $e.msg}
            }
        }
        sleep $delay  # Pause between batches
        $results
    }
    | flatten
}
```

---

## Common APIs

### GitHub

```nushell
# List repos
http get "https://api.github.com/users/nushell/repos" -H {Accept: "application/vnd.github.v3+json"}
| select name description stargazers_count

# Search code
http get "https://api.github.com/search/code?q=language:nushell" -H {Authorization: $"Bearer ($env.GITHUB_TOKEN)"}
```

### JSONPlaceholder (Testing)

```nushell
# Get posts
http get https://jsonplaceholder.typicode.com/posts | first 5

# Create post
http post https://jsonplaceholder.typicode.com/posts {
    title: "Test Post"
    body: "This is a test"
    userId: 1
}
```

### Weather API

```nushell
def get-weather [city: string] {
    http get $"https://wttr.in/($city)?format=j1"
    | get current_condition.0
    | select temp_C humidity weatherDesc
}
```
