# Virtual Host & Template Hierarchy Architecture
**Version**: 1.0
**Date**: 2025-11-07
**Status**: Integrated with NEW_ZENKA_ARCHITECTURE.md
**Objective**: Map vhost structure in `/var/httpd/` to template hierarchies with nested skins and HTTPS delivery

---

## Current Vhost Structure

```
/var/httpd/
├── 127.0.0.1/                  # Virtual host by IP
│   ├── index.html
│   └── pix/
│       └── nailara_logo.png
├── default/                     # Default vhost fallback
│   ├── huge-test-file.bin       # 512MB test file
│   ├── large-test-file.bin      # 1MB test file
│   └── (dynamic content here)
└── wpad.net/                    # WPAD protocol example
    └── wpad.dat
```

### Current Features
- **Virtual Hosting**: Multiple sites per IP (vhost by domain name)
- **Subdirectory Structure**: Direct filesystem mapping to URL paths
- **Static Files**: Binary and text files served directly
- **Image Assets**: Organized in subdirectories (pix/, images/, etc.)

### Planned Extensions
- **Dynamic Templates**: Mustache/Handlebars rendering per vhost
- **Nested Skins**: CSS/design layers inherited and overridable
- **Menu Generation**: Automatic navigation from directory structure
- **HTTPS Delivery**: Each vhost served securely via httpsd

---

## Enhanced Vhost Architecture with Templates

### Proposed Directory Structure

```
/var/httpd/
├── 127.0.0.1/                              # Vhost 1: IP-based
│   ├── _templates/                         # Vhost-specific templates (template priority 2)
│   │   ├── layout.html.mustache            # Base layout for this vhost
│   │   ├── index.html.mustache             # Home page
│   │   ├── 404.html.mustache               # Error page
│   │   └── api/
│   │       └── response.json.mustache      # JSON response template
│   ├── _skins/                             # Nested skin system
│   │   ├── default/                        # Primary skin
│   │   │   ├── style.css
│   │   │   ├── colors.json
│   │   │   └── assets/
│   │   │       └── logo.png
│   │   ├── dark/                           # Dark mode override
│   │   │   ├── style.css
│   │   │   └── colors.json
│   │   └── mobile/                         # Mobile optimization
│   │       ├── style.css
│   │       └── layout.json
│   ├── _menu/                              # Menu generation
│   │   ├── main.json                       # Main menu structure
│   │   └── sidebar.json                    # Secondary navigation
│   ├── _config/                            # Vhost configuration
│   │   ├── site.yaml                       # Site metadata
│   │   ├── security.yaml                   # CSP, headers, etc.
│   │   └── features.yaml                   # Feature flags
│   ├── index.html                          # Static fallback
│   ├── pix/
│   │   └── nailara_logo.png
│   ├── blog/                               # Subdirectory with subdomain-like behavior
│   │   ├── _templates/                     # Subdirectory-specific templates (priority 3)
│   │   │   ├── post.html.mustache          # Individual post layout
│   │   │   └── listing.html.mustache       # Blog index
│   │   ├── _skins/                         # Subdirectory skin overrides
│   │   │   ├── serif-font/
│   │   │   │   └── style.css
│   │   │   └── monospace/
│   │   │       └── style.css
│   │   ├── 2025-11-07-hello-world.md       # Blog post (rendered via template)
│   │   ├── 2025-10-15-architecture.md
│   │   └── index.html.mustache             # Rendered blog index
│   └── shop/                               # Another subdirectory
│       ├── _templates/
│       │   ├── product.html.mustache
│       │   └── checkout.html.mustache
│       ├── products/
│       │   ├── product-001.json            # Product data
│       │   └── product-002.json
│       └── cart.html                       # Dynamic cart rendering
│
├── default/                                # Vhost 2: Default/fallback
│   ├── _templates/                         # Default vhost templates
│   │   ├── layout.html.mustache
│   │   └── error.html.mustache
│   ├── _skins/
│   │   └── default/
│   │       └── style.css
│   ├── huge-test-file.bin
│   └── large-test-file.bin
│
├── wpad.net/                               # Vhost 3: Domain name
│   ├── _templates/
│   │   └── wpad.js.mustache                # WPAD response as template
│   ├── _config/
│   │   └── site.yaml
│   └── wpad.dat
│
└── _global_templates/                      # Global fallback (template priority 1 - lowest)
    ├── layout.html.mustache                # System-wide base layout
    ├── 404.html.mustache
    ├── 500.html.mustache
    └── skins/
        ├── default/
        │   ├── style.css
        │   └── assets/
        │       ├── favicon.ico
        │       └── fonts/
        ├── dark/
        │   └── style.css
        └── light/
            └── style.css
```

