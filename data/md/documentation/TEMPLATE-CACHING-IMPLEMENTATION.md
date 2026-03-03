# Template Caching & Content Routing System

## Overview

This document describes the template caching layer and intelligent request routing
system for Protocol-7 web-zenka. These modules connect the existing template
processing infrastructure with content scanning, smart routing, and TTL-aware caching.

## Architecture

```
HTTP Request
    |
    v
+------------------+
| Route Dispatcher |  httpsd.route_template_request
|  (ACME→API→Tmpl) |
+--------+---------+
         |
    +----+----+-----+-------+
    |         |             |
    v         v             v
+-------+ +-------+ +-------------+
| ACME  | |  API  | |  Template   |  httpd.vhost_template_resolver
| Handler| | Handler| |   Handler   |
+-------+ +-------+ +------+------+
                            |
                    +-------v--------+
                    | Content Index  |  web.scan_content_directories
                    | (3-level tree) |
                    +-------+--------+
                            |
                    +-------v--------+
                    | Template Cache |  web.template_cache.get/set
                    |   (TTL-based)  |
                    +-------+--------+
                            |
                    +-------v--------+
                    |    Renderer    |  web.process_template_recursive
                    |  (<[...]> cmds) |
                    +----------------+
```

## Modules

### 1. web.scan_content_directories

Recursively scans content directories and builds an index of files with their
template associations.

**Purpose:**
- Discover all content files in a vhost directory
- Check for template files at 3 hierarchy levels
- Cache results for fast lookup

**Location:** `modules/web.scan_content_directories`

**Parameters:**
```perl
my $result = <[web.scan_content_directories]>->($base_dir, $vhost);
```

| Parameter | Type   | Default                | Description                |
|-----------|--------|------------------------|----------------------------|
| base_dir  | string | `<web.cfg.base_dir>` | Base directory to scan     |
| vhost     | string | '' (all vhosts)        | Specific vhost to scan     |

**Returns:**
```perl
{
    status  => 'success' | 'error',
    message => "Scanned N entries",
    count   => 4,
    index   => {
        '/index.html' => {
            path           => '/index.html',
            has_template   => 1,
            template_path  => '/data/web/vhost/_templates/index.html.tmpl',
            template_level => 2,  # 1=subdir, 2=vhost, 3=global
            mtime          => 1740982847,
            size           => 32,
            is_dynamic     => 1,
        },
        ...
    }
}
```

**Storage:** Results stored in `<web.content_index>{$vhost_key}`

**Template Hierarchy (3 levels):**
1. **Level 1** - Vhost subdirectory: `{vhost}/{subdir}/_templates/{file}.tmpl`
2. **Level 2** - Vhost root: `{vhost}/_templates/{file}.tmpl`
3. **Level 3** - Global: `_global_templates/{file}.tmpl`

---

### 2. web.template_cache.get

Retrieves cached template content by key, checking TTL expiration.

**Purpose:**
- Fast retrieval of pre-rendered templates
- Automatic expiration of stale entries
- Metrics tracking (cache hits/misses)

**Location:** `modules/web.template_cache.get`

**Parameters:**
```perl
my $result = <[web.template_cache.get]>->($cache_key);
```

| Parameter | Type   | Required | Description          |
|-----------|--------|----------|----------------------|
| cache_key | string | Yes      | Unique cache key     |

**Returns:**
```perl
# Cache hit
{
    status  => 'hit',
    hit     => 1,
    content => '... rendered HTML ...',
    age     => 45,      # seconds since stored
    ttl     => 1800,    # configured TTL
    size    => 1024,    # bytes
}

# Cache miss / expired
{
    status  => 'miss' | 'expired',
    hit     => 0,
    content => undef,
}
```

**Storage:** Reads from `<web.template_cache>{$key}`

**Entry Structure:**
```perl
<web.template_cache>{$key} = {
    content   => '...',
    timestamp => 1740982847,  # unix time
    ttl       => 1800,        # seconds
    size      => 1024,        # bytes
};
```

**TTL Behavior:**
- Expired entries are automatically deleted
- Returns `undef` for expired content
- Updates `<web.metrics.cache_misses>` on expiration

---

### 3. web.template_cache.set

Stores rendered template content with TTL and size limits.

**Purpose:**
- Cache rendered templates to avoid re-processing
- Enforce maximum content size
- Validate TTL values

**Location:** `modules/web.template_cache.set`

**Parameters:**
```perl
my $result = <[web.template_cache.set]>->($cache_key, $content, $ttl);
```

| Parameter | Type   | Required | Default                 | Description          |
|-----------|--------|----------|-------------------------|----------------------|
| cache_key | string | Yes      | -                       | Unique cache key     |
| content   | string | Yes      | -                       | Content to cache     |
| ttl       | int    | No       | `<web.cfg.cache_ttl>` | TTL in seconds       |

