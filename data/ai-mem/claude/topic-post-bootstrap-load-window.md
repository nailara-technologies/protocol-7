---
name: topic-post-bootstrap-load-window
description: "SEED, design-only: hybrid deferred/eager Perl-module (and subroutine) loading -- defer to a window right after main bootstrap subsides, but trigger immediately on unexpected early use; self-optimizing later via dep-graph + timing stats. Generalizes the deferred_compile self-heal pattern from subroutines to perl module deps. Not implemented -- currently zero deferred perl-module loading exists (base.perlmod.load/autoload are both eager, see feedback-perlmod-load-noise-is-intentional)"
metadata:
  type: vision
---

Raised 2026-07-26, same conversation as
[[feedback-perlmod-load-noise-is-intentional]] and
[[bug-swap-subs-nested-lifecycle-hook-gate]].

## the idea

A "convenient" dynamic load window for Perl module dependencies (CPAN
modules loaded via `base.perlmod.load`/`autoload`), and — the user
explicitly noted — the *same* idea applies equally to P7 subroutines:

1. **Default**: defer a load until right after the zenka's main bootstrap
   burst has subsided — not "never load early," but "load in the natural
   lull once the critical startup path is done," so the expensive part
   doesn't compete with time-critical boot work.
2. **Preemption**: if real runtime usage needs the dependency *before*
   that deferred window would have serviced it, trigger the load
   immediately, right then — never silently missing, never a crash.
3. **Self-optimization, later**: once (1)+(2) exist, the system can watch
   its own dependency graph (`bin/dev/dep-graph`) plus real timing
   statistics (which subs/src actually get hit early vs. late, how
   often preemption fires vs. the deferred window firing on schedule) and
   adaptively tune which things get which treatment, instead of a fixed
   human-authored policy.

Net effect: boot time drops by offloading non-critical load work past the
critical window, while remaining exactly as reliable as eager loading —
nothing is ever missing, "started cleanly" stays a trustworthy signal.

## why this isn't just theoretical — the pattern already exists half-built

This is precisely `base.handler.deferred_compile`'s existing shape,
already landed for P7 subroutines this same session
([[bug-swap-subs-nested-lifecycle-hook-gate]]): a deferred stub sits in
`%code` until first real call, at which point it compiles on-demand,
transparently, via `goto &{...}`. The hybrid idea proposed here is that
same mechanism, generalized to also cover raw Perl module `require`s (not
just P7 module compilation), plus an explicit "or defer to a scheduled
post-boot window, whichever comes first" race between the two triggers,
plus a feedback loop (dep-graph + timing stats) that eventually decides
the window's shape itself rather than a fixed constant.

## current state (as of this note)

Confirmed: zero deferred Perl-module loading exists anywhere in this
codebase today. `base.perlmod.load` and `base.perlmod.autoload` are both
fully eager — see [[feedback-perlmod-load-noise-is-intentional]] for the
correction that `load`/`autoload` differ only in export-import behavior,
not timing. This vision note is the "possible next optimization" the
user flagged in the *same breath* as confirming that — i.e. this is
where the currently-settled "just be eager, in init_code" guidance is
expected to evolve toward, not a contradiction of it.

## status

Seed only. No design doc, no chosen scheduling mechanism for "main
bootstrap has subsided" (event-loop idle callback? a timer? explicit
end-of-init_code marker?), no chosen shape for the dep-graph/timing
feedback loop. Surface if/when actual boot-time profiling data exists to
justify picking this up, or if [[feedback-perlmod-load-noise-is-intentional]]'s
noise-driven cleanup starts surfacing enough per-call loads that a
systemic fix becomes worth the design cost over one-off `init_code`
placement moves.

#,,..,..,,,..,,.,,,,.,.,.,..,,.,.,,,,,.,,,,.,,..,,...,...,,,.,.,.,,,,,,,,,.,,,
#AAUF265AR4SSN74AA3MCX4XKRELDT5EXNETQNZVD53UKVAO6V44ISSWXQZTCIU4OUVP7OAXHR25B4
#\\\|37FT64OHGEELY7YAIJCV5RQEQ2OBCGC62SRNXM2Y2CCXYF4MVH7 \ / AMOS7 \ YOURUM ::
#\[7]VQPE4M7JAHQNPRTTGDLW5J5OLP7EORNGNFBPZX7ZF7W4AE4SHWBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
