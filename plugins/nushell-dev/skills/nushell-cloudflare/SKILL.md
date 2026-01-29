---
name: nushell-cloudflare
description: This skill should be used when the user asks to "use Cloudflare from Nushell", "deploy Workers", "access R2 storage", "work with KV", "manage D1 database", "use Cloudflare Queues", "create Durable Objects", "run wrangler commands", "call Cloudflare API", or mentions Cloudflare Workers, R2, KV, D1, Queues, Workflows, or Durable Objects in a Nushell context.
version: 1.0.0
---

# Nushell Cloudflare Integration

Complete guide for integrating Nushell with Cloudflare services. Covers API access, wrangler CLI integration, and patterns for Workers, R2, KV, D1, Queues, and Durable Objects.

## Authentication

### API Token Setup

```nushell
# Set credentials in environment
$env.CLOUDFLARE_API_TOKEN = "your-api-token"
$env.CLOUDFLARE_ACCOUNT_ID = "your-account-id"

# Or load from file
$env.CLOUDFLARE_API_TOKEN = (open ~/.cloudflare/token | str trim)
```

### API Client Base

```nushell
# Cloudflare API client
def cf-api [
    endpoint: string
    --method: string = "GET"
    --body: any = null
] {
    let base = "https://api.cloudflare.com/client/v4"
    let headers = {
        Authorization: $"Bearer ($env.CLOUDFLARE_API_TOKEN)"
        Content-Type: "application/json"
    }

    let url = $"($base)($endpoint)"

    let response = match $method {
        "GET" => { http get $url -H $headers }
        "POST" => { http post $url $body -H $headers }
        "PUT" => { http put $url $body -H $headers }
        "DELETE" => { http delete $url -H $headers }
    }

    if not $response.success {
        error make {
            msg: $"Cloudflare API error: ($response.errors | to json)"
        }
    }

    $response.result
}
```

## Wrangler CLI Integration

### Setup and Config

```nushell
# Verify wrangler installation
^wrangler --version

# Login (interactive)
^wrangler login

# Check auth status
^wrangler whoami
```

### Worker Management

```nushell
# List workers
def "cf workers list" [] {
    ^wrangler deployments list --json
    | from json
}

# Deploy worker
def "cf workers deploy" [path?: path] {
    let dir = $path | default "."
    cd $dir
    ^wrangler deploy
}

# Tail worker logs
def "cf workers tail" [name: string] {
    ^wrangler tail $name --format json
    | lines
    | each { |line| $line | from json }
}

# View worker details
def "cf workers get" [name: string] {
    cf-api $"/accounts/($env.CLOUDFLARE_ACCOUNT_ID)/workers/scripts/($name)"
}
```

### Worker Development

```nushell
# Start dev server
def "cf workers dev" [--port: int = 8787] {
    ^wrangler dev --port $port
}

# Generate new worker
def "cf workers new" [name: string, --template: string = "hello-world"] {
    ^wrangler init $name --template $template
}
```

## R2 Object Storage

### Bucket Operations

```nushell
# List buckets
def "cf r2 buckets" [] {
    cf-api $"/accounts/($env.CLOUDFLARE_ACCOUNT_ID)/r2/buckets"
}

# Create bucket
def "cf r2 create-bucket" [name: string] {
    cf-api $"/accounts/($env.CLOUDFLARE_ACCOUNT_ID)/r2/buckets" --method POST --body {name: $name}
}

# Delete bucket
def "cf r2 delete-bucket" [name: string] {
    cf-api $"/accounts/($env.CLOUDFLARE_ACCOUNT_ID)/r2/buckets/($name)" --method DELETE
}
```

### Object Operations with Wrangler

```nushell
# List objects
def "cf r2 list" [bucket: string, --prefix: string = ""] {
    ^wrangler r2 object list $bucket --prefix $prefix --json
    | from json
}

# Upload file
def "cf r2 put" [bucket: string, key: string, file: path] {
    ^wrangler r2 object put $"($bucket)/($key)" --file $file
}

# Download file
def "cf r2 get" [bucket: string, key: string, --output: path] {
    let out = $output | default $key
    ^wrangler r2 object get $"($bucket)/($key)" --file $out
}

# Delete object
def "cf r2 delete" [bucket: string, key: string] {
    ^wrangler r2 object delete $"($bucket)/($key)"
}
```

### R2 Sync Pattern

```nushell
# Sync local directory to R2
def "cf r2 sync" [local_dir: path, bucket: string, --prefix: string = ""] {
    ls $local_dir | each { |file|
        let key = if $prefix == "" { $file.name } else { $"($prefix)/($file.name)" }
        print $"Uploading: ($file.name) -> ($key)"
        cf r2 put $bucket $key $file.name
    }
}
```

## KV Namespace

### Namespace Management

```nushell
# List namespaces
def "cf kv namespaces" [] {
    cf-api $"/accounts/($env.CLOUDFLARE_ACCOUNT_ID)/storage/kv/namespaces"
}

# Create namespace
def "cf kv create-namespace" [title: string] {
    cf-api $"/accounts/($env.CLOUDFLARE_ACCOUNT_ID)/storage/kv/namespaces" --method POST --body {title: $title}
}
```

### Key-Value Operations

