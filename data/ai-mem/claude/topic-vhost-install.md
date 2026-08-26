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

## status (Apr 26 2026)

orbital pipeline fully live:
- nodes/discover/external/web/httpd/graphics-matrix all running
- orbital.json: self + known populated, glow_shells/channel/graph from graphics-matrix
- visualization renders at space.v7.ax via local httpd (Host: header)
- POST /context handled, zoom/intent stored in web.space.templates.context
- self-echo test: discovered node appears in known[] (same coords as self — overlap expected)
- real second node needed to see distinct visualization elements

## open items

- web-browser start file still references old data/html/ paths
- httpsd TLS testing pending
- visual.v7.ax + iv.v7.ax DNS needed for remote test
- graphics-matrix.orbital-sync: channel.palette empty (no multi-node cells yet)
- glow_shells strings not numbers in JSON ("1.00000" vs 1.0) — viz parseFloat handles it
- kimi reconnect auto-approval fix deployed but not yet stress-tested

## key fixes made this session (Apr 26 2026)

- send.local → route-send in web plugin fetch modules (replies never arrived)
- nodes.orbital-position: mode=size key=value (REF stringification fix)
- discover.orbital.get_local_p7ref: nodes push pattern (route-send, not reply handler)
- all multi-dot command names fixed: .cell.place/.cursor.set/.glow.compute → single-dot
- graphics-matrix idle timeout: 23s → 420s
- cube/access.zenki: web + httpd + discover + nodes permissions fully wired

#,,..,,.,,,..,,,,,,,.,,,.,.,,,...,...,,..,,,.,..,,...,...,,,.,..,,...,..,,...,
#4JSXTE5XSKVWFYGCONL2SHK72GLF3VWBACOIGCOJWNR456A3VCWAKUTWHSH6TEJTXEJ6NXFXP7FI4
#\\\|IQVHHYYGTQRX22VO2PCI5KSMEIAQTNEQ4GV6NZJND5DPBUGWQSZ \ / AMOS7 \ YOURUM ::
#\[7]BTW6IWQMKDH5U7XZDKONWKVHTI6M6N6BWL4HDISNPCMEHN4XZSCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