---

## Template Resolution Hierarchy

### Priority Order (Highest to Lowest)

1. **Vhost-Subdirectory Level** (e.g., `/var/httpd/127.0.0.1/blog/_templates/`)
   - Used for: Specialized templates for specific sections
   - Inheritance: Can inherit/extend from parent vhost templates
   - Use Case: Blog posts use different layout than shop products

2. **Vhost Root Level** (e.g., `/var/httpd/127.0.0.1/_templates/`)
   - Used for: Site-wide templates for this vhost
   - Inheritance: Can inherit from global templates
   - Use Case: Main site layout, error pages, standard pages

3. **Global Level** (e.g., `/var/httpd/_global_templates/`)
   - Used for: System-wide defaults
   - Inheritance: Base templates for all sites
   - Use Case: Fallback layouts, common components

### Skin Resolution Hierarchy

```
Skin Layer Resolution:
1. Subdirectory skin override    (/vhost/section/_skins/skin-name/)
2. Vhost-specific skin          (/vhost/_skins/skin-name/)
3. Global skin                  (/_global_templates/skins/skin-name/)
```

Example: If user requests "dark" skin for blog post:
```
1. Check /var/httpd/127.0.0.1/blog/_skins/dark/style.css
2. If missing, use /var/httpd/127.0.0.1/_skins/dark/style.css
3. If missing, use /var/httpd/_global_templates/skins/dark/style.css
4. If missing, use /var/httpd/_global_templates/skins/default/style.css
```

---

## Menu Generation System

### Automatic Menu from Directory Structure

The template engine can automatically generate menus from directory structure:

```
/var/httpd/127.0.0.1/
├── index.html              → Menu: "Home"
├── about/
│   └── index.html          → Menu: "About"
├── blog/
│   ├── 2025-11-07-post.md  → Menu: "Blog › Posts"
│   └── index.html          → Menu: "Blog"
└── shop/
    └── index.html          → Menu: "Shop"

Generated Menu JSON:
{
  "items": [
    { "label": "Home", "path": "/", "icon": "home" },
    { "label": "About", "path": "/about/", "icon": "info" },
    {
      "label": "Blog",
      "path": "/blog/",
      "submenu": [
        { "label": "Posts", "path": "/blog/posts/" },
        { "label": "Categories", "path": "/blog/categories/" }
      ]
    },
    { "label": "Shop", "path": "/shop/", "icon": "shopping-cart" }
  ]
}
```

### Menu Configuration Override

```
/var/httpd/127.0.0.1/_menu/main.json
{
  "items": [
    { "label": "Home", "path": "/", "icon": "home", "priority": 1 },
    { "label": "Blog", "path": "/blog/", "priority": 2 },
    { "label": "Shop", "path": "/shop/", "priority": 3, "new": true },
    { "label": "About", "path": "/about/", "priority": 4 }
  ],
  "exclude_paths": ["/_config/", "/_templates/"],
  "auto_discover": true
}
```

---

## Integration with Existing HTTPD

### Request Flow: Static File → Template → HTTPS

```
Client (HTTPS)
  │
  ├─> httpsd zenka (decrypt TLS)
  │     │
  │     └─> [forward to httpd]
  │
  ├─> httpd zenka (handle request)
  │     │
  │     ├─> Determine vhost from Host header
  │     │   Example: 127.0.0.1 → /var/httpd/127.0.0.1/
  │     │
  │     ├─> Check for static file
  │     │   /var/httpd/127.0.0.1/pix/logo.png → Serve directly
  │     │
  │     ├─> Check for template-based content
  │     │   /var/httpd/127.0.0.1/blog/post.md
  │     │     ├─> Load _templates/post.html.mustache (priority 2)
  │     │     ├─> Load post.md content
  │     │     ├─> Request template zenka to render
  │     │     │
  │     │     └─> template zenka (render content)
  │     │           │
  │     │           ├─> Determine skin preference
  │     │           │   From: query param, cookie, or default
  │     │           │
  │     │           ├─> Resolve skin hierarchy
  │     │           │   Check blog/_skins/dark/ → vhost/_skins/dark/
  │     │           │   → global_templates/skins/dark/
  │     │           │
  │     │           ├─> Render template with context
  │     │           │   {
  │     │           │     title: "Hello World",
  │     │           │     content: "<html>...",
  │     │           │     skin: "dark",
  │     │           │     menu: {...}
  │     │           │   }
  │     │           │
  │     │           └─> Return rendered HTML
  │     │
  │     ├─> Build response
  │     │   Add headers (CSP, X-Frame-Options, etc.)
  │     │   Add cache headers
  │     │
  │     └─> Send to httpsd
  │
  ├─> httpsd zenka (encrypt response)
  │     └─> Send to client (HTTPS)
  │
  └─> Client Browser (display)
```

