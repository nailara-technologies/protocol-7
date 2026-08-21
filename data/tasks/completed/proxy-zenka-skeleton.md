# task: proxy zenka — generic skeleton + request context

## context

the p7 native web stack needs a proxy zenka as the central interception
and routing point. it sits between the web-browser zenka and the network,
intercepts all HTTP/HTTPS requests, builds a typed request context, routes
through the template selector, and returns a transformed response.

this task covers the self-contained skeleton: intercept lifecycle, request
context hash, template selector wiring, and generic site-yaml extraction
fallback. credentials and transport selector are stubs in this phase —
they plug in cleanly once their own tasks are complete.

design reference: `data/md/design/TEMPLATE-RESOLUTION-ENGINE.md`
design reference: `data/md/development/P7-NATIVE-WEB.md`

## proxy zenka role

```
web-browser zenka
    ↓ all HTTP/HTTPS requests (configured proxy)
[proxy zenka]
    ↓ build request context hash
    ↓ template selector (domain/url/mime assertions)
    ↓ resolve template against context
    ↓ renderer adapter: HTML (for browser) or typed data (for other zenki)
    ↓ return transformed response
```

the proxy is a thin orchestrator. it does not implement extraction,
rendering, or auth itself — it routes to the appropriate zenki and
assembles the result.

## request context hash — stable schema

every template selector assertion and code_ref receives this hash.
define it once here; all downstream code depends on it:

```perl
{
    session   => {
        user        => $user,
        zenka_name  => $calling_zenka,
        transport   => $transport_type,   ## 'direct' stub for now
        ntime       => $ntime,
    },
    request   => {
        domain      => $domain,
        url         => $full_url,
        method      => $method,           ## GET POST etc
        headers     => $headers_hashref,
        mime_type   => $mime,             ## from Accept or response Content-Type
        path        => $path,
        query       => $query_string,
    },
    auth      => {
        has_session => FALSE,             ## stub — credential fabric phase
        slots       => {},                ## stub — credential fabric phase
    },
    transport => {
        type        => 'direct',          ## stub — transport selector phase
        quality     => 1.0,               ## stub
        loss_rate   => 0.0,               ## stub
    },
    env       => {
        renderer_type => 'html',          ## html | tty | gtk3 | json | data
        tty_cols      => undef,
        tty_rows      => undef,
    },
}
```

## template selector — domain/url/mime routing

the proxy routes each request through a template selector that maps
assertions to named templates. assertion types in priority order:

```
1. static   — exact match on context key (renderer_type, method)
2. regex    — pattern on domain, url, path, mime_type
3. code_ref — arbitrary Perl, receives context hash
4. zenka    — async query (stub in phase 1, real in later phase)
5. fallback — generic.proxy.template
```

selector config lives in `data/yaml/web-proxy/template-selector.yaml`:

```yaml
rules:
  - regex:    "\\.(pdf|PDF)$"
    on_path:  true
    template: document.proxy

  - regex:    "\\.(jpg|jpeg|png|gif|webp|svg)$"
    on_path:  true
    template: image.passthrough

  - regex:    "\\.(js|css|woff2?)$"
    on_path:  true
    template: asset.passthrough

  - static:   { request.method: CONNECT }
    template: tunnel.passthrough

  fallback:   generic.proxy
```

domain-specific rules are loaded from
`data/yaml/web-proxy/domains/<domain>.yaml` and merged after global rules.

## generic extraction — site-yaml fallback

for domains without a specific template, the proxy runs site-yaml extraction:

```
proxy intercepts GET https://example.com/article
    ↓
site-yaml.fetch_and_parse 'example.com/article'
    ↓
structured yaml: { title, author, date, body, links, images }
    ↓
generic.proxy template renders it as clean p7-style HTML
    ↓
served to browser
```

failed extraction falls back to pass-through with stripping of known
noise elements (ads, tracking pixels, cookie banners).

## passthrough templates

some request types need no transformation — pass through unchanged:

- `image.passthrough`  — images referenced by content
- `asset.passthrough`  — CSS, JS, fonts (needed for page function)
- `tunnel.passthrough` — CONNECT method (WebSocket, TLS tunnel)

passthrough templates forward the request unchanged and return the
response unchanged. they exist as named templates so they can later
be replaced with richer behavior without changing the selector.

## interaction logging

every proxied request appends to the visit log:

```yaml
# data/yaml/web-proxy/visit-log.yaml entry:
domain:            example.com
last_visit:        <ntime>
visit_count:       42
extraction_quality: 0.87   ## 0..1, scored by llm or heuristic
template_used:     generic.proxy
```

`data/yaml/web-proxy/adapter-candidates.yaml` is derived from the visit
log — domains with high visits × high value × low complexity are promoted
as candidates for native zenka adapters.

## modules to create

- `src/proxy.init_code` — initialize, register as httpd child or
  standalone, load selector config, start request loop
- `src/proxy.handler.request` — main intercept handler: build context
  hash, run selector, dispatch to template resolver, return response
- `src/proxy.selector.load` — load + merge global and domain selector
  rules from yaml config
- `src/proxy.selector.match` — walk rules in priority order, return
  matched template name
- `src/proxy.template.resolve` — dispatch to site-yaml or passthrough,
  assemble typed result
- `src/proxy.log.visit` — append to visit-log.yaml, update
  adapter-candidates.yaml
- `src/proxy.template.generic` — generic p7-style HTML renderer for
  extracted content
- `src/proxy.template.passthrough` — forward unchanged

## configuration

`cfg/zenki/proxy/zenka.v7` — standard zenka start file
`cfg/zenki/proxy/start.cfg` — runtime params:

```
proxy.cfg.listen_port    = 8118
proxy.cfg.selector_config = data/yaml/web-proxy/template-selector.yaml
proxy.cfg.visit_log       = data/yaml/web-proxy/visit-log.yaml
proxy.cfg.transport       = direct    ## stub — transport selector phase
```

## stub integration points

the following are defined as stubs in this phase. each has a clear
interface so parallel tasks can implement them without changing the proxy:

```perl
## credential lookup — stub returns undef (no session)
<[proxy.auth.lookup]>->($context)   ## → { has_session, slots } or undef

## transport selection — stub returns 'direct'
<[proxy.transport.select]>->($context)   ## → transport config hashref

## zenka template assertions — stub always returns false
<[proxy.selector.zenka_assert]>->($rule, $context)   ## → true/false
```

## harmony checks

run before implementation:

```
harmony proxy.init_code
harmony proxy.handler.request
harmony proxy.selector.match
harmony proxy.template.resolve
harmony proxy.log.visit
```

## dispatch notes

- implement modules in order listed above — init_code last
- use `data/md/development/P7-LLM-REFERENCE.md` for verified p7 patterns
- request context hash schema is fixed — do not add fields without updating
  `TEMPLATE-RESOLUTION-ENGINE.md` first
- stub integration points must remain callable with the defined signature
  even when not yet implemented — return safe defaults

## signatures note

do not modify or regenerate any AMOS7 signature lines. the signing system
handles all footer blocks — leave them untouched.

## codebase findings

### existing patterns to reuse

**httpd handler registration — four patterns available:**
1. **Protocol method binding** (`cfg/zenki/httpd/zenka.v7`): `http.handler.get = httpd.http_get` — `httpd.request_handler` looks up `<http.handler>->{ lc $request->{method} }` and calls the coderef with `$id`. The proxy handler should register as `http.handler.connect = proxy.handler.request` (and potentially override GET/POST when proxy mode is active).
2. **Route registry** (`cfg/zenki/httpd/routes`): parsed by `httpd.route.init_code` into `$data{'httpd'}{'route'}{'exact'}{$method}{$path}`. `httpd.route_dispatcher` returns `{ handler => 'module.name', handler_args => { ... } }`. Good for proxy status/debug endpoints.
3. **Hard-coded routes in `httpd.route_dispatcher`**: the `plugin.httpd.radio` stream endpoint is checked via state vars (`<plugin.httpd.radio.active>`, `<plugin.httpd.radio.stream.path>`). The proxy could use the same pattern for an intercept toggle.
4. **Async dispatch via `protocol-7.route-send`**: used by `httpd.process_template` and `httpd.route.handler.web-relay`. The proxy should use this to call `site-yaml.extract` and later the credential fabric.

**Request context hash — already populated by `httpd.request_handler`:**
Inside any handler receiving `$id`, the session hash `$data{'session'}{$id}{'http'}{'request'}` contains `method`, `uri`, `headers`, `host`, `client` (addr/port), etc. This is the source for building the proxy's request context hash.

