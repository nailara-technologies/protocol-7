---
name: feedback-perlmod-load-noise-is-intentional
description: "base.perlmod.load/autoload's 'skipping already present X..,' log-level-2 noise is a deliberate nag to surface redundant per-call loads for cleanup, not a bug to silence -- also corrects a mistaken belief that load vs autoload differ in load timing (they don't, both eager; the real axis is export behavior, and where in the code -- init_code vs per-call handler -- the call sits)"
metadata:
  type: feedback
---

Landed 2026-07-26 while converting `bin/format-code` and
`coding.tools.handler.perltidy` off subprocess `perltidy` calls onto
`Perl::Tidy`'s in-memory API ([[bug-swap-subs-nested-lifecycle-hook-gate]]
is the unrelated but same-session P7-module-lazy-compile counterpart of
this same tension).

## the noise is a feature, not a bug

`base.perlmod.load`/`autoload` log `": skipping already present '%s'..,"`
at level 2 every time they're called for an already-loaded module. First
instinct on seeing this repeat is "this is spam, either silence the log
level or make the check quieter." **Wrong response.** User confirmed:
it's deliberately slightly annoying *on purpose*, specifically so a
redundant per-call load (e.g. `coding.tools.handler.perltidy` calling
`<[base.perlmod.load]>->('Perl::Tidy')` on every single tool invocation,
instead of once in `coding.init_code`) gets *noticed* and *fixed* — not
tolerated by turning the volume down. Concrete precedent the user cited:
`AMOS7::Twofish` noise in `p7-log` under `-vv` is the exact same pattern,
already on their list, and was literally the reason the `base.vax-int.*`
routines got migrated onto the `base32.*` wrapper earlier this session.

**How to apply:** when this noise shows up during testing, the correct
fix is always "move the load call to the zenka's `init_code` (or wherever
it's actually only needed once)," never "quiet the log line" or "wrap
every call site defensively" — the latter treats the symptom the nag is
specifically designed to surface as a variable to be silenced.

## `load` vs `autoload`: export behavior only, NOT timing (corrected)

Got this wrong initially and was corrected: `base.perlmod.load` and
`base.perlmod.autoload` are **both eager** — each calls
`Module::Load::{load,autoload}( $module_name, @export )` synchronously,
right there in the statement, the moment it's reached. Neither defers
anything. The actual difference per `Module::Load`'s own docs: `autoload`
auto-imports the module's default exports and is safe to call under
`BEGIN{}`; `load` imports nothing unless you explicitly list `@export`
symbols. `load File::Spec::Functions, qw|splitpath|;` and `autoload
File::Spec::Functions, qw|splitpath|;` behave identically — passing
explicit exports makes the distinction moot. So "autoload" in the name
is not a synonym for lazy/deferred loading; don't read it that way.

**The real (and still valid) placement point**: the reliability concern
isn't about choosing between these two functions — it's about *where in
the code* the call appears. Calling `<[base.perlmod.load]>->('Perl::Tidy')`
inside `coding.tools.handler.perltidy` (a per-tool-call handler) means the
require happens on first tool invocation, not at zenka boot — genuinely
later than necessary, and exactly the kind of placement that lets a
missing dependency go unnoticed until that handler is actually exercised.
Moving it to `coding.init_code` (this session's actual fix) makes it run
once, at boot, regardless of which of `load`/`autoload` is used.

**How to apply:** pick `load` vs `autoload` based only on whether you
need the module's default exports imported into the caller — that's the
only axis that differs. For the eager-vs-lazy timing question, look at
*where* the call sits in the code (init_code vs. per-request handler),
not which function name is used.

**Load-time optimization is not deprioritized** — user was explicit:
it remains a very high priority, not something to sacrifice for
reliability. The resolution to the apparent conflict isn't "always eager,
never defer" as a permanent rule; it's that the *infrastructure itself*
needs to gradually gain enough dependency-awareness to do both at once —
optimized load windows AND immediate, accurate visibility into
system/installation state — without one costing the other. Defaulting to
eager loading for now is the interim-safe choice while that
infrastructure matures, not the final answer.

**Why the wrapper routines specifically matter for getting there**: using
`<[base.perlmod.load]>`/`<[base.perlmod.autoload]>` — never a raw `use
Module;` or a runtime `require` — is what makes a dependency *trackable*
by the system's own tooling in the first place. `bin/dev/dep-graph`
already builds its whole reachability/whitelist model by statically
parsing these same wrapper call patterns (see
[[bug-swap-subs-nested-lifecycle-hook-gate]] and
[[topic-base32-namespace]] for the `swap_subs` half of this same
tracking idea). A raw `use`/`require` is invisible to that tooling —
so even an eager, reliability-safe raw `use` still undermines the
long-term fix, because it can't be seen, counted, or reasoned about by
whatever infrastructure eventually reconciles the load-time/accuracy
tension. The wrapper isn't bureaucratic overhead; it's the hook the
future optimization has to attach to.

See [[topic-post-bootstrap-load-window]] for the specific shape that
future optimization was sketched as, same conversation: a hybrid
deferred/eager load window, generalizing `deferred_compile`'s existing
self-heal pattern from P7 subroutines to CPAN module deps.

#,,,,,,,,,,,,,...,,,.,.,.,,.,,,.,,,,.,..,,.,.,..,,...,...,..,,..,,..,,...,.,.,
#36V2CEV53RLNA4PKV5LZDIRD5HO73IKSNR3LUUDZZIAESSV7SDRZ64PE6SQXJNDKX5USS5CL6QWTA
#\\\|3CKI45R2AYSB6SRVVSWFLB7XEYGIVVU52ECHYQMKL6ZAHFQ2ALT \ / AMOS7 \ YOURUM ::
#\[7]6SDL4KEPKNMH3A6XXADSZHEABWOEQYHMEBZJEWGTKDPB3ZKHKABQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