### Multiple Skin Support

```
GET /blog/post.html?skin=dark
  → Renders with /var/httpd/127.0.0.1/blog/_skins/dark/ styles

GET /blog/post.html?skin=mobile
  → Renders with /var/httpd/127.0.0.1/blog/_skins/mobile/ styles

GET /blog/post.html
  → Renders with default skin (from _skins/default/)
```

---

## Module Extensions Required

### Template Zenka Extensions

**template.vhost_resolver**
- Determine vhost from Host header or filename
- Locate vhost root directory in `/var/httpd/`
- Validate vhost configuration

**template.template_resolver**
- Implement priority hierarchy resolution
- Search for templates in priority order
- Cache resolved template paths
- Handle cascading inheritance

**template.skin_resolver**
- Resolve skin hierarchy
- Support user preference (query param, cookie, device)
- Merge skin layers (base + overrides)
- Generate CSS cascade

**template.menu_generator**
- Scan directory structure
- Generate menu from filesystem
- Apply menu configuration overrides
- Cache menu structure
- Support submenu depth

**template.content_processor**
- Detect content type (HTML, Markdown, JSON, etc.)
- Convert Markdown → HTML (if needed)
- Parse front-matter/metadata
- Inject into template context

**template.cache_invalidator**
- Monitor `/var/httpd/` for changes
- Invalidate related caches
- Handle vhost/subdirectory changes
- Rebuild menu on directory changes

### HTTPD Zenka Extensions

**httpd.vhost_dispatcher**
- Route requests to specific vhost handler
- Parse Host header
- Validate vhost exists
- Set vhost context

**httpd.static_or_template_router**
- Determine if path is static file or template
- Check for template markers (_templates/, etc.)
- Decide to serve directly or delegate to template zenka
- Set appropriate headers

---

## Configuration Examples

### Vhost Configuration: /var/httpd/127.0.0.1/_config/site.yaml

```yaml
vhost:
  name: "127.0.0.1"
  enabled: true
  ssl: true

templates:
  engine: "mustache"
  cache_ttl: 3600
  precompile: true

skins:
  available:
    - default
    - dark
    - mobile
  default: default
  allow_user_override: true
  persistence: cookie  # or session, query_param

menus:
  auto_discover: true
  max_depth: 3
  include_indices: false

content:
  markdown_support: true
  frontmatter_parser: yaml

security:
  content_security_policy: "default-src 'self'"
  x_frame_options: "SAMEORIGIN"
  x_content_type_options: "nosniff"
  referrer_policy: "strict-origin-when-cross-origin"

performance:
  cache_static: true
  compress_html: true
  minify_css: true
```

### Blog Subdirectory Overrides: /var/httpd/127.0.0.1/blog/_config/site.yaml

```yaml
templates:
  default_template: "post.html.mustache"

skins:
  default: serif-font
  available:
    - serif-font
    - monospace

content:
  date_format: "%Y-%m-%d"
  excerpt_length: 200

menus:
  show_archive: true
  show_categories: true
  group_by_date: true
```

---

## File Type Mapping

### Template Rendering by Extension

```
.html.mustache      → Render as HTML template
.json.mustache      → Render as JSON template
.xml.mustache       → Render as XML template
.css.mustache       → Render as CSS (dynamic stylesheets)
.js.mustache        → Render as JavaScript
.md                 → Convert to HTML, then render in layout template
.json               → Load as data, pass to template context
.yaml               → Load as config, pass to template context
.html               → Serve as-is (static)
.png/.jpg/.gif      → Serve as-is (static assets)
```

---

## Security Considerations

### Template Sandbox
- Restrict template operations (no shell commands)
- Validate all context data
- Escape output by default
- Prevent path traversal (../ in template names)

### Vhost Isolation
- Each vhost operates in isolated context
- Cannot access files outside its directory
- Cannot access other vhosts' private config (_config/, _skins/)
- Enforce filesystem boundaries

### Menu Security
- Don't expose hidden directories (_templates/, _config/)
- Validate menu paths before generation
- Sanitize user-provided skin names

---

## Examples: End-to-End Flows

### Example 1: Rendering Blog Post with Dark Skin

