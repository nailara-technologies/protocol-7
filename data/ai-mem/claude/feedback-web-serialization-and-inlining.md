---
name: web serialization and inlining preferences
description: default JSON+YAML parallel endpoints, inline CSS/JS for reliability — avoid /static/* dependencies by reflex
type: feedback
originSessionId: 22e240a2-b6d9-41a1-bfe7-0b6526db01b4
---
## parallel JSON + YAML for data endpoints

Where we serve data from templates/plugins [ e.g. space.v7.ax grid ],
default to **both** endpoints in parallel:

- `.json` — for browsers / inline `<script>window.x = {...}</script>` embeds
  [ natively JS-evaluable, no parser needed ]
- `.yaml` — for perl clients and humans eyeballing via curl
  [ YAML::Tiny/XS already loaded; YAML is also a stepping stone to
    native formats understood by `base.parser.config` ]

YAML is treated as a placeholder for more native Protocol-7 formats,
not as an alternative-for-alternatives-sake.

**Why:** lets perl-based clients stay in their native idiom, JS-based
clients get zero-parse-cost JSON, and future native-format migration
touches one endpoint at a time.

**How to apply:** when adding a data endpoint to a vhost or plugin,
author `foo.json.tmpl` AND `foo.yaml.tmpl` from the start. Keep the
plugin's `json-raw` / `yaml-raw` section symmetric.

## inline CSS and JS inside templates

For anything the **browser** consumes [ CSS, JS ], inline into the
template itself. Do NOT pull from `/static/*` by reflex.

**Why:** inlining restores native-application reliability to HTML pages:
- page saves as a single self-contained file [ nothing missing offline ]
- no network-latency render issues [ no FOUC, no async script race ]
- deterministic rendering regardless of `/static/` availability
- fewer requests → simpler debugging

This is a deliberate robustness choice, not a premature-optimization
concern. The ubiquity of HTML+JS rendering becomes more native-like
when we stop fragmenting the payload.

**How to apply:** when building overlays, skins, or template output,
embed `<style>` and `<script>` blocks directly. Reserve `/static/*` for
binary assets that genuinely can't be inlined [ fonts, images, large
media ]. The asset registry [ `src/web.assets.*` ] remains relevant
for those cases but doesn't need to be primed for text-only vhosts.

## future: dependency-resolved JS via dynamic templates

Planned: default JS subroutines served by the web zenka with dependency
resolution via dynamic templates — shared helpers expressed as template
includes rather than script tags. At that point format choice
[ JSON vs YAML vs native ] becomes a per-call decision rather than a
per-endpoint decision. For now, the parallel-endpoint default stands.

#,,,.,...,..,,,,.,..,,,,.,,,,,..,,.,.,.,.,,..,..,,...,...,...,..,,..,,,..,...,
#PQ67ATTRBGD6FVZJGW6B6EELZXDLFMXWGOFSSEMGLCXEAWRPMQKUPCYZXBCIL5SCGWCI3CCLPVXC6
#\\\|Y3EXARE4ZLOKXW36SVAIYEE3775ZDWADUK3YBQ3ODUBFZ26YYBE \ / AMOS7 \ YOURUM ::
#\[7]CTME4W6WHEDFFUWLLFU66EO4MIIMBMJN5AOX7YURZQYK4RGX2MDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
