---
name: feedback-v7-reload-init-live-swap-subs-crash
description: "RESOLVED, confirmed: bare 'v7.reload init' on a live process crashed the whole backend via base.swap_subs's destructive 'undefine' wipe firing on a stale/partial snapshot. root cause: an un-whitelisted nested lifecycle hook (v7.zenka.init_code) can compile/resolve slightly later than its whitelisted sibling (v7.zenka.pre_init), so a later swap_subs call finds it 'alone' and reads that as evidence of a full reload, wiping 44 already-correct target subs to make room for the 1 straggler. fixed via (1) flagging unresolved deferred-compile stubs so they're never mistaken for real reloaded code, and (2) gating the destructive wipe to fire at most once per real compile generation, tracked PER-NAMESPACE (not a shared global counter, which falsely triggers on any unrelated namespace's reload). directly reproduced, root-caused via live debug instrumentation, and confirmed fixed across multiple reload/restart cycles."
metadata:
  node_type: memory
  type: feedback
  originSessionId: 16c8ce74-d9e2-429d-bafb-25fae9c0c30f
  modified: 2026-07-27T00:00:00.000Z
---

## incident (2026-07-26)

while Kimi K3 was implementing the new `audio` zenka
([[project-audio-waveform-visualization-landed-2026-07-26]]), the entire
`v7` supervisor process crashed and took down all managed sub-processes,
including the `coding` zenka mid-round:

```
: [id] < source code reinit >
: running 'v7' init code.,
: 'undefined value as subroutine reference [v7.init_start_setup:33]
: module 'v7'-init not successful [ init_code != [0|5] ]
: :. no zenki to start found, giving up..,
: v7 zenka shutdown [ .. N sub-processes ., ]
```

trigger: a bare `reload init` — not `reload all` — on the live,
already-running `v7` process. directly reproduced on demand, repeatedly,
before being root-caused and fixed.

## root cause, fully traced via live debug instrumentation

`v7.init_start_setup:33` calls the bare short name `<[zenka.is_enabled]>`,
which only exists in `%code` because `v7.zenka.pre_init` runs
`base.swap_subs('v7.zenka', 'zenka')`. adding temporary debug output
directly into `base.swap_subs` (dumping every matching source sub, every
existing target sub, and the wipe/move outcome, gated to the `v7` zenka
only) made the mechanism directly observable:

```
<swap_subs DEBUG> v7.zenka -> zenka [ policy=undefine ] : 1 source subs found
<swap_subs DEBUG>   source: v7.zenka.init_code                       status=no-error
<swap_subs DEBUG> 44 existing target subs before undefine step
...
<swap_subs DEBUG> WIPE FIRED : v7.zenka->zenka
<swap_subs DEBUG> MOVE DONE [ moved=1 ] : v7.zenka -> zenka
<swap_subs DEBUG>   post-move probe zenka.is_enabled : exists=0 coderef=0
```

`swap_subs`'s `'undefine'` policy is *supposed* to wipe the entire target
namespace and refill it from whatever currently exists under the source
prefix — this is Protocol-7's normal, intentional reload semantic, and
it's correct: confirmed working the same way for other families (e.g.
`locales`) in the same log, which just degrade gracefully
(`zenka has no locale text data..`) when their source is sparse. The bug
was never in that design.

