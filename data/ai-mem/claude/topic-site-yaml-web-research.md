---
name: site-yaml web research
description: safe web research for coding zenka via checksum-capability tokens + two browsing modes
type: project
---

## design

site-yaml zenka acts as a safe web research proxy for the coding zenka.
models never see raw URLs — only AMOS checksum IDs that site-yaml resolves
internally. web is treated as strictly read-only.

## flow

1. `site-yaml.search query=<q>` — queries DuckDuckGo (expandable to other
   engines), returns results as:
   `[AMOS_ID] title / snippet` — one per line
2. `site-yaml.fetch id=<AMOS_ID>` — site-yaml resolves checksum→URL
   internally, fetches page, returns cleaned text + extracted links,
   each link also checksummed and tracked
3. coding zenka only ever calls fetch with IDs it received from a prior
   search or fetch — cannot construct arbitrary URLs

## checksum-as-capability

- AMOS chksum of the URL = stable ID for that resource
- site-yaml maintains chksum→URL map with TTL (in-memory or zenka_dir)
- model builds a local reachable graph without ever seeing URLs
- IDs received = permissions granted — no escalation possible

## two browsing modes

**same-site** (default, stricter):
- only follows links within the same domain as the initial fetch
- enforced by site-yaml, not the model
- good for: documentation, job listings, any structured site navigation

**open-research** (explicit opt-in):
- follows cross-domain links, still only via checksums
- model cannot self-escalate to this mode — set at task/config level
- site-yaml logs cross-domain hops for audit trail

## cleanup tiers

- level 1: regex strip — `<script>`, `<style>`, nav/footer by class, whitespace collapse. fast, zero cost.
- level 2: readability heuristic (Mozilla Readability or equivalent) — extracts main content block
- level 3: small inference model pass — for JS-heavy or ad-saturated pages; expensive, minority use

## TTL design (open question)

- per-task: map cleared on task complete — safest
- per-session: persists across tasks until expiry — more useful for multi-task doc browsing
- likely: per-session with explicit expiry config key

## second-level link tracking

when fetching a page, site-yaml:
- extracts all links from the page
- assigns each an AMOS checksum
- returns them inline (prefixed with checksum) so model can follow them
- in same-site mode: only same-domain links are tracked/returned
- in open-research mode: all links tracked, cross-domain hops logged

## integration with coding zenka

- new tools: `web_search`, `web_fetch` — thin wrappers over site-yaml commands
- tool definitions added to coding zenka tool set
- search results and fetched content flow through normal tool response path
- mode selection via coding zenka config or per-task parameter (not model-controlled)

## starting point

- DuckDuckGo HTML search (no API key needed, scrape results page)
- site-yaml already has domain regex/template pattern infrastructure
- AMOS chksum already available via `<[base.chk-sum.amos]>`

#,,..,.,.,.,.,,,.,,..,,,,,,..,,.,,,,.,,..,..,,.,.,...,...,.,,,...,,..,,.,,,,,,
#43BOXOK5XNCQ7DZR3LQUFIETNXKAEPBQIK3HDSHD44YEUGH5UMXQBMLZL3AWLNFKIPOU2QZLTAIS4
#\\\|G4QSJ3YT4Z6O46LVNUGOKXYTB3HJTEWXMK6WCKBX2LFZN2HCABD \ / AMOS7 \ YOURUM ::
#\[7]MBCCZAFLAPRDLKIOUV4DV7UHKEEU6CBTX32HXUOX2HZCI4CVGICA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
