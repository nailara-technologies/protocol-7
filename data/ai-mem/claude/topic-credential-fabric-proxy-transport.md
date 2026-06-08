---
name: topic-credential-fabric-proxy-transport
description: credential_fabric/proxy/transport zenki — boot blockers fixed and committed (3349352df); live wiring still needs traffic-level verification
metadata: 
  node_type: memory
  type: project
  originSessionId: 540d7622-310e-4b0f-8485-ccf9ab5cebcd
---

Three infrastructure zenki (credential_fabric, proxy, transport) landed
their initial wiring in `21f4edfa5`, but a manual verification pass
(`data/md/development/CREDENTIAL-FABRIC-WIRING-FINDINGS.md`, commit
`c336ce62c`) found none of them could actually boot. Session 2026-06-08
dispatched fixes via kimi (`kimi_dispatch`, task files now in
`data/tasks/completed/`) and committed the result as `3349352df`.

**Fixed and committed:**
- proxy: `$proxy` bareword compile error in `proxy.handler.accept`,
  `proxy.selector.load` cwd-relative path failure, `httpd.status_codes`
  load-order in `modules.load`, `max_concurrency = 1` (was racing 3
  simultaneous instances on `127.0.0.1:8118` bind)
- credential_fabric: `cube/access.zenki` granted *prefixed* command names
  (`credential_fabric.resolve`) to the cube-side check, but routed
  commands arrive *prefix-stripped* (`resolve`) — see [[base-prefix-
  stripped]]. Fixed `access.cmd.usr.cube` to use plain names + added
  admin grants. Console can now call `.approve`/`.resolve`/`.rotate`
  without "no perm" errors.
- transport: scaffolded the entire missing config dir (`start`,
  `zenka-startup.v7`, `subroutine.white-list`, `access.zenki`, dep
  manifests), fixed `AF_INET()`/`SOCK_DGRAM()` bareword compile error in
  `transport.handle.udt-tunnel:57` (needs `()` under `strict subs` — see
  precedent `SOCK_STREAM()` in `proxy.listen`/`clients.http.request`),
  fixed `init_code` return-value semantics (see [[init-code-return-
  values]]), and **renamed `<external.transports>` → `<transport.
  registry>`** across all 11 `transport.*` modules.

**The `<external.transports>` rename — a real trap, worth remembering:**
`transport.init_code` borrowed the namespace name `<external.transports>`
from `external.init_code` ("initialize generic transport registry for
external plugins"). This LOOKED like a cross-zenka dependency (and
produced "external.init_code not loaded" boot failures), but per-zenka
isolation means `<external.transports>` inside `transport` and inside
`external` are two completely separate hashes — borrowing the name
bought nothing and created a spurious, *unsafe* apparent dependency
(loading the real `external.init_code` would have scheduled live orbital
auto-connect timers — see `external.init_code:44-72` — wildly
inappropriate inside `transport`). The fix was to seed the registry
locally (`<external.transports> //= {}`) and then rename the namespace
to its own (`<transport.registry>`) once the safety analysis confirmed
none of `transport`'s actual usage (`profiles`/`quality`/`demoted`/
`active`/`stats.connections_ok`) depended on anything `external.init_code`
uniquely provides.

**Open / not yet verified (from the original findings doc, still relevant):**
- live traffic-level acceptance items — header injection reaching
  upstream, transport-handle reuse in `proxy.outbound.connect_or_use`,
  on-demand auth (407/pending/approve flow) — none of these were
  exercisable while the zenki couldn't boot; now that they can, these
  need a live HTTP round-trip test through the proxy
  (`127.0.0.1:8118`) — **remember `NO_PROXY=127.0.0.1` for any curl
  test**, or the system-wide hysteria proxy will interfere
- `subscribe_rotation` wildcard (`*`) bug — rotation cache flush still
  broken (open issue #6 in the findings doc)
- 6 hardcoded `var/credential_fabric/...` paths bypass `file.zenka_dir.*`
  — confirmed live: a stray run created `bin/var/credential_fabric/`
  (cwd-relative, wrong location) with real key material (`fabric.public`,
  `fabric.secret`, `store`); cleaned up with `rm -rf bin/var`, but this
  is now a p0-adjacent fix, not just portability debt
- `credential_fabric.resolve`/`.rotate`/`.subscribe_rotation`/`.register`/
  `.request-authorization` are plain subroutine modules, not `.cmd.`
  command modules — they exist as internal APIs but aren't registered as
  console-callable; `credential_fabric.list` doesn't exist at all (spec
  vs. implementation mismatch, flagged but not yet resolved)
- `credential_fabric.cmd.approve` has a separate, pre-existing argument-
  parsing bug ("missing req_id" even when args supplied) — discovered by
  kimi mid-session, undocumented before now

#,,,.,,,.,.,,,,.,,,.,,...,...,.,,,,,.,.,.,,.,,..,,...,...,...,..,,,..,.,.,.,.,
#P5BAXCYT62SMBSCEHUVVI4O3OIX5JLZ3FU2VOC65JBKVZM2PMFQB4I3HSPHSZB2ZEZ6F72UJDPANY
#\\\|6I72HOWYOZLXZ3UZDZGBCGOE22JSLOCHWNCLBE75U32WGGUTMR7 \ / AMOS7 \ YOURUM ::
#\[7]ZE2KDO4I5Z4R7CV4PFZZ3LXUXPXXC6DEYVWS6HPOTQUZ2JLGFYBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
