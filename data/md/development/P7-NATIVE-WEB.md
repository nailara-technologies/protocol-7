# p7 native web — progressive web integration

## vision

the web exists as a legacy data layer. protocol-7 progressively absorbs
it: starting with a local proxy that reframes any site into p7-style
layout, evolving through site-yaml adapters, arriving at native zenki
that replace the proxy entirely for high-value sites.

the proxy is not just a renderer — it is a learning system. every visit
is data. every interaction pattern is a specification. the llm zenki read
that data and decide where to invest tokens building the next native
adapter.

---

## the proxy intercept layer

all web-browser zenka traffic routes through a local http proxy:

```
web-browser zenka
    ↓ all requests
[p7 web proxy]
    ↓
site-yaml template (if exists for domain)
    ↓
llm reframe (normalize to p7 layout)
    ↓
rendered in web-browser zenka — clean, dark blue, semantic
```

the proxy is transparent to the browser. it intercepts, transforms,
and re-serves. the user sees a p7-native version of every site.

### what gets stripped

- advertisements and tracking pixels
- navigation chrome (menus, breadcrumbs, sidebars)
- cookie banners, popups, overlays
- social share buttons, comment sections
- decorative images unrelated to content
- third-party scripts

### what gets kept

- article/document body text
- structured data (tables, lists, code blocks)
- images directly referenced by content
- links that are part of the content flow
- semantic headings and structure

### p7 layout normalization

every page becomes:
```
#000013 background
clean typography (white-rabbit or similar monospace)
content in single reading column
images inline with caption
data tables normalized to p7 list format
external links marked [ext]
```

---

## site-yaml as extraction engine

the site-yaml zenka already extracts structured yaml from web pages.
the proxy makes this universal — every visited page runs through
site-yaml extraction automatically:

```
proxy intercepts GET https://example.com/article
    ↓
site-yaml.fetch_and_parse 'example.com/article'
    ↓
structured yaml: { title, author, date, body, links, images }
    ↓
p7 layout template renders it
```

existing site-yaml domain templates apply automatically. unknown domains
get a generic extraction attempt. failed extractions fall back to
raw-but-cleaned html.

### template improvement loop

each visit to a domain:
1. current template attempts extraction
2. llm evaluates extraction quality (did it get the right content?)
3. if poor: llm proposes template improvement
4. template updated for next visit
5. over time: templates become highly accurate per-domain

---

## llm reframe pipeline

for domains without site-yaml templates, or for complex layouts:

```
rendered dom (from web-browser zenka evaluate_javascript)
    ↓
llm zenka: identify main content region
    ↓
llm zenka: extract semantic structure
    ↓
llm zenka: generate p7-normalized html
    ↓
served to browser
```

the llm has access to:
- the full dom tree (via browser zenka js evaluation)
- the visual layout (via get_snapshot)
- the page's semantic signals (headings, article tags, main element)

this is not scraping — it is semantic understanding of live rendered pages.

---

## interaction tracking → adapter priority

the proxy records:
```
data/yaml/web-proxy/
  visit-log.yaml          ← domain, frequency, last-visit, extraction-quality
  interaction-patterns/
    <domain>.yaml         ← what actions users take on this site
  adapter-candidates.yaml ← ranked list: visits × complexity × value
```

`adapter-candidates.yaml` is the product roadmap:

```yaml
stepstone.de:
  visits:        847
  llm_tokens:    24000    ## spent reframing per month
  complexity:    medium
  value:         high     ## job applications = high value
  status:        native   ## jobsite zenka already built

youtube.com:
  visits:        312
  llm_tokens:    8000
  complexity:    high
  value:         medium
  status:        candidate ## yt-dlp + browser session pattern ready

github.com:
  visits:        256
  llm_tokens:    3000
  complexity:    low
  value:         high
  status:        candidate ## git operations via api already possible
```

sites with high visits × high value × low complexity → build native zenka next.

---

## convergence path

### stage 1: proxy reframe
- every site gets p7-style rendering
- generic extraction, llm fills gaps
- interaction patterns logged

### stage 2: site-yaml adapter
- domain-specific templates improve extraction
- structured data available to other zenki
- credentials zenka handles auth sessions

### stage 3: native zenka
- zenka implements site's actual api or dom interaction
- no proxy needed for this site
- other zenki can call it directly
- jobsite zenka is the reference implementation

### stage 4: full integration
- site-specific capabilities exposed as p7 commands
- other zenki compose with it
- the "site" ceases to be a website and becomes a p7 service

---

## capability cross-pollination

the proxy, browser zenka, and llm zenki share capabilities:

```
proxy capabilities:
  + web-browser zenka tools: dom access, js evaluation, screenshots
  + llm zenki: semantic understanding, template generation
  + site-yaml zenka: structured extraction
  + credentials zenka: authenticated sessions
  + dom filesystem mount (plan-9): expose dom as files

web-browser zenka capabilities:
  + llm capabilities: understand page intent, extract meaning
  + proxy awareness: knows when content is reframed
  + view stack: multiple sites simultaneously in light mode

llm zenki capabilities:
  + browser tools: see rendered page, not just html
  + proxy feedback: improve extraction templates
  + interaction pattern analysis: learn site behavior
```

the system becomes self-improving: each component's output improves
the others. the proxy learns faster extraction. the browser understands
pages better. the llm has richer context for each domain.

---

## credential and session management

for authenticated sites, the proxy works with the credential + auth relay
architecture:

```
proxy intercepts request to authenticated.site.com
    ↓
credentials zenka: is there a session for this domain?
    ↓ yes → inject cookies/headers
    ↓ no  → auth relay: request user authorization
              web-browser zenka: show approval dialog
              credentials zenka: perform login
              session stored (encrypted, per-client key)
```

the user sees seamless authentication. the credential private key
never leaves the detached key holder child process.

---

## connection to existing zenki

| existing zenka | role in p7 native web |
|---|---|
| site-yaml | extraction templates, domain parsing |
| jobsite | reference native adapter (stepstone) |
| web-browser | renderer, dom access, js evaluation |
| httpd/httpsd | proxy transport layer |
| credentials | session management, auth relay |
| ssh/sftp | remote credential delivery |
| coding zenka | llm reframe pipeline |
| kimi-web | heavy analysis, template improvement |
| plan-9 | dom filesystem mount |
| data zenka | interaction tracking, adapter candidates |

---

## implementation order

1. **proxy intercept** — route web-browser zenka through local httpd
2. **generic extraction** — site-yaml on every request
3. **p7 layout template** — normalize rendered output
4. **interaction logging** — track visits + patterns
5. **llm reframe** — for domains without templates
6. **template improvement loop** — llm refines per-domain
7. **adapter priority queue** — data/yaml/web-proxy/adapter-candidates.yaml
8. **credential integration** — proxy-aware session management
9. **dom filesystem mount** — plan-9 + data zenka
10. **native adapter pipeline** — tooling to accelerate zenka creation
    from adapter-candidates.yaml

#,,..,,..,.,,,,,.,,,,,.,,,...,.,.,,,,,,..,,,.,..,,...,..,,,..,,.,,..,,.,,,...,
#KGNUFI4PP736WALNAN5VEBW5SWROLXCYZIEBEEIEHR564H3J6WEWH7GX3WIKZVEG4GBPMXRQSITP6
#\\\|V22HEVDKEQOKBDOJM6FPAA226LTVKOTKGTE7Q7GXTZKIOUR7RPG \ / AMOS7 \ YOURUM ::
#\[7]NQQAH54CDIZNDBRIGNCTRCZ3NFQXD56ZAL5XXAPZDU7M6DPWK2DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
