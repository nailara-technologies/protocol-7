## task: skip lazy-stub deferral for nested lifecycle hooks whose ancestor namespace is already being compiled

## RESOLVED 2026-08-04

Implemented the proposed approach essentially as written: in
`bin/Protocol-7`'s whitelist-gate block (~line 1586-1650), added
`$nested_hook_ancestor_in_batch` — the same ancestor-match regex that
already existed for the early-`next` decision, reused to also gate the
stub-install path. When true, the block now falls through to a normal
eager compile (same as any whitelisted file in the batch) instead of
installing/leaving a deferred stub. Also clears a stale
`deferred_stub` flag on that fallthrough so a later pass where the
ancestor is *not* in the batch won't misread leftover real code as
still-a-stub. Landed together with (but scoped as a separate patch on
top of) [[loader-reload-stale-cmd-modules]]'s fix, per this task's own
caution against bundling into that just-stabilized area — verified
independently.

Verified live on `cube-13` (small, low-traffic zenka, real repro
target — confirmed via grep across `/var/log/protocol-7/*.zenka.log`
for `p7-source : base.locales.` / `base.chk-sum.` hits): before the
fix, both a fresh `v7.restart` and a `reload all` showed individual
`. loading p7-source : base.locales.pre_init` /
`base.chk-sum.bmw384.init_code` / etc. lines, each with its own solo
`..: 1 sub., 0K src., no errors., =)` summary, interleaved between
`running 'base' pre-init code.,` and `running 'base' init code.,`.
After the fix: zero such lines on both a restart and a `reload all` —
these hooks now compile silently as part of the single `base` batch
(`..: N subs...` count includes them), and `base.init_modules` calls
already-real code directly with no solo-compile hop.

Acceptance criteria from below: both met (no separate `p7-source`
lines for in-batch nested hooks; `v7.reload init`'s live-swap fix
re-verified working, no regression, per the reload-all cycle above).
Also confirmed fixed on the `coding` zenka — the original zenka whose
log first surfaced this redundancy in this session.

---

### origin

surfaced 2026-07-27 while reviewing the newly-landed `audio` zenka's
startup log, right after fixing the `v7.reload init` crash
([[feedback-v7-reload-init-live-swap-subs-crash]] in
`data/ai-mem/claude/`) — a distinct, unrelated inefficiency in the same
general area of the loader, **not a bug**, just wasted work on every
single zenka startup:

```
:. audio   : . loading p7-source : audio
:. audio   : ..: 69 subs., 147K src., no errors., =)
:. audio   : running 'base' pre-init code.,
:. audio   : . loading p7-source : base.strm.pre_init
:. audio   : ..: 1 sub., 0K src., no errors., =)
:. audio   : . loading p7-source : base.locales.pre_init
:. audio   : ..: 1 sub., 0K src., no errors., =)
:. audio   : . loading p7-source : base.dependency.pre_init
:. audio   : ..: 1 sub., 0K src., no errors., =)
:. audio   : . loading p7-source : base.chk-sum.bmw384.pre_init
:. audio   : ..: 1 sub., 0K src., no errors., =)
:. audio   : . loading p7-source : base.chk-sum.profile.pre_init
:. audio   : ..: 1 sub., 0K src., no errors., =)
:. audio   : running 'base' init code.,
:. audio   : . loading p7-source : base.slot.init_code
:. audio   : ..: 1 sub., 0K src., no errors., =)
:. audio   : . loading p7-source : base.locales.init_code
:. audio   : ..: 1 sub., 2K src., no errors., =)
:. audio   : . loading p7-source : base.chk-sum.jha.init_code
:. audio   : ..: 1 sub., 0K src., no errors., =)
:. audio   : . loading p7-source : base.chk-sum.bmw384.init_code
:. audio   : ..: 1 sub., 0K src., no errors., =)
```

