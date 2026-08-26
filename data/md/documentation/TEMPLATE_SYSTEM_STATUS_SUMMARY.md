# Web-Zenka & Template System - Comprehensive Status Summary

**Date**: 2025-11-29 (Context Compilation Session)
**Status**: Infrastructure complete, integration pending
**Previous Sessions**: Nov 14-15, Nov 16, Nov 28

---

## Executive Summary

**What's Complete:**
- ✅ Web zenka template processing (recursive parsing with <[ ]> command syntax)
- ✅ 3-level template hierarchy (vhost-subdir → vhost → global)
- ✅ Skin resolver with CSS cascade (dark/mobile/default fallback)
- ✅ Menu generator from filesystem
- ✅ Route dispatcher for intelligent request routing
- ✅ HTTPSD TLS/SSL support (phases 1-8 of Let's Encrypt integration)
- ✅ ACME certificate auto-installation
- ✅ Configuration template expansion system

**What's Needed:**
- 🟡 Template cache implementation (TTL-aware in-memory or file-based)
- 🟡 Content directory scanner (index available templates)
- 🟡 Request routing integration (connect all pieces)
- 🟡 Integration testing with sample content
- 🟡 Documentation of complete system

---

## Existing Modules (Already Implemented)

### Core Template Processing (Working)
| Module | Lines | Purpose | Status |
|--------|-------|---------|--------|
| `web.init_code` | 95 | Zenka initialization, config setup | ✅ Complete |
| `web.process_template_recursive` | 150+ | Recursive template parsing | ✅ Complete |
| `web.process_template_ipc` | 100+ | IPC handler from httpd zenka | ✅ Complete |
| `httpd.process_template` | 95 | HTTP handler that offloads to web zenka | ✅ Complete |
| `web.execute_template_command` | Variable | Execute <[command]> syntax | ✅ Complete |

### Template Routing & Resolution (Nov 15 Session)
| Module | Lines | Purpose | Status |
|--------|-------|---------|--------|
| `httpd.vhost_template_resolver` | 94 | 3-level template hierarchy lookup | ✅ Complete |
| `web.skin_resolver` | 110 | CSS/skin cascade with fallback | ✅ Complete |
| `web.menu_generator` | 130 | Auto-generate nav from filesystem | ✅ Complete |
| `httpd.route_dispatcher` | 90 | Route requests to handlers | ✅ Complete |

### Configuration & Utilities
| Module | Purpose | Status |
|--------|---------|--------|
| `base.parser.config` | Parse config files with template expansion | ✅ Complete |
| `web.assets.load_registry` | Asset registry management | ✅ Complete |

---

## What's Configured in web.init_code

```perl
<web.cfg.cache_enabled>         = 1              # Cache ON
<web.cfg.cache_ttl>             = 1800           # 30 minutes
<web.cfg.template_max_size>     = 5MB            # Size limit
<web.cfg.recursion_depth_max>   = 8              # Nest limit

<web.templates.cache>           = {}             # DECLARED but empty
<web.templates.active>          = {}             # Active processing
<web.commands.pending>          = {}             # Pending commands

<web.metrics>                   # Tracking metrics
  - templates_processed
  - templates_cached
  - cache_hits / cache_misses
  - recursion_depth_max_hit
  - avg_processing_time_ms
```

**Critical Finding**: Cache is configured and declared but **NOT IMPLEMENTED**. The hash `<web.templates.cache>` exists but no TTL logic or eviction.

---

## Current Architecture (Data Flow)

```
┌─────────────────────────────────────────────────────────────────┐
│                    User Browser Request                          │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  HTTPSD Zenka (TLS/SSL wrapper - auto-certs via Let's Encrypt)  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  HTTPD Zenka (HTTP handler)                                      │
│  • Detects .tmpl or .mustache extension                         │
│  • Calls: httpd.process_template                                │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  httpd.process_template (HTTP layer)                             │
│  • Reads template file                                           │
│  • Encodes: template + meta_vars → base32r                      │
│  • Sends IPC to: web.process_template_ipc (on web zenka)        │
│  • Waits for: httpd.handler.web_template_reply (callback)       │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  Web Zenka (Template processing engine)                          │
│  • Receives: template_id, content_b32r, meta_b32r, session_id  │
│  • Decodes: base32r → actual content                            │
│  • Calls: web.process_template_recursive                        │
│    - Step 1: Expand <{variable_name}> meta vars                 │
│    - Step 2: Parse <[command.name:args]> syntax                 │
│    - Step 3: Execute commands recursively                       │
│    - Step 4: Apply caching (if TTL implemented)                 │
│  • Returns: rendered_content (JSON)                             │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  httpd.handler.web_template_reply (callback)                     │
│  • Receives: rendered_content from web zenka                    │
│  • Sets: Content-Type, Cache-Control headers                    │
│  • Sends: rendered_content to client                            │
└────────────────────────────────────────────────────────────────┘
```

---

## Template Resolution Flow

```
Request: GET /blog/post.html

httpd.vhost_template_resolver('127.0.0.1', '/blog/post.html')
│
├─ Check 1 (HIGHEST PRIORITY):
│  └─ /var/httpd/127.0.0.1/blog/_templates/post.html.tmpl
│     ├─ EXISTS? → Return it (cache result)
│     └─ MISS? → Continue to Check 2
│
├─ Check 2 (MEDIUM PRIORITY):
│  └─ /var/httpd/127.0.0.1/_templates/post.html.tmpl
│     ├─ EXISTS? → Return it (cache result)
│     └─ MISS? → Continue to Check 3
│
└─ Check 3 (LOWEST PRIORITY):
   └─ /var/httpd/_global_templates/post.html.tmpl
      ├─ EXISTS? → Return it (cache result)
      └─ MISS? → Return undef, serve static file

Result cached in: $data{'httpd.vhost_template_resolver'}{$cache_key}
```

---

## Caching Patterns Already in Protocol-7

### Pattern 1: Simple In-Memory Hash (web.menu_generator)
```perl
unless (exists $data{'menu_cache'}) {
    $data{'menu_cache'} = {};
}
my $cache_key = "$vhost:$menu_context:$base_path";
if (exists $data{'menu_cache'}->{$cache_key}) {
    return $data{'menu_cache'}->{$cache_key};
}
# ... generate content ...
$data{'menu_cache'}->{$cache_key} = \@menu_items;
return \@menu_items;
```
**Pros**: Simple, fast, lightweight  
**Cons**: No TTL, no eviction, session-bound

### Pattern 2: File-Based with Timestamp TTL (weather.parent.cache)
```perl
my $max_age = <weather.cache_timeout> * 3600;
# File format: timestamp\ndata\n

my $data_age = time - $timestamp;
if ($data_age > $max_age) {
    unlink($cache_file);  # Expired
    return undef;
}
return $cached_data;
```
**Pros**: Persistent across restarts, explicit TTL  
**Cons**: Filesystem overhead, single timestamp per entry

### Pattern 3: Line-Delimited Persistent (crypt.C25519.chksum_cache)
```perl
# Functions: .add, .retr, .delete
# File format: key:value\nkey:value\n
# Simple grep/split for retrieval
```
**Pros**: Persistent, searchable  
**Cons**: Not suitable for large datasets or frequent updates

---

## What Taeki's Three Modules Should Do

### Module 1: httpsd.scan_content_directories
**Purpose**: Index available templates at startup
**Should Return**: 
```perl
{
    '/blog/post.html' => {
        'has_template' => 1,
        'template_path' => '/var/httpd/127.0.0.1/blog/_templates/post.html.tmpl',
        'mtime' => 1234567890,
    },
    '/index.html' => {
        'has_template' => 0,
    }
}
```
**Storage**: `$data{'httpsd.content_index'}`  
**Pattern**: Like web.menu_generator (simple in-memory hash)

### Module 2: httpsd.route_template_request  
**Purpose**: Route requests (ACME → API → Template → Static)
**Should Return**:
```perl
{
    'type' => 'template',           # or 'acme', 'api', 'static'
    'path' => '/blog/post.html',
    'template_path' => '...',       # if template
    'reason' => '...',              # why routed here
}
```
**Pattern**: Like httpd.route_dispatcher (simple pattern matching)

### Module 3: httpsd.template_cache (two functions)
**3a. httpsd.template_cache.get** - Retrieve cached template
**3b. httpsd.template_cache.set** - Store with TTL  
**Should Use**: TTL pattern like weather.parent.cache  
**Storage**: `$data{'httpsd.template_cache'}` with timestamps

---

## Configuration Files to Check

```
cfg/zenki/httpsd/zenka.v7       # HTTPSD config
cfg/zenki/web/zenka.v7          # Web zenka startup
cfg/zenki/letsencrypt/zenka.v7  # Let's Encrypt config
```

These define which modules load and initialization parameters.

---

## Key Insight: Namespace Decisions

Based on reading the architecture:

**Question**: Should your three modules be:
- `httpsd.*` (HTTPS-layer focus)?
- `web.*` (Content-layer focus)?
- Split between both?

**Answer from architecture**: 
- Content scanning/indexing → `web.*` (content domain)
- Request routing → `httpsd.*` (HTTP layer)
- Caching → Either, but likely `web.*` (content caching)

**Recommendation**:
- `web.scan_content_directories` (content indexing)
- `httpsd.route_template_request` (HTTP routing)
- `web.template_cache.get` + `web.template_cache.set` (content caching)

---

## Next Steps (Token Efficient)

### Phase 1: Understanding Complete ✅ (This session)
- Read existing architecture (NEW_ZENKA_ARCHITECTURE.md)
- Read template hierarchy (VHOST_TEMPLATE_HIERARCHY.md)
- Review session status files
- Understand current modules
- Identify cache patterns

### Phase 2: Refactor Your Modules (Next)
1. Convert 3 Perl modules → 4 Protocol-7 modules
2. Use correct namespace (web.* vs httpsd.*)
3. Follow existing cache patterns
4. Minimal wrapper around existing functionality

### Phase 3: Documentation (Recommended)
1. Create: `docs/src/TEMPLATE-SYSTEM-MODULE-REFERENCE.md`
2. Create: `data/yaml/coding-tasks/web-template-caching-implementation.yaml`
3. Document: module APIs, usage examples, cache strategy

---

## Files to Refactor

Your current Perl modules:
- `/home/claude/protocol-7/src/HTTPSD/LoadCipherProfile.pm`
- `/home/claude/protocol-7/src/HTTPSD/ScanContentDirectories.pm`
- `/home/claude/protocol-7/src/HTTPSD/RouteTemplateRequest.pm`
- `/home/claude/protocol-7/src/HTTPSD/TemplateCache.pm`

Should become Protocol-7 modules (single subroutine each):
- `src/httpsd.load_cipher_profile`
- `src/web.scan_content_directories`
- `src/httpsd.route_template_request`
- `src/web.template_cache.get`
- `src/web.template_cache.set`
- `src/web.template_cache.invalidate` (optional)

---

## Critical Notes for Refactoring

1. **No `sub {}` wrapper** - Just the code body
2. **Parameters via `@_` and `shift`** - Not standard function params
3. **Call other modules**: `<[module.name]>->()` syntax
4. **Access globals**: `<config.key>` or `$code{'...'}->()` or `$data{'...'}`
5. **Naming**: Dots preserved in key (not nested hash!)
6. **For `.cmd.*` files**: Auto-wrapped with `$call` and `$reply` hashes

---

## Questions Answered

**Q1: Cache namespace?**  
A: `$data{'web.template_cache'}` (scoped to web zenka, shared with other web modules)

**Q2: Cache implementation?**  
A: Use weather.parent.cache pattern (TTL with timestamp, simple format)

**Q3: Module naming?**  
A: Split:
- `web.scan_content_directories`
- `httpsd.route_template_request`  
- `web.template_cache.get`, `web.template_cache.set`

**Q4: Documentation first?**  
A: YES - Create `docs/src/TEMPLATE-SYSTEM-MODULE-REFERENCE.md` before refactoring

---

## Reference Links

Architecture Documents:
- `/home/claude/protocol-7/docs/architecture/NEW_ZENKA_ARCHITECTURE.md`
- `/home/claude/protocol-7/docs/architecture/VHOST_TEMPLATE_HIERARCHY.md`
- `/home/claude/protocol-7/docs/architecture/LETSENCRYPT_CHILD_ZENKA_PATTERN.md`

Session Status Files:
- `/home/claude/protocol-7/docs/SESSION_STATUS_2025-11-15_web-zenka-progress.md` (routing infrastructure)
- `/home/claude/protocol-7/docs/SESSION_STATUS_2025-11-14_template-auth-completion.md` (template expansion)

Coding Style:
- `/home/claude/protocol-7/data/yaml/protocol-7-coding-style.md`

Task Files:
- `/home/claude/protocol-7/data/yaml/coding-tasks/next-session-httpsd-web-zenka-completion.yaml`
- `/home/claude/protocol-7/data/yaml/coding-tasks/httpd-async-https-expansion.yaml`

---

**Status**: Ready to proceed with refactoring modules  
**Token Budget**: ~50,000 remaining (plenty for documentation + refactoring)  
**Recommendation**: Create module reference doc first, then refactor code

#,,,,,...,,..,...,,..,,.,,.,.,,.,,...,,,,,...,..,,...,...,..,,.,.,...,,.,,,,,,
#ED2QVQ7PA3WC4XXV663FKBMIA3AH5PTP5LQM5QD4WVB5AGYHWWWY7YS3IQA4CIOHHUUZXRDFJLJV4
#\\\|KJXMHUZCKQNAWP4RQV7CVYDJQUFCBBXY7Q2RWJSY75ZZYOBECDQ \ / AMOS7 \ YOURUM ::
#\[7]AWUDR2MOSUEOEJOJHJQI7ZNKM646ZUA57CMPRBF3NUBM376HTOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