**The actual mechanism**: `v7.zenka.init_code` is a real file
(`src/v7.zenka.init_code`) that is *not* whitelisted in
`cfg/zenki/v7/subroutines.load-early` — unlike its sibling
`v7.zenka.pre_init`, which is. The loader (`bin/Protocol-7`, commit
`e90dd04ae`, "loader: make swap_subs-moved namespaces reachable without
whitelist regen") installs a deferred-compile stub for such nested,
un-whitelisted lifecycle hooks so `base.init_modules` can call them —
which is correct and intentional. But that stub can resolve to real,
compiled code on a *different* pass than its whitelisted sibling — pre_init
always runs before init_code, so on a fresh compile the sibling's own
swap already moved everything else away by the time this straggler
resolves. A *later* `swap_subs` call then finds this one real, resolved
sub sitting alone under the source prefix and — correctly, by its own
logic — reads that as "there's reloaded code," triggering the full
destructive wipe to make room for just that one sub. 44 real, entirely
correct `zenka.*` subs (including `zenka.is_enabled`) get wiped to
restore only 1.

## fix (implemented and confirmed working)

Three files, two complementary mechanisms:

**1. Stub-awareness** (`bin/Protocol-7`, `base.handler.deferred_compile`,
`base.swap_subs`): every deferred-compile stub is now flagged
`$data{'code'}{$name}{'deferred_stub'} = TRUE` at install time, cleared
the moment real code resolves at that key. `swap_subs` excludes anything
still flagged from `$subs_matching` and from the move loop — an
unresolved stub's mere presence can never trigger the destructive wipe.
This alone was necessary but *not sufficient* — a stub that resolves to
real code between two `swap_subs` calls (the actual `v7.zenka.init_code`
case) is no longer a stub by the second call, and would still trigger a
false wipe without the second mechanism.

**2. Per-namespace generation gating** (`bin/Protocol-7`,
`base.swap_subs`): the destructive `'undefine'` wipe now fires at most
once per real compile generation for a given `(source,target)` pair —
tracked via `$data{'base'}{'loader'}{'namespace_generation'}{$code_name}`,
recorded per top-level namespace actually present in each compile batch's
`%module_code_map`, not a single shared `$load_seq` counter. This
distinction mattered in practice: an early version of the fix used the
flat global counter and was directly disproved by a reproduction — any
*unrelated* namespace's `source` reload (e.g. `audio`) bumped the shared
counter and made `v7.zenka` falsely look like it had a fresh generation
too, re-arming the wipe. The per-namespace version fixed this: `swap_subs`
walks `$source_sub_prefix` from most- to least-specific dot-segment
(`'v7.zenka'` → not a registered code_name → `'v7'` → is one) to find the
generation that's actually relevant to its own namespace.

A repeat `swap_subs` call within the *same* namespace-generation now
skips the wipe but still runs the additive move step — so a late-resolving
straggler like `v7.zenka.init_code` gets correctly migrated into
`zenka.*` without disturbing anything already there.

**Confirmed via direct reproduction**: fresh restart, `v7.reload init`
survives cleanly (`WIPE SKIPPED [ gen=2, last=2 ]`, `MOVE DONE [moved=1]`,
`post-move probe zenka.is_enabled : exists=1 coderef=1`), full startup
completes normally, and two further `v7.reload init` calls plus a full
`v7.reload all` all succeed afterward with `v7.heart` responding each
time. Debug instrumentation was removed once confirmed; the three files
carry the permanent fix.

## scope: v7-specific trigger, general-purpose fix

The *crash* was v7-specific: `cube`'s bare `reload init` was checked
directly and does not crash (no equivalent self-referential swap family
depending on a fresh recompile the way `v7.zenka` does). But the
*mechanism* that caused it — an un-whitelisted nested lifecycle hook
resolving on a different pass than its whitelisted sibling — is not
v7-specific, and the fix lives in the shared `swap_subs`/loader code, so
it protects every family using this pattern, not just `v7.zenka`.

## design note surfaced during the fix

`base.swap_subs`'s `overwrite_policy` parameter already has an
`'if_missing'` mode that looks, at first glance, like it would fix this —
it doesn't: `'if_missing'` means "only populate if not already present,"
which would permanently freeze a family at whatever code first migrated
in, silently discarding any later `source` reload's updated code. The
per-generation gate implemented here effectively makes the *first*
`'undefine'`-policy call in a generation behave as the wipe, and any
subsequent same-generation call for that pair behave like an implicit
additive/`if_missing` call — without a caller having to request that
explicitly. Nobody currently calls `swap_subs` that way on purpose, but
the primitive's existing policy vocabulary already anticipates a
deliberate "wipe once, then compose additively" use case, if one ever
comes up.

## proper long-term fix

This is an interim fix within the current loader architecture. The
structural fix is the planned version-aware loader
(`data/md/coding-tasks/version-aware-loader.md`): compiling into a
separate staged `%CODE` hash and atomically swapping the whole namespace
only once verified successful, with rollback. That eliminates this whole
class of problem by construction — including a related, distinct edge
case flagged during this investigation: even `reload source` itself could
in principle leave some modules stale (no swap update) while others wait
indefinitely for a reinit that never comes, under the current
incrementally-mutated-in-place `%code` design. Not urgent today, but a
reason to keep this as an interim patch, not a place to keep investing
further architecture-level effort.

## related

- [[topic-zenka-restart-intent-propagation-resumption]] — the broader
  vision-level gap this incident exposed: a zenka crash currently means
  "no zenki to start found, giving up," not automatic recovery.
- superficially resembles [[bug-swap-subs-nested-lifecycle-hook-gate]]
  (resolved e90dd04ae, a different family: `base32`/`chk-sum.bmw`) — that
  commit is in fact what *introduced* the mechanism (nested-hook deferred
  stubs) this bug exploited, by making such stubs reachable in more cases
  than before. Different root cause, same general territory
  (swap_subs + lifecycle timing).
- corrects [[feedback-v7-zenka-startup-config-placement]]'s old advice to
  use bare `v7.reload init` as an alternative to `v7.reload all` — that's
  no longer dangerous now that this fix is in, but the note's original
  reasoning (before the fix) was wrong to suggest it as safe.

#,,..,..,,,..,,..,,..,.,,,.,.,.,,,.,.,,,,,,..,..,,...,...,.,.,.,,,...,,,.,..,,
#M3Z5ONIZZYFAN3SWKAD6CYMNEQOIVSBSPQ7G3TAMBVNH26QC7JXWNQXFY5YQS54CY54AMISRLHNZY
#\\\|PSVFD7YIL3FXFT2PRXXZJXW76MJGEAYDA3DAYVE3KCCRYD6DDP3 \ / AMOS7 \ YOURUM ::
#\[7]AR2PVF4G6SNI3RWYZYW3N2HOW7ZBT2LC67XA2HOKIXCZNUVCTOCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