**Async HTTP client for outbound fetching:**
- `src/clients.http.request` — blocking connect → non-blocking → `event.add_io` with `clients.http.handler.io`
- `src/clients.https.request` — same plus `IO::Socket::SSL` handshake handler `clients.https.handler.handshake`
- Socket I/O: `<[base.s_read]>->($sock, \$chunk, 65536)` and direct `syswrite`
- These are the baseline for passthrough and generic extraction fetch.

**site-yaml extraction API:**
- `src/site-yaml.extract` — entry point: `<[site-yaml.extract]>->($url)` returns hashref on success, error string on failure.
- `src/site-yaml.http.get` — uses `LWP::UserAgent` (`$data{'site-yaml'}{'ua'}`), calls `$ua->env_proxy`.
- `src/site-yaml.cmd.fetch` — wraps extract in protocol-7 reply: `{ mode => 'size', data => $yaml }` or `{ mode => 'false', data => $error }`.
- **Critical limitation:** only `stepstone.de` extractors exist (`site-yaml.stepstone.job`, `site-yaml.stepstone.search`). There is **no generic `fetch_and_parse`** that accepts an arbitrary domain.

**Plugin pattern (for reference):**
- `src/plugin.httpd.radio.init_code` — initializes state vars, sets stream path.
- `src/plugin.httpd.radio.cmd.radio_online` — activates endpoint, invalidates route cache.
- `src/plugin.httpd.radio.handler.stream_request` — HTTP handler that sends headers then issues `protocol-7.route-send` → `radio.listen`.
- `src/plugin.httpd.radio.handler.strm_open` — reply handler that registers `base.strm.local.register` consumer.
- Note: there is **no generic plugin hook API** in httpd. The radio plugin integrates via hard-coded checks in `httpd.route_dispatcher`.

**web-browser proxy setup (for reference, not reuse):**
- `src/web-browser.proxy_setup` and `src/web-browser.disable_proxy` configure `Gtk3::WebKit2::NetworkProxySettings`. These are **GTK3/WebKit proxy config helpers**, not an intercepting HTTP proxy. They are unrelated to the planned proxy zenka except in name.

### integration points confirmed

**Where the proxy hooks into httpd:**
1. Add `proxy` to `modules.load` in `cfg/zenki/httpd/zenka.v7` (or run as standalone zenka). Given the task spec says "register as httpd child or standalone", note that httpd config **does not declare child zenki** — it loads src/plugins into the current zenka via `[load_modules:...]`. A standalone proxy zenka would need to be spawned by v7 and communicate over route-send.
2. Register method handler in `cfg/zenki/httpd/zenka.v7`: `http.handler.connect = proxy.handler.request`.
3. For full interception of GET/POST, the proxy needs to either:
   - Override `http.handler.get` / `http.handler.post` when proxy mode is on, OR
   - Use a hard-coded check in `httpd.route_dispatcher` (like radio), OR
   - Be a standalone zenka that the web-browser zenka routes through.
4. The task spec envisions the proxy as a **standalone zenka** between web-browser and network. The web-browser zenka already has proxy config helpers (`web-browser.proxy_setup`). The simplest integration is: configure the web-browser to use `localhost:8118` as HTTP proxy, run the proxy as its own zenka, and have it make outbound requests via `clients.http.*`.

**site-yaml integration:**
- Proxy calls `<[protocol-7.route-send]>->({ command => 'site-yaml.cmd.fetch', call_args => { args => $url }, reply => { ... } })`.
- Reply handler (`proxy.handler.site_yaml_reply`) receives the SIZE reply and continues template resolution.

**Template selector wiring:**
- The selector config (`data/yaml/web-proxy/template-selector.yaml`) can be loaded by `proxy.selector.load` using existing YAML loading patterns (e.g., `AMOS7::13::read_yaml` or similar).
- `httpd.route.init_code` parses flat text routes; `proxy.selector.load` should parse YAML instead.

### naming conflicts or overlaps

- `src/web-browser.proxy_setup` / `web-browser.disable_proxy` — name collision on "proxy" but completely different function (WebKit proxy settings vs. intercepting proxy). Not a real conflict since namespaces differ (`web-browser.*` vs `proxy.*`).
- **No existing `src/proxy.*` files** — the namespace is clean.
- `src/httpd.handler.web-relay.response` — handles web-relay replies. The proxy's reply handlers should use distinct names (`proxy.handler.*`) to avoid confusion.

### gaps in the task spec