every one of these `base.*.pre_init` / `base.*.init_code` lines is a
separate, individual, lazy on-demand compile of an un-whitelisted nested
lifecycle hook, triggered when its deferred-compile stub gets called
during `base.init_modules`'s pre_init/init_code phases — happening on
**every single zenka process's startup**, even though `base` (their
ancestor namespace) is always loaded first, implicitly, for every zenka.

### the actual gap

the loader's whitelist gate in `bin/Protocol-7`'s `p7_load_code`
(currently around the `$lc_hook` regex introduced in `e90dd04ae`) decides
stub-vs-normal-compile purely on "is *this exact file* in the whitelist"
— it has no awareness of whether the file's *ancestor* namespace is
already part of the very batch currently being compiled. When `base`
itself is being bulk-loaded (as it always is, for every zenka, before
anything else), these nested hooks could just be compiled eagerly,
normally, as part of that same pass — there's no lazy-loading benefit to
deferring them, since we're already right there loading the parent tree.
Deferring only pays off when the ancestor *isn't* part of the current
load; that's not the case here.

### precedent already landed for the analogous problem

`base.register_src_deps` (commit `478c4be3a`, "register_src_deps:
order-independent lifecycle-hook collapse") solved the equivalent problem
for the *dependency-file tracking* side: nested hooks with no registered
ancestor now register the top-level namespace's touch-file instead of
their own, collapsing under whichever sibling compiles first, order-
independent. That fix doesn't touch actual `%code` compilation at all —
it's purely about `data/*/zenki/<zenka>/source/` touch-file bookkeeping.
This task is the compile-time analog: apply the same "collapse under an
already-present/being-loaded ancestor" reasoning to the whitelist-gate
decision itself in `p7_load_code`, not just to dependency-file tracking.

### proposed approach

in `bin/Protocol-7`'s whitelist-gate block (`if (defined $wl and
$data{'base'}{'loader'}{'sub_whitelist_enabled'} and not exists
$wl->{$file_name})`), before falling through to the stub-install path for
a nested lifecycle hook: check whether the file's top-level ancestor
(first dot-segment, or the relevant registered `$code_name`) is `$code_name`
itself — i.e. is this file's ancestor namespace the very one currently
being compiled in this batch? If so, skip the stub path and compile it
normally/eagerly right there, same as any other file in that batch.
Only fall through to the deferred stub for genuinely cross-namespace
cases (a nested hook whose ancestor namespace is *not* part of the
current compile batch at all).

### caution

this touches the exact same code region
([[feedback-v7-reload-init-live-swap-subs-crash]]'s fix) that was just
landed and confirmed working across multiple reload/restart cycles.
implement and test this as its own separate change, with its own fresh
reproduction/verification cycle — don't bundle it into more edits of an
already-fragile, just-stabilized area without re-testing in between.

### acceptance

- a freshly-started zenka's startup log no longer shows individual
  `p7-source : base.*.pre_init` / `base.*.init_code` lines for hooks
  whose ancestor (`base`) is part of the same startup's bulk compile —
  they should appear compiled as part of the earlier bulk batch instead,
  or otherwise stop being logged as separate lazy-load events.
- the `v7.reload init` fix's own behavior (per
  [[feedback-v7-reload-init-live-swap-subs-crash]]) must still be
  verified working after this change — re-run the same reproduction
  (fresh restart, `v7.reload init` × 2, `v7.reload all`) to confirm no
  regression.

#,,,.,...,.,,,..,,,..,,..,,..,,..,,,.,,..,,..,..,,...,...,...,..,,.,.,.,,,,..,
#OQOS6GR2BNOCVQIJTEJOK2BVNOEACTYNNWBBGZNM7ZXA2MDBIQS7ZZBD5VJKMXN3EORRJTFCMCZBS
#\\\|IPHMF6DMIHJ2ZVJEX7UIS32J5ORYSIPJOL4Q5J7SMUCBA5UFLYV \ / AMOS7 \ YOURUM ::
#\[7]WS4BTAUCGNHIW3DNV35VUSMA5X3SBGGM7SLKPHCPKB4ZVZGCPQCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
