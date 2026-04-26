---
name: vhost-install
description: httpd vhost install infrastructure — DNS-gated symlink/copy deployment, letsencr TLS integration, web template aliases, local test status
type: project
originSessionId: 4eafab32-f1ff-4563-a22d-899a251afa89
---
## what was built

vhost install system: `p7c httpd.install-vhosts [:force:]`

```
data/web-root/vhosts/<hostname>/.vhost-manifest  →  YAML install descriptor
p7c httpd.install-vhosts                         →  DNS-gated install all vhosts
p7c httpd.install-vhosts :force:                 →  bypass DNS check (local test)
p7c httpd.vhost-status                           →  status table (mode 'size' reply)
p7c httpd.update-vhosts                          →  update copy-mode vhosts
```

## vhosts defined

```
space.v7.ax   →  symlinked, TLS, orbital visualization
visual.v7.ax  →  symlinked, TLS, cubic topology v14
iv.v7.ax      →  symlinked, TLS, placeholder
default       →  symlinked, no TLS, dns_match:none (always installs)
```

## local test status (Apr 2026)

all 4 vhosts installed via `:force:` — symlinks in /var/httpd/.
space.v7.ax serving:
- /visualization.html  ✓  (merged grid-v13 + orbital layer)
- /orbital.json        ✓  (live orbital data, empty while nodes zenka offline)
- /templates.json      ✓  (template resolver state)

test with: `NO_PROXY=127.0.0.1 curl -s -H "Host: space.v7.ax" http://127.0.0.1/`

## key fixes made during testing

- read_manifests: file.slurp returns scalar ref — use direct open() instead
- read_manifests: prepend system.root_path for absolute paths
- httpd.scan_site_dir: missing log levels, undef max on empty vhosts, swapped extdir args
- httpd.cmd.install-vhosts: base.file.* → file.* swap namespace
- httpd.cmd.install-vhosts: backup with base.ntime.b32 before symlink, never remove_tree
- httpd.cmd.install-vhosts: dns_match:none skips DNS check
- httpd.vhost.request_tls_cert: use letsencr.request-certificate (not internal path)
- httpd.vhost.request_tls_cert: skip if httpsd not online
- cube/access.zenki: added letsencr.request-certificate + v7.status to httpd perms
- plugin.web.space.init_code: register web.space.* aliases for template commands
  (template processor looks up code{web.space.state}, module is plugin.web.space.state)
- plugin.web.space.template-resolver.json: fix scalar/deref syntax for history_depth
- shared-params: system.web-root-* keys (hyphenated to avoid dot→hash nesting conflict)

## open items

- nodes/discover zenki not running during test → orbital.json returns empty arrays
- web-browser start file still references old data/html/ paths (web-browser zenka)
- httpsd TLS testing pending (needs httpsd online for cert requests)
- visual.v7.ax + iv.v7.ax DNS needed for remote test (or /etc/hosts entry)
- double scan on init resolved but worth monitoring

## next steps

1. start nodes + discover zenki → populate orbital.json with live data
2. open space.v7.ax in browser (add to /etc/hosts or use pri.v7.ax proxy)
3. test visualization with live orbital nodes visible
4. httpsd deployment for TLS vhosts (letsencr cert auto-request)
5. nodes.orbital → discover bridge: verify mcast packets include p7ref
6. curve engine promotion: base.curve.* from radio/mpv scope to universal animation

#,,,.,,,.,,..,..,,,..,,..,,..,,..,,,.,,..,...,..,,...,..,,..,,..,,.,.,,..,,.,,
#JXEYUFAJLWDDA5UZN5ZL7SBQXF5TZZ35EGMERQMECIJHRVTYHPJGP4EUK2EW2GOQOQDFNKWWZSDF2
#\\\|W5AWZEG7GSLV5JA2EGO4PPMXXVIVKKD22CP4B6R34FF5IGUNLEH \ / AMOS7 \ YOURUM ::
#\[7]GWD2JP7U547545MQ2JIVN7DG43XXIZZ5MWSUXBNUMTHVORLZQ6DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
