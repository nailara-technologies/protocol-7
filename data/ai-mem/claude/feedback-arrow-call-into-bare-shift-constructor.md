---
name: feedback-arrow-call-into-bare-shift-constructor
description: "Class->new($arg) silently discards $arg if new() is written as a plain function (sub new { my $X = shift; ... }) instead of a proper OO constructor (my $class = shift; my $X = shift) -- arrow syntax always inserts the class name as $_[0], and a bare single shift consumes that instead of the real argument. Vendored X11::WM.pm had exactly this bug, masked for years by coincidence."
metadata:
  type: feedback
---

Found live 2026-09-06 building X-11 auxiliary-display support (see
[[project-x11-xvfb-crash-loop-and-cleanup-2026-09-06]]). Every call site
of `X11::WM->new($X)` in the codebase (`X-11.connect_X11`,
`X-11.pool.promote_standby`, `X-11.job.finalize_server`, and a new
helper this session) passed an explicit X11::Protocol connection object,
clearly intending to reuse it. None of them worked. `X11::WM::new()`
(`data/lib-path/pm/X11/WM.pm`) was written as:

```perl
sub new {
    my $X = shift;
    $X = X11::Protocol->new() unless ref $X;
    ...
```

`Class->new($X)` is sugar for `Class::new('Class', $X)` — the class name
is always `$_[0]`. A single bare `shift` takes the class name string,
never reaching `$X`. `ref('X11::WM')` is false, so it silently falls
into `X11::Protocol->new()` with no arguments (connects to
`$ENV{DISPLAY}`) — discarding whatever connection was actually passed,
in every caller, unconditionally.

**Why nobody noticed for years**: the primary display's own
`$ENV{DISPLAY}` already happens to match the primary display, so
`X11::WM->new($X)` "working" for the primary was never proof it reused
the intended connection — it silently opened a second, separate one to
the same place by coincidence. The bug only became visible the first
time something needed `X11::WM` to attach to a connection that *wasn't*
also `$ENV{DISPLAY}` (an auxiliary xvfb display) — two connections to
different X servers meant window ids discovered on one connection then
queried on the other, producing a 100%-reproducible BadWindow protocol
error, not a transient race.

**How to apply**: when a module's `new()` is called via arrow syntax
everywhere in a codebase but internally does a single un-guarded `shift`
before touching its first "real" argument, check whether that shift is
consuming the invocant (class name / object) instead of the intended
argument — especially in older/vendored/CPAN-derived modules not
originally written with this project's calling convention in mind (this
file is a modified copy of CPAN's `X11::Tops`, per its own header
comment). A quick empirical check: log `Scalar::Util::refaddr` (or
stringify, which embeds the address) of what you passed in versus what
the object ends up storing — if they differ, the argument never arrived.
Don't trust "it's been working" as proof the argument-passing is
correct; it may be working by accident via a fallback default that
happens to coincide with the intended value.

**The fix** (safe, no call-site changes needed): add the missing class
shift (`my $class = shift; my $X = shift; ...`) and `bless $wm, $class`
instead of the bare-package-implicit `bless $wm;`. Since every existing
caller already used arrow syntax expecting a proper constructor, fixing
the constructor to actually behave like one made every call site work
as originally intended — no call site needed to change to plain
function-call syntax instead.

#,,.,,...,,..,..,,,.,,,,.,.,,,.,.,...,...,.,,,..,,...,...,,..,.,.,.,.,..,,.,,,
#LO4ARTZSCYMBW7CIHOJR7T5O3EWHNDDOYUVEYNGV3EPK2XHBM3ETFQQH2BN4REIOZGQBN6MS7Y6DS
#\\\|SCSQ5TBSYEJYH2RLXZCYWH2A5LQXXGROM4XE3LJY2MB7YGDZU4V \ / AMOS7 \ YOURUM ::
#\[7]GR2KDZOLHHEZYXDNQZO2NBNGFHDU7NXEGYT5JV4ZCRGDTY5UC2CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