**Returns:**
```perl
# Success
{
    status    => 'success',
    stored    => 1,
    cache_key => 'vhost:/path',
    size      => 1024,
    ttl       => 1800,
}

# Error (size exceeded)
{
    status   => 'error',
    stored   => 0,
    message  => 'Content exceeds max size...',
    size     => 6000000,
    max_size => 5242880,
}
```

**Configuration:**
- Max size: `<web.cfg.template_max_size>` (default: 5MB)
- Default TTL: `<web.cfg.cache_ttl>` (default: 1800 seconds / 30 minutes)

**TTL Validation:**
```perl
$ttl =~ m|\A[1-9][0-9]*\z|  # Must be positive integer
```

**Metrics:** Increments `<web.metrics.templates_cached>` on success

---

### 4. httpsd.route_template_request

Routes HTTP requests to appropriate handlers with caching.

**Purpose:**
- Priority-based request routing
- Path normalization
- Route decision caching

**Location:** `modules/httpsd.route_template_request`

**Parameters:**
```perl
my $route = <[httpsd.route_template_request]>->($method, $uri, $vhost, $session_id);
```

| Parameter  | Type   | Required | Default   | Description              |
|------------|--------|----------|-----------|--------------------------|
| method     | string | No       | 'GET'     | HTTP method              |
| uri        | string | No       | '/'       | Request URI              |
| vhost      | string | Yes      | -         | Virtual host name        |
| session_id | string | No       | 'unknown' | Session ID for logging   |

**Returns:**
```perl
{
    type         => 'acme' | 'api' | 'template' | 'static',
    path         => '/normalized/path',
    handler      => 'module.name',
    handler_args => { ... },
    reason       => 'human readable',
    cached       => 0 | 1,        # was this a cached decision?
    cache_ttl    => 1800,         # how long to cache this route
}
```

**Routing Priority:**

1. **ACME Challenges** (`/.well-known/acme-challenge/{token}`)
   - Handler: `httpd.handler.acme_challenge`
   - Cache: No (one-time tokens)

2. **API Endpoints** (`/api/...`, `/webhook/...`)
   - Handler: `base.protocol-7.command.send.local`
   - Cache: No

3. **Template Content**
   - Handler: `httpd.process_template`
   - Cache: Yes (TTL from `<web.cfg.cache_ttl>`)
   - Uses: `<[httpd.vhost_template_resolver]>`

4. **Static Files** (default)
   - Handler: `httpd.serve_static`
   - Cache: Yes (3600 seconds)

**Path Normalization:**
- Removes query strings (`?...`)
- Removes fragments (`#...`)
- Collapses multiple slashes (`//` → `/`)
- Ensures leading `/`
- Removes trailing `/` (except for root)

**Route Caching:**
- Cache key: `"$method:$path:$vhost"`
- Storage: `<httpsd.route_cache>{$cache_key}`
- ACME and API routes are never cached

---

## Configuration

### Data Structure Initialization

In `web.init_code`:
```perl
# Cache structures
<web.template_cache>  = {};
<web.content_index>   = {};
<web.skin_cache>      = {};
<web.menu_cache>      = {};

# Metrics
<web.metrics> = {
    templates_processed     => 0,
    templates_cached        => 0,
    commands_executed       => 0,
    commands_nested         => 0,
    recursion_depth_max_hit => 0,
    avg_processing_time_ms  => 0,
    cache_hits              => 0,
    cache_misses            => 0,
};
```

### Configuration Values

```perl
<web.cfg.base_dir>          //= '/data/web';
<web.cfg.skins_dir>         //= '/var/httpd/skins';
<web.cfg.cache_enabled>     //= 1;
<web.cfg.cache_ttl>         //= 1800;      # 30 minutes
<web.cfg.template_max_size> //= 5 * 1024 * 1024;  # 5MB
```

---

## Usage Examples

### Scan Content Directory

```perl
# Scan specific vhost
my $result = <[web.scan_content_directories]>->('/data/web', 'example.com');

# Access the index
my $index = <web.content_index>{'example.com'};

# Check if file has template
if ($index->{'/index.html'}{'has_template'}) {
    my $tmpl_path = $index->{'/index.html'}{'template_path'};
}
```

### Cache Operations

```perl
# Store rendered content
my $cache_key = "example.com:/blog/post.html";
my $result = <[web.template_cache.set]>->(
    $cache_key,
    $rendered_html,
    3600  # 1 hour TTL
);

# Retrieve cached content
my $cached = <[web.template_cache.get]>->($cache_key);
if ($cached->{'hit'}) {
    return $cached->{'content'};
}

# Render and cache on miss
my $rendered = render_template($path);
<[web.template_cache.set]>->($cache_key, $rendered);
```

### Route Request

```perl
# In httpd request handler
my $route = <[httpsd.route_template_request]>->(
    'GET',
    '/blog/post.html?id=123',
    'example.com',
    $session_id
);

# Dispatch based on type
if ($route->{'type'} eq 'template') {
    return <[httpd.process_template]>->($route->{'handler_args'});
} elsif ($route->{'type'} eq 'static') {
    return <[httpd.serve_static]>->($route->{'handler_args'});
}
```