1. **How does the proxy intercept ordinary GET/POST?** The task says "web-browser zenka ↓ all HTTP/HTTPS requests (configured proxy)" but doesn't specify the mechanism. The web-browser uses WebKit; configuring it as a proxy client requires calling `web-browser.proxy_setup` with `localhost:8118`. This is a **required integration step** not listed in the task.
2. **site-yaml has no generic extractor.** The task assumes `site-yaml.fetch_and_parse 'example.com/article'` works for any domain. In reality only `stepstone.de` is implemented. Generic extraction (LLM reframe or heuristic HTML→YAML) needs to be built or the fallback to "raw-but-cleaned HTML" must be the primary path.
3. **No httpd child-zenka mechanism exists.** The task says "register as httpd child or standalone." httpd config does not spawn child zenki. If the proxy runs inside httpd, it's a module. If standalone, it needs its own `cfg/zenki/proxy/` directory and v7 startup config.
4. **Renderer adapter "HTML" for browser is underspecified.** The task references `TEMPLATE-RESOLUTION-ENGINE.md` but there is no existing HTML renderer adapter in the codebase. `httpd.process_template` uses a template engine, but it's not the same as the deferred rendering model described in the design doc.
5. **passthrough template forwarding** — "forward the request unchanged" implies the proxy makes an outbound HTTP request and streams the response back. The async client pattern (`clients.http.handler.io`) accumulates the full response before firing `on_done`. For true passthrough (streaming), a different pattern is needed: register an IO watcher that copies bytes from the outbound socket to the HTTP session's output buffer as they arrive.
6. **visit-log.yaml and adapter-candidates.yaml atomic updates** — appending to YAML files from multiple concurrent requests requires locking. The task doesn't mention this. Existing patterns: `credentials.read_archive` / `write_archive_file` use file-based locking via `IO::AIO` or simple rename swaps.

### suggested refinements

1. **Run proxy as standalone zenka, not httpd child.** The httpd zenka has no child-zenka spawning mechanism. A standalone `proxy` zenka with `cfg/zenki/proxy/zenka.v7` and `start.cfg` is cleaner. It listens on `localhost:8118`, accepts HTTP proxy requests, and uses `clients.http.*` / `clients.https.*` for outbound. Integration with httpd is then just a route for health/status if desired.
2. **Reuse `clients.http.request` for outbound, but add a streaming variant.** The existing client accumulates full response. For passthrough/images/assets, create `clients.http.request_streaming` that copies chunks directly to a target filehandle/session via `base.stream.push` or direct `base.s_write`.
3. **Defer generic site-yaml extraction to Phase 2.** Since only stepstone.de has extractors, the Phase 1 skeleton should treat generic extraction as a stub that returns `{ error => 'no_extractor' }` and falls back to passthrough with content-type-based stripping (HTML gets ad-stripped, images pass through).
4. **Use `base.handler.hooks` for proxy lifecycle hooks if needed.** It exists but is unused by httpd. The proxy zenka could use it for pre-request / post-request hooks without inventing new infrastructure.
5. **Add a `proxy.cfg.listen_address` defaulting to `127.0.0.1`.** The task only specifies `listen_port = 8118`. Binding to `127.0.0.1` is essential for security.

## refined module list

The original list is sound but needs two additions for the standalone-zenka model:

- `src/proxy.listen` — create listening socket (IO::Socket::IP), accept connections, spawn per-connection handler
- `src/proxy.handler.connection` — per-connection request parser (lightweight HTTP::Request or hand-rolled), builds context hash, calls `proxy.handler.request`

These replace the implicit "httpd child" integration. If the proxy runs inside httpd instead, these are unnecessary and `proxy.handler.request` receives `$id` directly.

The `proxy.handler.request` module should be split into two variants if both models are kept:
- `proxy.handler.request.standalone` — accepts a client socket directly
- `proxy.handler.request.httpd` — accepts `$id` session from httpd

**Recommendation:** commit to standalone model and add `proxy.listen` + `proxy.handler.connection`.

#,,,.,,,.,.,.,,.,,,,,,,..,,,.,...,,,.,,..,..,,..,,...,...,..,,,.,,,,,,...,,,,,
#LK4AZ72V5SFVEN6DVDV72SCJLVA7WB3FT5IDVLTDARPNB2TMMELI2ACU33DT2YEHDRW5RZKNPXGNC
#\\\|TF2QKGVBQPA2E4PUZP633OKZW2M62H27S45BBYUBP32NDT3DWNZ \ / AMOS7 \ YOURUM ::
#\[7]4QAZPXTWRERTPKBAIITNEB5OWEZEXT36PFELCG7PTZYJZG5JYYAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