```nushell
# Get value
def "cf kv get" [namespace_id: string, key: string] {
    ^wrangler kv key get --namespace-id $namespace_id $key
}

# Put value
def "cf kv put" [namespace_id: string, key: string, value: string] {
    ^wrangler kv key put --namespace-id $namespace_id $key $value
}

# List keys
def "cf kv list" [namespace_id: string, --prefix: string = ""] {
    ^wrangler kv key list --namespace-id $namespace_id --prefix $prefix --json
    | from json
}

# Delete key
def "cf kv delete" [namespace_id: string, key: string] {
    ^wrangler kv key delete --namespace-id $namespace_id $key
}

# Bulk operations
def "cf kv bulk-put" [namespace_id: string, data: list] {
    # data: [{key: "k1", value: "v1"}, {key: "k2", value: "v2"}]
    $data | to json | save --force /tmp/kv-bulk.json
    ^wrangler kv bulk put --namespace-id $namespace_id /tmp/kv-bulk.json
    rm /tmp/kv-bulk.json
}
```

## D1 Database

### Database Management

```nushell
# List databases
def "cf d1 list" [] {
    ^wrangler d1 list --json | from json
}

# Create database
def "cf d1 create" [name: string] {
    ^wrangler d1 create $name --json | from json
}

# Get database info
def "cf d1 info" [name: string] {
    ^wrangler d1 info $name --json | from json
}
```

### Query Operations

```nushell
# Execute SQL
def "cf d1 query" [database: string, sql: string] {
    ^wrangler d1 execute $database --command $sql --json
    | from json
}

# Execute from file
def "cf d1 execute-file" [database: string, file: path] {
    ^wrangler d1 execute $database --file $file --json
    | from json
}

# Migrations
def "cf d1 migrate" [database: string, --dir: path = "./migrations"] {
    ls $dir | sort-by name | each { |f|
        print $"Running migration: ($f.name)"
        cf d1 execute-file $database $f.name
    }
}
```

### D1 Query Builder

```nushell
# Simple query builder
def "cf d1 select" [
    database: string
    table: string
    --columns: list<string> = ["*"]
    --where: string = ""
    --order-by: string = ""
    --limit: int = 100
] {
    let cols = $columns | str join ", "
    mut sql = $"SELECT ($cols) FROM ($table)"

    if $where != "" {
        $sql = $"($sql) WHERE ($where)"
    }
    if $order_by != "" {
        $sql = $"($sql) ORDER BY ($order_by)"
    }
    $sql = $"($sql) LIMIT ($limit)"

    cf d1 query $database $sql
}
```

## Queues

### Queue Management

```nushell
# List queues
def "cf queues list" [] {
    cf-api $"/accounts/($env.CLOUDFLARE_ACCOUNT_ID)/queues"
}

# Create queue
def "cf queues create" [name: string] {
    cf-api $"/accounts/($env.CLOUDFLARE_ACCOUNT_ID)/queues" --method POST --body {queue_name: $name}
}

# Delete queue
def "cf queues delete" [name: string] {
    cf-api $"/accounts/($env.CLOUDFLARE_ACCOUNT_ID)/queues/($name)" --method DELETE
}
```

### Message Operations

```nushell
# Send message to queue (via Worker)
def "cf queues send" [queue_binding: string, message: any] {
    # This would typically be done through a Worker binding
    # Here's an example of calling a Worker endpoint that sends to queue
    http post $"https://your-worker.workers.dev/queue/($queue_binding)" $message
}
```

## Durable Objects

Durable Objects require Worker deployment. Here are patterns for managing them:

```nushell
# Create Worker with Durable Object
def "cf do create-worker" [name: string] {
    # Generate wrangler.toml with DO binding
    let config = {
        name: $name
        main: "src/index.ts"
        compatibility_date: (date now | format date "%Y-%m-%d")
        durable_objects: {
            bindings: [
                {name: "MY_DO", class_name: "MyDurableObject"}
            ]
        }
        migrations: [
            {tag: "v1", new_classes: ["MyDurableObject"]}
        ]
    }

    $config | to toml | save wrangler.toml
}
```

## Workflows

### Workflow Patterns

```nushell
# Deploy workflow
def "cf workflows deploy" [--name: string] {
    ^wrangler deploy --name $name
}

# Trigger workflow (via HTTP)
def "cf workflows trigger" [worker_url: string, payload: any] {
    http post $worker_url $payload -H {
        Authorization: $"Bearer ($env.CLOUDFLARE_API_TOKEN)"
    }
}
```

## Utility Functions

### Account Info

```nushell
# Get account details
def "cf account" [] {
    cf-api "/accounts" | where id == $env.CLOUDFLARE_ACCOUNT_ID | first
}

# List zones
def "cf zones" [] {
    cf-api "/zones"
}
```

### Cost Tracking

```nushell
# Get usage metrics
def "cf usage" [--days: int = 30] {
    let end = date now | format date "%Y-%m-%dT%H:%M:%SZ"
    let start = (date now) - ($days * 1day) | format date "%Y-%m-%dT%H:%M:%SZ"

    cf-api $"/accounts/($env.CLOUDFLARE_ACCOUNT_ID)/analytics/workers/usage?since=($start)&until=($end)"
}
```

## Best Practices

1. **Use environment variables** for tokens, never hardcode
2. **Prefer wrangler** for complex operations (handles auth, retries)
3. **Use local dev** (`wrangler dev`) before deploying
4. **Implement retries** for API calls
5. **Monitor usage** to avoid unexpected costs
6. **Use KV for sessions**, D1 for relational data, R2 for files

## Additional Resources

### Reference Files

For detailed patterns:
- **`references/wrangler-config.md`** - wrangler.toml patterns
- **`references/worker-templates.md`** - Common Worker patterns

### Example Files

Working examples in `examples/`:
- **`worker-deploy.nu`** - Full deployment workflow
- **`r2-backup.nu`** - Backup local files to R2
- **`d1-migration.nu`** - Database migration script