---

## Testing

### Manual Testing Commands

```bash
# Test content scanner
p7c web.exec-sub web.scan_content_directories /data/web test.local

# Test cache set
p7c web.exec-sub web.template_cache.set my_key "Hello World" 60

# Test cache get (hit)
p7c web.exec-sub web.template_cache.get my_key

# Test cache expiration
sleep 61 && p7c web.exec-sub web.template_cache.get my_key

# Test router - ACME
p7c httpsd.exec-sub httpsd.route_template_request \
    GET /.well-known/acme-challenge/test 127.0.0.1 123

# Test router - API
p7c httpsd.exec-sub httpsd.route_template_request \
    GET /api/users 127.0.0.1 123

# Test router - Static
p7c httpsd.exec-sub httpsd.route_template_request \
    GET /index.html 127.0.0.1 123
```

### Verify Data Structures

```bash
# Check content index
p7c web.dump web.content_index

# Check cache contents
p7c web.dump web.template_cache

# Check metrics
p7c web.dump web.metrics

# Check route cache
p7c httpsd.dump httpsd.route_cache
```

---

## Integration Points

### httpd.request_handler

The router should be called early in request processing:

```perl
# In httpd.request_handler or httpd.http_get

my $route = <[httpsd.route_template_request]>->(
    $method, $uri, $vhost, $session_id
);

given ($route->{'type'}) {
    when ('acme')    { return <[httpd.handler.acme_challenge]>->(...) }
    when ('api')     { return <[base.protocol-7.command.send.local]>->(...) }
    when ('template'){ return <[httpd.process_template]>->(...) }
    default          { return <[httpd.serve_static]>->(...) }
}
```

### Template Processing Pipeline

```
httpd.process_template
    |
    v
web.process_template_recursive
    |
    +---> web.template_cache.get (check cache)
    |
    +---> base.parser.pattern_split (parse <[...]> commands)
    |
    +---> web.execute_template_command (execute commands)
    |
    +---> web.template_cache.set (store result)
```

---

## Performance Considerations

### Cache Hit Rates

Expected cache hit rates:
- **Static routes**: >95% (cached 1 hour)
- **Template routes**: >80% (cached 30 minutes)
- **Content index**: Re-scan on vhost changes only

### Memory Usage

- Each cached template: content size + ~100 bytes overhead
- Content index: ~500 bytes per file
- Route cache: ~200 bytes per unique route

### TTL Strategy

- **Short TTL (2-60s)**: Dynamic content, user-specific
- **Medium TTL (1800s)**: Standard templates
- **Long TTL (3600s+)**: Static routes, stable content

---

## Troubleshooting

### Common Issues

**Cache always misses:**
- Check `<web.cfg.cache_enabled>` is true
- Verify cache key format includes vhost
- Check TTL is positive integer

**Content not found:**
- Verify `<web.cfg.base_dir>` path
- Check vhost directory permissions
- Ensure template files have `.tmpl` extension

**Routes not caching:**
- ACME and API routes are intentionally uncached
- Check `<httpsd.route_cache>` exists
- Verify no errors in `<base.log>`

### Debug Logging

Enable verbose logging:
```bash
p7c web.change-log-verbosity 3
p7c httpsd.change-log-verbosity 3
```

Watch routing decisions:
```bash
p7c web.show-buffer zenka | tail -20
p7c httpsd.show-buffer zenka | tail -20
```

---

## Future Enhancements

1. **Persistent Cache** - File-based cache like weather module
2. **Cache Warming** - Pre-render popular templates
3. **Smart Invalidation** - Watch for file changes
4. **Distributed Cache** - Shared cache across instances
5. **Cache Statistics** - Hit rate dashboards

---

## See Also

- `docs/modules/TEMPLATE-SYSTEM-MODULE-REFERENCE.md` - Complete API reference
- `docs/TEMPLATE_SYSTEM_STATUS_SUMMARY.md` - Current status
- `docs/architecture/VHOST_TEMPLATE_HIERARCHY.md` - Template hierarchy design
- `modules/httpd.vhost_template_resolver` - Template resolution
- `modules/web.process_template_recursive` - Template rendering

---

*Last updated: 2026-03-03*
*Implementation: Phase 2-4 Complete*

#,,.,,...,.,.,,..,,,.,,.,,.,.,...,,.,,.,,,,.,,..,,...,...,,,.,,..,,..,,..,.,,,
#UKJJLVFNFSWEJYNANLG7J2BAV6OETC4SOKI5LR2X5WHCTYVI7HIRRNND4Y7ZDGC5VLB6O2HS5IVYS
#\\\|7OYODEOT7GPVN2E46PG27RRAWUM5DCO3TJCU4XDWGISLAQJM3BQ \ / AMOS7 \ YOURUM ::
#\[7]QDE2U7MWCRGGR6XEUEATFM2LX234LR4S3NM6NWKGHU7PWW7UJECQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
