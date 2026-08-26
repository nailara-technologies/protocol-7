# Template System Module Reference
**Version**: 1.0  
**Date**: 2025-11-29  
**Status**: Planning/Reference for implementation  
**Purpose**: Complete API reference for template processing modules in Protocol-7

---

## Table of Contents
1. [Existing Modules](#existing-modules)
2. [New Modules to Implement](#new-modules-to-implement)
3. [Data Structures](#data-structures)
4. [Integration Points](#integration-points)
5. [Module Interaction Diagram](#module-interaction-diagram)
6. [Implementation Notes](#implementation-notes)

---

## Existing Modules

### Core Template Processing (Web Zenka)

#### `web.init_code`
**Purpose**: Initialize web zenka and configure template system  
**Type**: `.init_code` - runs once at zenka startup  
**File**: `src/web.init_code`

**Initializes**:
```perl
<web.cfg.base_dir>              # Content base directory
<web.cfg.cache_enabled>         # Enable caching (1 = yes)
<web.cfg.cache_ttl>             # Cache TTL in seconds (1800 = 30 min)
<web.cfg.template_max_size>     # Max template size (5MB default)
<web.cfg.recursion_depth_max>   # Max nesting depth (8 default)
<web.cfg.command_timeout>       # Command execution timeout (15s)
<web.cfg.parallel_commands_max> # Max parallel command execution (16)

<web.templates.cache>           # Cache storage: { key => content, ... }
<web.templates.active>          # Active processing: { id => metadata }
<web.commands.pending>          # Pending commands
<web.metrics>                   # Tracking metrics hash
```

**Status**: ✅ Complete - Sets up config but cache not implemented

---

#### `web.process_template_recursive`
**Purpose**: Main template processing engine with recursive parsing  
**Type**: Regular module (subroutine)  
**File**: `src/web.process_template_recursive`  
**Called by**: `web.process_template_ipc`

**Signature**:
```perl
my $result = <[web.process_template_recursive]>->({
    content         => $template_content,      # Template HTML/text
    meta            => { key => value, ... },  # Variables: <{key}>
    depth           => 0,                      # Current recursion depth
    template_id     => 'template_12345',       # Tracking ID
    session_id      => 'session_789',          # HTTP session ID
});
```

**Returns**:
```perl
{
    status   => 'success',          # or 'error'
    message  => 'rendered content', # or error description
    content  => $rendered_html,     # Fully processed template
    metrics  => { ... }             # Performance metrics
}
```

**Process** (steps 1-4):
1. **Meta variable expansion**: `<{var_name}>` → lookup in `$meta` hash
2. **Command parsing**: Find `<[command.name:arg1:arg2]>` patterns
3. **Command execution**: Execute each command, collect results
4. **Recursion**: If output contains more templates, recurse (depth+1)
5. **Caching**: Store result in `<web.templates.cache>` (TTL applied)

**Example**:
```html
<!-- Input template -->
<h1><{page.title}></h1>
<p>Current user: <[web:get-user-name]></p>
<div><[web:include:partials/sidebar.html]></div>

<!-- After expansion (simplified) -->
<h1>My Blog Post</h1>
<p>Current user: alice</p>
<div>(contents of partials/sidebar.html)</div>
```

**Limitations**:
- Max depth: `<web.cfg.recursion_depth_max>` (prevents infinite loops)
- Max size: `<web.cfg.template_max_size>` (prevents DOS)
- Command timeout: `<web.cfg.command_timeout>` (prevents hangs)

**Status**: ✅ Complete - Fully functional

---

#### `web.process_template_ipc`
**Purpose**: IPC handler to receive templates from httpd zenka  
**Type**: Regular module (command handler)  
**File**: `src/web.process_template_ipc`  
**Called by**: httpd.process_template (via cube IPC)  
**Calls**: web.process_template_recursive

**Signature**:
```perl
my $reply = <[web.process_template_ipc]>->(
    'template_id:template_b32r:meta_b32r:session_id'
);
```

**Parameters** (colon-delimited):
- `template_id`: Unique ID (e.g., `httpd_12345_1234567890`)
- `template_b32r`: Template content (base32r encoded to avoid delimiters)
- `meta_b32r`: Meta variables as JSON (base32r encoded)
- `session_id`: HTTP session ID for correlation

**Returns**:
```perl
{
    mode   => 'true' | 'false',     # Success/failure
    data   => 'rendered_content',   # Result or error message
    type   => 'size' | 'text',      # Response type
    size   => 12345                 # Content size (optional)
}
```

**Process**:
1. Decode base32r inputs
2. Parse JSON meta variables
3. Call `web.process_template_recursive` with parsed content
4. Log result
5. Return response to httpd via cube callback

**Status**: ✅ Complete - Fully functional

---

#### `httpd.process_template`
**Purpose**: HTTP layer handler called when `.tmpl` file requested  
**Type**: Regular module  
**File**: `src/httpd.process_template`  
**Called by**: httpd.http_get (or httpd.request_handler)  
**Calls**: web.process_template_ipc (async via cube)

**Signature**:
```perl
my $keep_alive = <[httpd.process_template]>->(
    $session_id,       # HTTP session ID
    $template_path     # Full path to .tmpl file
);
```

**Return**: 1 (keep connection alive, waiting for async reply)

**Process**:
1. Validate session and template path
2. Read template file via `<[file.slurp]>->`
3. Extract meta variables from session
4. Encode both as base32r (to avoid IPC delimiter conflicts)
5. Create unique template_id
6. Send to web zenka via: `<[base.protocol-7.command.send.local]>->`
7. Return 1 (connection stays alive)
8. Web zenka sends result back to: `httpd.handler.web_template_reply`

**Status**: ✅ Complete - Fully functional

---

#### `httpd.handler.web_template_reply`
**Purpose**: Callback handler to receive rendered template from web zenka  
**Type**: Handler (`.handler.` prefix)  
**File**: `src/httpd.handler.web_template_reply`  
**Called by**: cube (async callback from web zenka)

**Receives**:
```perl
{
    mode => 'true'|'false',
    data => $rendered_content,
    params => {
        client_sid => $session_id,
        template_id => $template_id
    }
}
```

**Process**:
1. Verify session still exists
2. Set Content-Type header
3. Set Cache-Control header (uses `web.cfg.cache_ttl`)
4. Send rendered content to HTTP client
5. Close connection

**Status**: ✅ Complete - Fully functional

---

### Template Resolution & Routing (Nov 15 Infrastructure)

#### `httpd.vhost_template_resolver`
**Purpose**: Find template across 3-level hierarchy  
**Type**: Regular module  
**File**: `src/httpd.vhost_template_resolver`  
**Called by**: Route dispatcher or your `httpsd.route_template_request`

**Signature**:
```perl
my $template_path = <[httpd.vhost_template_resolver]>->(
    $vhost,         # e.g., "127.0.0.1" or "example.com"
    $request_path,  # e.g., "/blog/post.html"
    $extension      # e.g., "tmpl" or "mustache"
);
```

**Returns**: Full path to template file or `undef`

**Search Order**:
1. `/var/httpd/{vhost}{request_path_dir}/_templates/{filename}.{extension}`
2. `/var/httpd/{vhost}/_templates/{filename}.{extension}`
3. `/var/httpd/_global_templates/{filename}.{extension}`

**Example**:
```perl
# Request: GET /blog/post.html from vhost 127.0.0.1
my $path = <[httpd.vhost_template_resolver]>->(
    '127.0.0.1', '/blog/post.html', 'tmpl'
);
# Returns: /var/httpd/127.0.0.1/blog/_templates/post.html.tmpl
# Or:      /var/httpd/127.0.0.1/_templates/post.html.tmpl
# Or:      /var/httpd/_global_templates/post.html.tmpl
# Or:      undef (if none found)
```

**Caching**: Results cached in `$data{'httpd.vhost_template_resolver'}{$cache_key}`  
(Both positive and negative results cached to prevent repeated filesystem checks)

**Status**: ✅ Complete - Fully functional

---

#### `web.skin_resolver`
**Purpose**: Resolve CSS/skin file with cascade fallback  
**Type**: Regular module  
**File**: `src/web.skin_resolver`  
**Called by**: Template during rendering to include stylesheets

**Signature**:
```perl
my $skin_file = <[web.skin_resolver]>->(
    $vhost,         # e.g., "127.0.0.1"
    $request_path,  # e.g., "/blog" (optional)
    $skin_name,     # e.g., "dark" (default: "default")
    $filename       # e.g., "style.css"
);
```

**Returns**: Full path to skin file or `undef`

**Search Order**:
1. `/var/httpd/{vhost}/_skins/{skin_name}/{filename}`
2. `/var/httpd/_global_templates/skins/{skin_name}/{filename}`
3. `/var/httpd/{vhost}/_skins/default/{filename}` (fallback)
4. `/var/httpd/_global_templates/skins/default/{filename}` (fallback)

**Example**:
```perl
# User requests dark skin
my $css = <[web.skin_resolver]>->(
    '127.0.0.1', '/blog', 'dark', 'style.css'
);
# Returns: /var/httpd/127.0.0.1/_skins/dark/style.css
# Or:      /var/httpd/_global_templates/skins/dark/style.css
# Or:      /var/httpd/127.0.0.1/_skins/default/style.css (fallback)
```

**In Template**:
```html
<link rel="stylesheet" href="<[web:include:skins/<{user.skin}>/style.css]>">
```

**Caching**: Results cached in `$data{'web.skin_resolver'}{$cache_key}`

**Status**: ✅ Complete - Fully functional

---

#### `web.menu_generator`
**Purpose**: Generate navigation menu from filesystem structure  
**Type**: Regular module  
**File**: `src/web.menu_generator`  
**Called by**: Template during rendering to create navigation

**Signature**:
```perl
my $menu_items = <[web.menu_generator]>->(
    $vhost,          # e.g., "127.0.0.1"
    $menu_context,   # e.g., "main" (default: "main")
    $base_path       # e.g., "/" (default: "/")
);
```

**Returns**: Array reference of menu items
```perl
[
    {
        label   => 'Home',
        path    => '/',
        icon    => 'home',
        active  => 1,          # True if current page
        order   => 10,         # Sort order (optional)
        hidden  => 0,          # Skip in rendering (optional)
    },
    {
        label   => 'Blog',
        path    => '/blog/',
        active  => 0,
    },
    # ... more items ...
]
```

**Source Data**:
- Scans `/var/httpd/{vhost}/` for subdirectories
- Creates menu item for each (skipping `_*` directories)
- Reads optional `{dir}/menu.yaml` for metadata:
  ```yaml
  label: Custom Label
  icon: folder-icon
  order: 20
  hidden: false
  ```

**In Template**:
```html
<nav>
  {{#menu_items}}
    <a href="{{path}}" {{#active}}class="active"{{/active}}>
      {{label}}
    </a>
  {{/menu_items}}
</nav>
```

**Caching**: Results cached in `$data{'menu_cache'}{$cache_key}`

**Status**: ✅ Complete - Fully functional

---

#### `httpd.route_dispatcher`
**Purpose**: Intelligent HTTP request routing  
**Type**: Regular module  
**File**: `src/httpd.route_dispatcher`  
**Called by**: httpd.request_handler (or your integration)

**Signature**:
```perl
my $route = <[httpd.route_dispatcher]>->(
    $http_method,   # e.g., "GET"
    $request_path,  # e.g., "/blog/post.html"
    $vhost,         # e.g., "127.0.0.1"
    $session_id     # For logging/correlation
);
```

**Returns**:
```perl
{
    type            => 'acme'|'api'|'template'|'static',
    path            => $request_path,
    handler         => 'module.name.to.call',
    handler_args    => { ... },        # Arguments for handler
    template_path   => '...',          # If type is 'template'
    cache_ttl       => 1800,           # Cache control
    reason          => 'found_template'
}
```

**Route Priority**:
1. **ACME Challenge**: `/.well-known/acme-challenge/*` → type: acme
2. **API Endpoints**: `/api/*` → type: api
3. **Template Routes**: Check for `_templates/` → type: template
4. **Static Files**: Everything else → type: static

**Example Decision Tree**:
```
GET /api/status
  → Matches /api/* pattern
  → Returns {type: 'api', handler: 'api.handler.status', ...}

GET /blog/post.html
  → Not ACME, not /api/*
  → Check template resolver: /var/httpd/127.0.0.1/blog/_templates/post.html.tmpl
  → Found!
  → Returns {type: 'template', template_path: '...', handler: 'httpd.process_template', ...}

GET /static/style.css
  → Not ACME, not /api/*, no template
  → Returns {type: 'static', handler: 'httpd.file_transfer', ...}
```

**Caching**: Route decisions cached per vhost+path combination

**Status**: ✅ Complete - Fully functional but not yet integrated

---

#### `web.assets.load_registry`
**Purpose**: Load asset registry (images, stylesheets, etc.)  
**Type**: Regular module  
**File**: `src/web.assets.load_registry`

**Signature**:
```perl
my $success = <[web.assets.load_registry]>->();
```

**Returns**: 1 on success, undef on failure

**Purpose**: Pre-load manifest of available assets for faster lookups  
**Status**: ✅ Complete - Used by web.init_code

---

### Utility Functions

#### `web.execute_template_command`
**Purpose**: Execute a single `<[command:args]>` in template  
**Type**: Regular module  
**File**: `src/web.execute_template_command`

**Signature**:
```perl
my $result = <[web.execute_template_command]>->({
    command     => 'web.include',      # Command namespace
    args        => 'path/to/file.html',
    session_id  => '...',
    depth       => 1,
});
```

**Status**: ✅ Complete - Part of web.process_template_recursive

---

## New Modules to Implement

### Module 1: Content Directory Scanner

**File**: `src/web.scan_content_directories` (or `src/httpsd.scan_content_directories`)  
**Purpose**: Index available templates at startup or on demand  
**Type**: Regular module (can also have `.cmd.scan_content` for manual trigger)

**Signature**:
```perl
my $index = <[web.scan_content_directories]>->(
    $base_dir,      # e.g., "/var/httpd"
    $vhost          # e.g., "127.0.0.1" (optional, for single vhost)
);
```

**Returns**:
```perl
{
    '/blog/post.html' => {
        path            => '/blog/post.html',
        has_template    => 1,
        template_path   => '/var/httpd/127.0.0.1/blog/_templates/post.html.tmpl',
        template_level  => 1,  # 1=vhost-subdir, 2=vhost-root, 3=global
        mtime           => 1234567890,
        size            => 2048,
        is_dynamic      => 1,
    },
    '/index.html' => {
        path            => '/index.html',
        has_template    => 0,
        is_dynamic      => 0,
    },
    # ... more entries ...
}
```

**Process**:
1. Recursively scan `/var/httpd/{vhost}/`
2. For each HTML/text file, check for `_templates/` version
3. Store in `$data{'web.content_index'}` or `$data{'httpsd.content_index'}`
4. Can be called at startup or refreshed on demand
5. Supports caching with mtime check for invalidation

**Used By**:
- Route dispatcher (to quickly check if template exists)
- Menu generator (to list available pages)
- Dashboard/admin interfaces (to show available content)

**Implementation Notes**:
- Use File::Find or simple directory recursion
- Check modification time to detect changes
- Cache results in `$data{...}` with optional file persistence
- Similar to web.menu_generator pattern (simple in-memory hash)

**Status**: ⏳ To implement

---

### Module 2: Request Route Dispatcher

**File**: `src/httpsd.route_template_request` (or could extend existing `httpd.route_dispatcher`)  
**Purpose**: Route HTTP requests to appropriate handlers (ACME → API → Template → Static)  
**Type**: Regular module

**Signature**:
```perl
my $route = <[httpsd.route_template_request]>->(
    $http_method,    # "GET", "POST", etc.
    $request_uri,    # "/blog/post.html?id=123"
    $vhost,          # "127.0.0.1" or "example.com"
    $session_id,     # For logging
    $content_index   # Precomputed index from scanner (optional)
);
```

**Returns**:
```perl
{
    type            => 'acme'|'api'|'template'|'static',
    path            => '/blog/post.html',              # Normalized
    handler         => 'httpd.process_template',      # Which handler to call
    handler_args    => {                               # Args for handler
        session_id     => '...',
        template_path  => '...',
        cache_ttl      => 1800,
    },
    reason          => 'template_found_in_vhost_subdir',
    cached          => 0|1,                           # Was this result cached?
}
```

**Routing Logic**:
```
Input: GET /blog/post.html from 127.0.0.1

1. Normalize path: remove query strings, fragments, double slashes
   → /blog/post.html

2. Check ACME: /.well-known/acme-challenge/{token}
   → NO → continue

3. Check API: /api/* or /webhook/* or /rest/*
   → NO → continue

4. Check STATIC: ends in .css, .js, .png, .pdf, .jpg, /static/, /assets/
   → NO → continue

5. Check TEMPLATE: does template exist in hierarchy?
   → Use vhost_template_resolver or content_index
   → YES: /var/httpd/127.0.0.1/blog/_templates/post.html.tmpl
   → Return {type: 'template', handler: 'httpd.process_template', ...}

6. Default STATIC:
   → Return {type: 'static', handler: 'httpd.file_transfer', ...}
```

**Caching Strategy**:
- Cache routing decisions in `$data{'httpsd.route_cache'}{$cache_key}`
- Cache key: `"$vhost:$normalized_path"`
- Invalidate on:
  - Content index refresh
  - Manual cache clear command
  - TTL expiration (configurable, e.g., 3600s)

**Integration Point**:
This should be called early in `httpd.http_get` or `httpd.request_handler`:
```perl
my $route = <[httpsd.route_template_request]>->(...);

if ($route->{type} eq 'template') {
    return <[httpd.process_template]>->(@{$route->{handler_args}}{qw(session_id template_path)});
} elsif ($route->{type} eq 'api') {
    return <[$route->{handler}]>->(...);
} else {
    # static file handling
}
```

**Status**: ⏳ To implement

---

### Module 3: Template Cache (Two Functions)

**Files**: 
- `src/web.template_cache.get`
- `src/web.template_cache.set`
- Optional: `src/web.template_cache.invalidate`

**Purpose**: TTL-aware caching of rendered templates  
**Type**: Regular modules

#### 3a: web.template_cache.get

**Signature**:
```perl
my $cached_content = <[web.template_cache.get]>->(
    $cache_key      # e.g., "127.0.0.1:/blog/post.html"
);
```

**Returns**: Cached content if exists and not expired, otherwise `undef`

**Implementation**:
```perl
# Storage format: $data{'web.template_cache'}{$key} = {
#     content    => $rendered_html,
#     timestamp  => $time_cached,
#     ttl        => $ttl_seconds,
# }

my $entry = <web.template_cache>{$cache_key};
return undef unless defined $entry;

my $age = time - $entry->{timestamp};
if ($age > $entry->{ttl}) {
    delete <web.template_cache>{$cache_key};  # Expired
    return undef;
}

return $entry->{content};  # Cache hit
```

**Status**: ⏳ To implement

---

#### 3b: web.template_cache.set

**Signature**:
```perl
my $success = <[web.template_cache.set]>->(
    $cache_key,         # e.g., "127.0.0.1:/blog/post.html"
    $rendered_content,  # HTML to cache
    $ttl                # seconds (default: <web.cfg.cache_ttl>)
);
```

**Returns**: 1 on success, 0 on failure (e.g., if size exceeded)

**Implementation**:
```perl
my $max_size = <web.cfg.template_max_size>;

# Check size limit
if (length($rendered_content) > $max_size) {
    <[base.log]>->(1, "cache: content exceeds max size ($max_size bytes)");
    return 0;
}

# Store with timestamp
<web.template_cache>{$cache_key} = {
    content   => $rendered_content,
    timestamp => time(),
    ttl       => $ttl // <web.cfg.cache_ttl>,
    size      => length($rendered_content),
};

# Update metrics
<web.metrics>{templates_cached}++;
return 1;
```

**Status**: ⏳ To implement

---

#### 3c: web.template_cache.invalidate (Optional)

**Signature**:
```perl
my $count = <[web.template_cache.invalidate]>->(
    $pattern    # e.g., "127.0.0.1:*" or "*" for all
);
```

**Returns**: Number of entries deleted

**Purpose**: Manual cache invalidation (e.g., when template file updated)

**Implementation**:
```perl
my $count = 0;
foreach my $key (keys %{<web.template_cache>}) {
    if ($key =~ /$pattern/) {
        delete <web.template_cache>{$key};
        $count++;
    }
}
<[base.log]>->(2, "cache: invalidated $count entries matching '$pattern'");
return $count;
```

**Status**: ⏳ Optional, can add later

---

### Module 4: Command Handler (Optional)

**File**: `src/httpsd.cmd.refresh_content_index` (or `web.cmd.scan-templates`)  
**Purpose**: Manually trigger content index refresh  
**Type**: `.cmd.*` - automatically gets `$call` and `$reply` wrappers

**Signature**:
```perl
# Called via: <[httpsd.cmd.refresh_content_index]>->({ args => '' })
# Or via cube: cube.httpsd.refresh-content-index
```

**Implementation**:
```perl
# Receives: $call with 'args'
# Returns: $reply with 'mode' and 'data'

my $vhost = $call->{args} // '';

my $index = <[web.scan_content_directories]>>->('/var/httpd', $vhost);
$data{'web.content_index'} = $index;

return {
    mode => 'true',
    data => 'Content index refreshed: ' . scalar(keys %$index) . ' entries'
};
```

**Status**: ⏳ Optional, can add later

---

## Data Structures

### Global Cache Storage

```perl
# Location: $data{'web.template_cache'}
# Format: key => { content, timestamp, ttl, size }

<web.template_cache> = {
    '127.0.0.1:/blog/post.html' => {
        content   => '<html>...</html>',
        timestamp => 1700000000,
        ttl       => 1800,
        size      => 2048,
    },
    '127.0.0.1:/index.html' => {
        content   => '<html>...</html>',
        timestamp => 1700000050,
        ttl       => 1800,
        size      => 1024,
    },
    # Expired entries removed on access or by cleanup
};
```

### Content Index Storage

```perl
# Location: $data{'web.content_index'}
# Format: path => metadata

<web.content_index> = {
    '/blog/post.html' => {
        path           => '/blog/post.html',
        has_template   => 1,
        template_path  => '/var/httpd/127.0.0.1/blog/_templates/post.html.tmpl',
        mtime          => 1700000000,
    },
    '/index.html' => {
        path           => '/index.html',
        has_template   => 0,
        mtime          => 1699999000,
    },
};
```

### Route Cache Storage

```perl
# Location: $data{'httpsd.route_cache'}
# Format: cache_key => route_decision

<httpsd.route_cache> = {
    '127.0.0.1:/blog/post.html' => {
        type            => 'template',
        path            => '/blog/post.html',
        handler         => 'httpd.process_template',
        handler_args    => { session_id => '...', template_path => '...' },
        reason          => 'template_found_in_vhost_subdir',
        cached_at       => 1700000000,
    },
    '127.0.0.1:/static/style.css' => {
        type            => 'static',
        path            => '/static/style.css',
        handler         => 'httpd.file_transfer',
        reason          => 'no_template_found',
        cached_at       => 1700000010,
    },
};
```

---

## Integration Points

### Primary: HTTP Request Handler

**Current Flow**:
```
httpd.http_get
  ↓
Checks for .tmpl extension
  ↓
Calls httpd.process_template directly
```

**Proposed New Flow**:
```
httpd.http_get
  ↓
Calls httpsd.route_template_request
  ↓
If type='template': calls httpd.process_template
If type='api': calls appropriate API handler
If type='acme': calls ACME handler
If type='static': serves file directly
```

**Integration Code** (pseudocode):
```perl
my $route = <[httpsd.route_template_request]>->($method, $uri, $vhost, $session_id);

if ($route->{type} eq 'template') {
    return <[httpd.process_template]->($route->{handler_args}{session_id}, 
                                       $route->{handler_args}{template_path});
}
elsif ($route->{type} eq 'api') {
    return <[base.protocol-7.command.send.local]>->(...);
}
# ... etc
```

### Secondary: Template Processing

**Current Flow**:
```
httpd.process_template
  ↓ (IPC)
web.process_template_ipc
  ↓
web.process_template_recursive
  ↓ (optional, not implemented yet)
web.template_cache.get (check if cached)
  ↓
(process & render)
  ↓
web.template_cache.set (store result)
  ↓ (IPC response)
httpd.handler.web_template_reply
```

**Current State**: Cache calls should be added to web.process_template_recursive

**Integration Code** (conceptual):
```perl
# Inside web.process_template_recursive

my $cache_key = "$session_id:$template_id";

# Check cache first
my $cached = <[web.template_cache.get]>->($cache_key);
return { status => 'success', content => $cached } if defined $cached;

# ... do actual template processing ...

# Store in cache
<[web.template_cache.set]>->($cache_key, $result_content, <web.cfg.cache_ttl>);

return { status => 'success', content => $result_content };
```

---

## Module Interaction Diagram

```
┌────────────────────────────────────────────────────────────────┐
│ HTTP Client Request (GET /blog/post.html)                      │
└───────────────────────┬──────────────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────────────┐
        │ httpd.http_get or .request_handler    │
        └───────────────┬───────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────────────────────────┐
        │ httpsd.route_template_request                     │ NEW
        │ (uses: content_index, vhost_template_resolver)   │
        └──┬────┬────┬──────────────────────────────────────┘
           │    │    │
      ┌────┘    │    └────────────────┐
      │         │                     │
      ▼         ▼                     ▼
   (acme)    (api)              ┌─────────────────────────┐
            handler             │ httpd.process_template  │
                                └───────┬─────────────────┘
                                        │
                                        ▼
                            ┌─────────────────────────────┐
                            │ web.process_template_ipc    │
                            │ (IPC handler on web zenka)  │
                            └───────┬─────────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────────────┐
                    │ web.process_template_recursive        │
                    │ (Main parsing engine)                 │
                    └───┬───────────────────────────────────┘
                        │
                    ┌───┴────────────────────────────┐
                    │                                │
                    ▼                                ▼
        ┌──────────────────────────┐   ┌─────────────────────┐
        │ web.template_cache.get   │   │ Meta variable       │
        │ (Check if cached) NEW    │   │ expansion & command │
        └──────┬───────────────────┘   │ execution           │
               │                       └─────────────────────┘
               │ (cache hit)           │ (new render)
               │                       │
               └───────────┬───────────┘
                           │
                           ▼
        ┌─────────────────────────────────┐
        │ web.template_cache.set NEW      │
        │ (Store rendered result)         │
        └────────────┬────────────────────┘
                     │
                     ▼
        ┌─────────────────────────────────┐
        │ httpd.handler.web_template_reply│
        │ (IPC callback to httpd)         │
        └────────────┬────────────────────┘
                     │
                     ▼
        ┌─────────────────────────────────┐
        │ HTTP Client Response            │
        │ (rendered HTML content)         │
        └─────────────────────────────────┘
```

---

## Implementation Notes

### Priority Order
1. **httpsd.route_template_request** (connects everything)
2. **web.scan_content_directories** (feeds route dispatcher)
3. **web.template_cache.get** / **.set** (improves performance)
4. **httpsd.cmd.refresh_content_index** (operational convenience)

### Namespace Strategy
- Content-level modules: `web.*` (template processing domain)
- HTTP-layer modules: `httpsd.*` (HTTPS/routing domain)
- Can be refactored later with `ncode replace all`

### Cache Key Strategy
```perl
# Suggested format: "$vhost:$normalized_path"
# Examples:
#   "127.0.0.1:/blog/post.html"
#   "example.com:/api/users"
#   "example.com:/static/style.css"

# Ensures cache is vhost-specific
# Normalizes path (removes query, fragments)
# Simple string-based (no complex hash structures)
```

### TTL Configuration
Use existing `<web.cfg.cache_ttl>` (default 1800s = 30 min):
```perl
my $ttl = $ttl // <web.cfg.cache_ttl>;
```

### Error Handling
- Non-existent template → return undef
- Cache size exceeded → skip caching, return content anyway
- Expired cache entry → return undef, remove from cache
- Filesystem errors → log and continue

### Logging Pattern
```perl
<[base.log]>->(2, "cache: stored /blog/post.html (2048 bytes, ttl=1800s)");
<[base.log]>->(3, "cache: hit for /blog/post.html (age=45s)");
<[base.log]>->(1, "cache: error storing entry, size exceeded");
```

---

## Testing Strategy

### Unit Tests (Per Module)
1. **web.scan_content_directories**
   - Scan test directory structure
   - Verify template detection
   - Check mtime tracking

2. **httpsd.route_template_request**
   - Route ACME challenges ✓
   - Route API endpoints ✓
   - Route template requests ✓
   - Route static files ✓
   - Verify caching behavior

3. **web.template_cache.get/set**
   - Store and retrieve
   - TTL expiration
   - Size limit enforcement
   - Negative cache (expired returns undef)

### Integration Tests
1. Full request flow: Request → Route → Template → Cache → Response
2. Cache invalidation: File update → cache clear → re-render
3. Fallback chain: Vhost → Global → Static

### Performance Tests
1. Cache hit rate
2. Rendering time (with/without cache)
3. Filesystem scanning time
4. Route decision time

---

## Future Enhancements

1. **Persistent Cache** (file-based)
   - Store cache to disk
   - Survive process restart
   - Use weather.parent.cache pattern

2. **Cache Statistics**
   - Hit/miss ratio
   - Average age
   - Size tracking
   - Per-vhost stats

3. **Dynamic Invalidation**
   - Watch filesystem for changes
   - Auto-invalidate on template update
   - Cascading invalidation for includes

4. **Cache Warmup**
   - Pre-render popular templates
   - Background cache refresh
   - Predictive caching

5. **Cache Clustering**
   - Share cache across multiple Protocol-7 instances
   - Distributed cache coherency
   - Cross-process invalidation

---

**Document Status**: Reference for implementation  
**Last Updated**: 2025-11-29  
**Ready to Implement**: YES  
**Namespace Optimization**: Can be done post-implementation with `ncode replace all`

#,,.,,..,,,..,,.,,.,.,,,,,.,,,,.,,.,.,.,.,..,,..,,...,...,...,..,,..,,...,..,,
#A5SXC43TGUBSCQR3C5TJOUSDR4AANUVHTVEEICDZNKBDJY7P4ZH2PW6A6I5KO4DMARHZL6JDCNFQ6
#\\\|3MS56P67YBE5AAG7C4CCUSQKAUPU6AJOK3FC32EFTN6XAFMKT6M \ / AMOS7 \ YOURUM ::
#\[7]MYHPH5O36KPR63LH6AWS2T4JU2HP24AH2RQJHTF4DTCVRT53MEBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
