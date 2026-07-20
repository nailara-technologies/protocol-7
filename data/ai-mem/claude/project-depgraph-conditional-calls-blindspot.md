---
name: depgraph-conditional-calls-blindspot
description: "bin/dev/dep-graph (backing base.handler.whitelist_miss self-heal) does static literal-call analysis and doesn't understand base.mod.exists-gated call_optional/call_expected — conditional cross-namespace deps drop out of whitelists after the eval->call_optional migration"
metadata: 
  node_type: memory
  type: project
  modified: 2026-07-20T12:07:28.492Z
  originSessionId: e4370102-a3e1-4def-83e3-83a02fdc5959
---

Landed in `c3870ebe5` (base: gate whitelist_miss self-heal on namespace
readiness, not eval): replaced `eval { <[crypt.C25519.load_from_string]>->() }`
and three unguarded `source.*` calls in `base.handler.whitelist_miss` with
`base.mod.exists('source')` gate + `base.code.call_optional`/`call_expected`.
See [[feedback-undef-sub-scanner-verification]] for the verification method
used.

After regenerating all `subroutine.white-list` files, the whitelists
**shrank** — the crypt/source routines dropped out of zenki that don't
actually load those namespaces, since the calls are no longer literal
unconditional `$code{'name'}->()` references `bin/dev/dep-graph` picks up
as hard deps.

**Why this matters:** this is the intended effect (a zenka that never loads
`source`/`crypt.C25519` shouldn't whitelist their subs), but it means
`dep-graph`'s static analysis has a blind spot for the new pattern: it
can't currently express "this dependency is conditional on
`base.mod.exists(ns)`," so it either (a) over-reports as before (flagging
subs that are never reachable in a given zenka), or (b) under-reports post-
migration (a zenka that legitimately *does* load the namespace at runtime
but wasn't caught by static scan loses the whitelist entry it needs).
Confirmed this shrinkage is symptom-correct for zenki that don't load
`source`/`crypt.C25519`, but the tool itself has not been taught the new
conditional-call pattern.

**How to apply:** before trusting a post-migration whitelist regen as
complete, spot-check that zenki which *do* load the gated namespace at
runtime (e.g. any zenka with `source`/`crypt.C25519` in `modules.load`)
still retain the subs they actually call. `bin/dev/dep-graph` itself is the
next thing to teach about `base.mod.exists`-gated `call_optional`/
`call_expected` if this eval→pattern migration continues across other
files — not urgent, flagged by the user as "complicated."

#,,..,,.,,.,,,.,.,,..,.,.,.,.,,,,,..,,.,.,,,.,..,,...,..,,...,,..,,.,,,.,,,,.,
#M6FYT7EAFUEL2NUZ5XW3YQGAX725YETB5VEC743Y36I4C2R7JH65A7ZDEQDRZLEHSUN46OCFOAGKM
#\\\|5IC2L2XR6TVW2CTYPCL73KNW5BWJGW4UTPVM7S3FBHUR6TCFZKM \ / AMOS7 \ YOURUM ::
#\[7]FYD2743VIE5B4S3VMBRM4NDG5KPIBKJOBHVLODKY2XKURLXD5CDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
