---
name: bug-swap-subs-deferred-stub-alias-regression
description: "RESOLVED 2026-08-12: the `next if deferred_stub` guard added by the v7-reload swap_subs fix silently regressed the base32 swapped-namespace fix — two individually-correct fixes whose INTERACTION was the bug; non-whitelisted subs in a swapped namespace became permanently unreachable instead of on-demand compiled"
metadata:
  type: feedback
---

## symptom

`user-edit` gained a `<[base.zenka.loop]>` call site without
`base.event.loop` being in its `subroutines.load-early`. Expected: the
deferred-compile safety net compiles it on first call. Actual: hard
`protocol-7 subroutine event.loop not defined` at `base.zenka.loop:35`,
and the zenka refused to start. Regenerating the whitelist did NOT help —
`bin/dev/dep-graph` does not emit `base.event.loop`/`base.zenka.loop` for
this zenka even though the call sites are plainly there.

**Per user: the whitelist is NEVER supposed to prevent loading.** It
governs compile TIMING only (its own header says so) — the deferred-stub
hook is the safety net. "Not in the whitelist" must never mean
"unreachable."

## root cause — an interaction between two correct fixes

Both of these are real, individually-correct fixes that already have
their own memories:

1. [[bug-swap-subs-nested-lifecycle-hook-gate]] (e90dd04ae) — made
   `base.swap_subs` MOVE already-installed deferred stubs to the target
   namespace, and taught `base.handler.deferred_compile` to self-heal
   across a swap via `$data{'code'}{$sub_name}{'moved_to'}`.
2. [[feedback-v7-reload-init-live-swap-subs-crash]] — stopped unresolved
   stubs being mistaken for real reloaded code, so the destructive
   `undefine` wipe couldn't nuke a populated target namespace.

Fix (2) implemented "don't mistake a stub for real code" in TWO places:
the `$subs_matching` count (correct, and the part that actually prevents
the crash) **and** a `next if $data{'code'}{$sub_name}{'deferred_stub'};`
in the MOVE loop (over-application). That second guard undid fix (1):
the stub stayed only at `base.event.loop`, while every post-swap call
site uses `event.loop` — a key that then never exists in `%code` at all.
`deferred_compile`'s `moved_to` self-heal could never fire either, since
nothing could reach the stub to trigger it.

## fix (2026-08-12)

`base.swap_subs` now ALIASES an unresolved stub into the target namespace
instead of skipping it — the stub is not *moved* (its `# line 1` filename
hint names the source, which is how `base.caller` finds the real source
path), it is made reachable under both names:

```perl
if ( $data{'code'}{$sub_name}{'deferred_stub'} ) {
    if ( not exists $code{$new_sub} ) {
        $code{$new_sub}                          = $code{$sub_name};
        $data{'code'}{$new_sub}{'deferred_stub'} = TRUE;
        $data{'code'}{$sub_name}{'moved_to'}     = $new_sub;
    }
    next;
}
```

Stubs stay excluded from `$subs_matching`, so fix (2)'s actual
crash-prevention is untouched. `base.handler.deferred_compile` also now
clears the stub flag on the `moved_to` key after compiling, not just on
the source key — otherwise real compiled code keeps reading as "just a
stub" to any later swap.

**How to apply:** when a call to a swapped short name (`event.*`,
`base32.*`, `file.*`, `protocol-7.*`, `zenka.*`, `chk-sum.*`) dies with
"subroutine X not defined", do NOT hand-add it to `subroutines.load-early`
— that masks the real bug and the generator wipes the entry on the next
regeneration anyway. The whitelist is compile timing, not reachability.

**General lesson worth more than this instance:** both prior memories
describe their own fix as complete and correct, and both are. Neither
records the other's existence. When touching `base.swap_subs` /
`base.handler.deferred_compile` / `bin/Protocol-7`'s stub gate, read ALL
THREE memories first — this cluster has now produced three separate bugs
from fixes interacting, not from any one fix being wrong.

## verification scope

Verified on fresh boot: `user-edit` reaches `zenka.loop` and renders with
`base.event.loop`/`base.zenka.loop` absent from its whitelist; `keys`,
`sourcecode`, `work`, `session`, `configure` all boot clean. NOT verified
under `v7.reload init` on a live process — which is precisely the
scenario that produced the original crash in (2), so that remains the
discriminating test if anything in this cluster misbehaves later.

#,,,,,..,,,.,,,,.,,,,,,,,,,..,,,,,..,,,.,,.,,,..,,...,...,...,...,,,.,.,.,.,,,
#PHXD3RBTREFHRA4HHWRPJ4R4YO6JRBJE2TBEFCVUTYUY5ESJK4P74VKQ5XFIQF7XYVZXUKJ7A3ZOG
#\\\|AV7Y3A6L573OQ7CFTIBN4JHBEPZCGMR3BHF7TKLBM56TYB3HKWE \ / AMOS7 \ YOURUM ::
#\[7]7IV5Z6ICXEXJCTPLKZHGOXFMNE67YEV5LPPDPAZTMD4UTW5E3ADI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
