---
name: reference-forked-child-lazy-load-and-event-safety
description: "two real gotchas for a P7 module that fork()s a child: (1) base.event.add_signal (and anything checking `exists $code{$name}` on a runtime string) does NOT trigger the on-demand module loader -- only a literal <[module.name]> macro occurrence does, at compile time; (2) a forked child inherits the parent's live Event.pm state, so Event::loop()/Event->signal() in the child is unsafe -- use plain %SIG + POSIX::pause() instead, matching cred-mesh.key_holder.child's established pattern"
metadata:
  type: reference
---

Both found live, 2026-08-14, building `sessions.holder.child` (see
[[vision-sessions-zenka-key-holding-children]] for the full incident
account with code and exact diagnostic steps — this is the extracted,
reusable rule).

## 1. P7's on-demand module loader only triggers on literal `<[...]>` syntax

`base.event.add_signal` (and by extension anything else that resolves a
P7 module by NAME rather than by literal macro reference) does:

```perl
if ( defined $handler and exists $code{$handler}
    and ref $code{$handler} eq qw| CODE | ) { ... }
elsif ( defined $handler ) {
    <[base.s_warn]>->( "nonexistent callback '%s' configured", $handler );
    return undef;
}
```

`exists $code{$handler}` is a plain hash lookup. The P7 compiler's
on-demand loader is triggered by a literal `<[module.name]>` occurrence
in source being compiled at COMPILE TIME — passing a module name as a
runtime string/data value (e.g. inside a hashref param) never triggers
it. If the target module hasn't been loaded into `%code` by something
else first, this fails SILENTLY from the caller's point of view — no
exception, just an unregistered handler left at whatever disposition it
had before (for a signal handler, the OS default — often "terminate").

**How to apply**: before passing a P7 module name as a runtime value to
anything that will later do `$code{$name}`-style dispatch (event
handlers, callback tables, dynamic dispatch of any kind), force-load it
first with a literal, harmless priming reference: `<[the.module.name]>;`
(no args, no `->()` needed for a load-only touch if the module tolerates
being called with none). Don't assume "it's already been loaded
elsewhere in this process" without checking — module loading is
per-process, and a module used only inside runtime-dispatched code (never
referenced via literal macro syntax anywhere else) may never get loaded
at all.

## 2. A forked child inherits the parent's live Event.pm state — don't use Event.pm in it

`fork()` duplicates the whole process, including Event.pm's internal
state: its polling fd (epoll/kqueue), and every watcher already
registered on the PARENT's own connections (e.g. the zenka's cube link).
Calling `Event::loop()` in the child sees that inherited, unrelated
state and can return immediately — confirmed live via a direct `waitpid`
`$?` capture showing a clean voluntary exit (status 0), not a crash: the
child's `Event::loop()` call returned with no signal ever having arrived,
silently short-circuiting straight through to shutdown.

This is why `cred-mesh.key_holder.child` (the established precedent for
a P7 forked child) uses NO Event.pm at all — plain `%SIG{...}` closures
and blocking I/O throughout. That was a correctness requirement, not a
style choice; a first attempt at `sessions.holder.child` missed this and
paid for it in a long live-debugging session.

**How to apply**: a forked child in this codebase should register signal
handling via plain `%SIG{NAME} = sub {...}` (never `<[event.add_signal]>`
/ `Event->signal`), and block on `POSIX::pause()` rather than
`Event::loop()` for an idle/dormant wait. Perl's own deferred-signal
safety handles a plain `%SIG` handler correctly even mid-blocking-syscall
(confirmed live and via an isolated reproduction script outside the zenka
entirely) — this is what actually makes it safe to interrupt a blocking
`<$socket>` read from a signal, not Event.pm.

One caveat surfaced by the same session, not yet re-verified in
isolation: `base.ntime` carries per-process harmonization/retry state
(`$data{'base'}{'retry-count'}{'ntime'}` etc.), so it is NOT a
deterministic function of wall-clock time two processes (e.g. a parent
and its freshly-forked child) can compute independently and expect to
agree on — do not reuse it as a shared, transmission-free freshness
counter across processes without first confirming stability for that
specific case.

[[vision-sessions-zenka-key-holding-children]]

#,,.,,..,,,..,.,,,.,,,...,,..,,.,,,..,.,.,..,,..,,...,..,,,,.,,,.,...,..,,,,,,
#S7VZXIFYKGKSSPXLAEKOAVDMI6OPPXADZQVXYL7OWVMPJU24XVRDQ2YAPCAI44UQJE5AQEBAVC4DU
#\\\|SN36LWCBQ3R4U6D2ACHQYSQLXGPDP7FJVT7UV6557UE7YH7OV6R \ / AMOS7 \ YOURUM ::
#\[7]S5VUQNLR5QVCL7JQVHE57HPFPUBEYKJOP4RSHIQVRUMC7K2DPICQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
