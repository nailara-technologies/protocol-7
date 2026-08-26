---
name: feedback-base-swap-subs-promote-pattern
description: "how to promote a module from opt-in namespace to default-loaded-on-every-zenka: physically live under base.X, add base.X.pre_init calling base.swap_subs(base.X, X), no call-site changes needed -- confirmed precedent base.file/file"
metadata:
  type: reference
---

Confirmed 2026-07-24 while promoting `format.inline-nested` to a
default-available zenka primitive.

**The pattern**: any module physically named/loaded as `base.<X>.*` gets
auto-loaded on every zenka that loads `base.*` (nearly universal). To make
something that started life as a standalone opt-in module (requiring an
explicit `modules.load` entry per zenka) available everywhere without
touching any existing `<[X.something]>` call sites:

1. Rename the module files to live under `base.<X>.*` (e.g.
   `format.inline-nested.encode` → `base.format.inline-nested.encode`).
2. Add a new `base.<X>.pre_init` module whose body is just:
   `<[base.swap_subs]>->(qw|  base.<X>  X  |);`
3. `base.init_modules` auto-discovers and runs `pre_init`/`init_code`/`post_init`
   suffixed subs for every namespace during the standard `[init_modules]`
   startup phase (confirmed via `bin/Protocol-7:1590` regex matching those
   three suffixes) — no wiring needed beyond adding the file.
4. At that pre_init step, `base.swap_subs('base.X', 'X')` RENAMES (not
   aliases — deletes the source name) every `$code{'base.X.*'}` sub back
   down to `$code{'X.*'}`, so every pre-existing `<[X.something]>` call site
   keeps working completely unchanged.
5. Drop the old explicit `modules.load` entry for `X` from any zenka config
   that had one (e.g. `cube/start`) — no longer needed since it now rides
   along with `base.*`.

**Exact precedent, not invented for this session**: `base.file.pre_init`
already does exactly this (`<[base.swap_subs]>->('base.file', 'file')`) —
found by reading `base.init_modules`/`base.file.get_swapped_subs_pairs`
before assuming this was a new idea.

**Why this matters over just editing every zenka's `modules.load`**: zero
call-site changes, and it's the established idiom, not a workaround.

## correction, 2026-07-25

Point 3 overstated confidence: "`base.init_modules` auto-discovers and
runs `pre_init`/`init_code`/`post_init` ... no wiring needed beyond
adding the file" — true of `base.init_modules` itself, but it can only
call a sub that already exists in `%code`, and `bin/Protocol-7`'s
deferred-stub installer would silently skip giving a stub to any nested
`base.<X>.pre_init` unless `<X>` happened to already be whitelisted.
`base.file` (this file's own confirmed precedent) has the exact same
one-segment-past-`base` shape as `base.base32`, so it was exposed to the
identical risk — it likely only worked in practice because `file`/
`base.file` ended up whitelisted somewhere along the way, not because
the gate handled it generically. Fixed in
[[bug-swap-subs-nested-lifecycle-hook-gate]] (`e90dd04ae`): the gate now
accepts lifecycle hooks nested anywhere under the loading namespace, so
step 2-3 of this pattern now hold unconditionally, as originally claimed.

## related

[[topic-p7-text-formats-landed]]
[[bug-swap-subs-nested-lifecycle-hook-gate]]

#,,,.,,,.,,.,,,..,.,,,,,.,,.,,,,,,..,,.,,,...,..,,...,...,.,.,,.,,,.,,,,.,,..,
#2YTOBPJZN7ZSZGZKHK4TOJJOETTUMX3AL74UY2VWEOVMORPZOGZFUCL37XGDQJ4EKHY3MJPJL37J4
#\\\|AM3E6WUFTTF5CP5K4MPPTFKNC64KPHIA7EN3XXG4WWGDS7FSE4F \ / AMOS7 \ YOURUM ::
#\[7]4IVVH5QAXIJGNL3VVJ3PMUQPIT5DH4IKDSQVYLMD3WXPN4ASWSDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
