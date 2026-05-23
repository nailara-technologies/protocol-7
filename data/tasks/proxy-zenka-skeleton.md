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

- `modules/proxy.init_code` — initialize, register as httpd child or
  standalone, load selector config, start request loop
- `modules/proxy.handler.request` — main intercept handler: build context
  hash, run selector, dispatch to template resolver, return response
- `modules/proxy.selector.load` — load + merge global and domain selector
  rules from yaml config
- `modules/proxy.selector.match` — walk rules in priority order, return
  matched template name
- `modules/proxy.template.resolve` — dispatch to site-yaml or passthrough,
  assemble typed result
- `modules/proxy.log.visit` — append to visit-log.yaml, update
  adapter-candidates.yaml
- `modules/proxy.template.generic` — generic p7-style HTML renderer for
  extracted content
- `modules/proxy.template.passthrough` — forward unchanged

## configuration

`configuration/zenki/proxy/start` — standard zenka start file
`configuration/zenki/proxy/zenka-startup.v7` — runtime params:

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

#,,,,,,.,,.,.,...,,..,,.,,,,.,,,.,...,.,.,,,.,..,,...,...,.,,,,,.,,,.,,.,,,,.,
#IPG4GUF3TS6QR5XHY5K7V4HEIVPG5TMLOL53GGS7L2MZBTM4FAGAEGGRLJ4FXNX43HPRWW2PVPVIU
#\\\|5IMENTRNEFHFYGNKVOAPDTYDX2RPO2APSLKPTWIKTAHPFKD646N \ / AMOS7 \ YOURUM ::
#\[7]A4PIFZCMNWZPTWPJQAIYCLB3OGU3SHCVJP66OMG27QFQNOOYVWBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