```
Request: GET https://127.0.0.1/blog/2025-11-07-hello-world.md?skin=dark

Flow:
1. httpsd receives HTTPS request
2. httpsd decrypts and forwards to httpd
3. httpd detects vhost: 127.0.0.1 → /var/httpd/127.0.0.1/
4. httpd checks for static file: /var/httpd/127.0.0.1/blog/2025-11-07-hello-world.md
   → File exists but is .md, not static HTML
5. httpd forwards to template zenka with:
   {
     vhost: "127.0.0.1",
     path: "/blog/2025-11-07-hello-world.md",
     skin: "dark",
     query: { skin: "dark" }
   }
6. template zenka:
   a. Resolves template path
      → Check /var/httpd/127.0.0.1/blog/_templates/post.html.mustache ✓
   b. Loads Markdown content and parses
   c. Resolves skin hierarchy
      → Check /var/httpd/127.0.0.1/blog/_skins/dark/style.css ✓
   d. Renders template with context:
      {
        title: "Hello World",
        content: "<h1>Hello World</h1><p>...</p>",
        skin: "dark",
        menu: { ... generated from directory structure ... },
        css: "/* dark skin CSS */"
      }
   e. Returns rendered HTML
7. httpd adds headers:
   Content-Type: text/html
   Cache-Control: public, max-age=3600
8. httpsd encrypts and sends to client via HTTPS
```

### Example 2: Shop Product Listing with Skin Switch

```
Request: GET https://127.0.0.1/shop/?skin=mobile

Flow:
1. httpd detects path /shop/ exists
2. Checks for /var/httpd/127.0.0.1/shop/index.html
   → Doesn't exist, check for template
3. Finds /var/httpd/127.0.0.1/shop/_templates/listing.html.mustache
4. Loads product data from /var/httpd/127.0.0.1/shop/products/*.json
5. template zenka renders with:
   {
     products: [ { id: 001, name: "Widget", ... }, ... ],
     skin: "mobile",
     menu: { ... },
     layout: "listing"
   }
6. Mobile skin applied:
   → /var/httpd/127.0.0.1/shop/_skins/mobile/style.css
   → Full-width layout, touch-friendly buttons
```

---

## Performance Optimizations

### Caching Strategy
1. **Template Cache**: Compiled templates cached by path
2. **Menu Cache**: Directory structure cache with inotify/stat watching
3. **Skin Cache**: Resolved skin layers cached
4. **Content Cache**: Rendered HTML cached with TTL
5. **Asset Cache**: CSS/JS files cached by hash

### Cascade Invalidation
- When /var/httpd/vhost/_menu/main.json changes → invalidate menu cache
- When /var/httpd/vhost/_skins/ changes → invalidate skin cache
- When /var/httpd/vhost/_templates/ changes → invalidate template cache

---

## Deployment Checklist

- [ ] Create `/var/httpd/_global_templates/` with base layouts
- [ ] Create vhost-level `_templates/`, `_skins/`, `_menu/`, `_config/`
- [ ] Deploy httpsd zenka with certificate support
- [ ] Deploy template zenka with Mustache support
- [ ] Configure cache invalidation (file watchers)
- [ ] Set up monitoring (render times, cache hit rates)
- [ ] Test vhost switching (Host header routing)
- [ ] Test template inheritance (priority hierarchy)
- [ ] Test skin resolution (multi-layer CSS)
- [ ] Load test (concurrent requests, cache pressure)

---

## Integration Points with IMPLEMENTATION-CHECKLIST.md

This vhost/template architecture should be reflected in:
- [ ] HTTPSD zenka extended to support vhost routing
- [ ] Template zenka extended with vhost/skin resolution
- [ ] New test suite: vhost switching, template inheritance, skin layers
- [ ] Performance benchmarks: menu generation, cascade invalidation

---

**Status**: Ready for implementation in Phase 2 (Template Zenka)
**Next Step**: Implement vhost_resolver and template_resolver modules
**Contact**: Protocol-7 Development Team

```

#,,,.,.,,,...,,,.,,,.,,,.,,..,...,,,,,.,,,,..,...,...,...,.,,,...,,.,,..,,..,,
#J7ARUDJ66QYLJR2FBGPVV3MSTXP4TYRNXOBNASFQQCFPPGNADYYF5BRZDHYIVNJWRRPBHE3L5A3MC
#\\\|SRJOPNZUSYYBW7IMHTZAXJJAOFLPMP2FJG52BOYHYZIKVJ3PLBY \ / AMOS7 \ YOURUM ::
#\[7]HCOVWDKNQ433YQDK6GKFFGPSNUVI47NJ3MA6HMQ7RY6XS4TC5OAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
