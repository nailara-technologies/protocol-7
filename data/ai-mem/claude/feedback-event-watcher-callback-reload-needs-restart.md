---
name: feedback-event-watcher-callback-reload-needs-restart
description: "reload source" alone can leave a fix inert: swap_subs-moved namespaces (shortening+implicit-load like base.file.*->file.*, or alternate-backend swaps like event.anyevent.*->event.*) only get re-moved during init, and a raw (non-sub{}-wrapped) Event/signal watcher callback also needs more than a bare source reload — try "reload init" before assuming a full zenka restart is required
metadata:
  type: feedback
---

Many `Event->io`/`Event->var`/etc. watcher registrations in this codebase pass the handler as a
bareword sub name resolved through `$code{$handler}` at call time (e.g. `base.event.add_var`'s
`'cb' => sub { $code{$callback}->(@ARG) }`) — that indirection layer IS reloadable, since it looks
up `%code` fresh on every invocation. But watchers that were instead wired with the callback
specified directly (no `sub {}` wrapper resolving through `%code`) keep the OLD compiled coderef
captured at watcher-creation time; a source-code reload does not reach them.

**Why:** confirmed live 2026-09-14 fixing [[reference-strm-size-write-cap-stall]] in
`base.handler.write` — a hot reload of the cube zenka did not pick up the fix (retested, still
stalled), a full `v7 restart cube` (not just reload) did. The user's own diagnosis: "many of the
watcher callbacks are specified directly, without sub {} wrapper.. requiring restart still."

**How to apply:** when a fix touches a function that's ALSO registered as an Event watcher
callback (grep for `'handler' => qw| <function> |` inside `Event->io(...)`/`Event->var(...)`/
`base.event.add_io`/`base.event.add_var` call sites, or for the function name appearing as a bare
watcher `cb` elsewhere), don't trust a code-reload test result — if the reload appears to have no
effect, try a full zenka restart before concluding the fix didn't work. This applies especially to
core dispatch functions like `base.handler.write`/`base.handler.read`/`base.handler.command` that
sit directly on hot I/O paths.

**Refinement, 2026-09-18** — a full zenka *restart* is the safe fallback, but not always the
cheapest fix. Fixing `coding.handler.inference_server_sigchld`'s log wording, `coding.reload
source` alone left it ambiguous whether the fix had really taken live effect; `coding.reload init`
made it unambiguous (all subsequent SIGCHLD log lines matched the new code, live inference-server
and self-test/sweep state survived intact).

**Corrected mechanism, per the user directly** — this is not really about `$SIG{CHLD}` vs a
`sub{}` wrapper. The actual reason `reload source` alone is insufficient in this codebase: `reload
source` only recompiles files into `%code` under their *source*-declared name. Where a module's
live-dispatch name differs from its source name, the actual *move* into the live-dispatch position
only happens when `base.swap_subs` runs, and `swap_subs` is invoked from the zenka's `init_code`,
not from a bare `source` reload. So a freshly recompiled sub can sit correctly updated under its
source name while the live-dispatch name still points at the stale pre-reload code, until an init
pass (`reload init`/`reload all`) re-triggers the move. Whether or not a *specific* function is
also a raw Event-watcher/signal-handler callback (the original, narrower finding above) is a
separate, additional way the same symptom can show up.

**What `swap_subs` is actually for, corrected 2026-09-18** — it was NOT originally written for
zenki to reuse each other's modules (an earlier draft of this note wrongly framed it that way,
citing `v7.zenka.*`→`zenka.*` and a guessed `cube-13`/`cube.*` example — the latter unverified,
dropped). The original design purpose is **alternate implementations of one namespace**: a
higher-level namespace like `event.*` normally gets populated by `base.event.*`, but an alternate
backend module can swap_subs itself in as a drop-in replacement instead. Real example,
`src/event.anyevent.init_code`:
```perl
<[base.perlmod.autoload]>->('AnyEvent');
<[base.swap_subs]>->( 'event.anyevent', 'event' );
```
— loading `AnyEvent` and moving `event.anyevent.*` into `event.*` in place of whatever
`base.event.*` would otherwise have installed there (a hypothetical libev-based alternative would
work the same way). It was deliberately kept flexible enough for other uses too, but per the user:
**the main use today** is the different, simpler pattern of shortening a longer on-disk namespace
into a shorter live one with *implicit* loading — e.g. `base.file.*` installs to `<[file.*]>` so
every zenka gets `file.*` for free without needing `file` added to its own `modules.load`. This is
almost certainly what `v7.zenka.*`→`zenka.*` actually is too (an instance of this shortening
pattern within one zenka's own namespace), not cross-zenka module reuse.

**This specific incident, verified, corrected 2026-09-18** — checked directly: both
`base.event.add_signal` and `base.event.add_timer` already wrap every by-name `'handler' =>
qw|...|` registration as `sub { $code{$name}->(@ARG) }` ("wrapped for reloading source code" /
"wrapper making sure the callback survives source code reload", their own comments) — a fresh
`%code` lookup on every fire. `coding.handler.inference_server_sigchld`'s SIGCHLD binding and
`self_test.run`'s probe timer were BOTH already reload-safe this way from the start; the earlier
guess in this note that the sigchld handler was "`$code{...}`-bound, not `sub{}`-wrapped" was
wrong. `coding.reload source` alone was genuinely sufficient for this specific fix (matching what
was actually observed live, before `reload init` ran as extra caution) — neither of this note's two
gotcha classes actually applied here, since `coding.handler.inference_server_sigchld` is also a
plain, non-swap_subs-moved native module. No registration-mechanism change is needed for either of
these two handlers.

**Default guidance, per the user directly, 2026-09-18** — none of the above is an argument for
reflexively reaching for `reload init` out of caution. `reload init` reruns the zenka's entire init
phase, which blocks/disrupts the zenka for that procedure's duration; `reload source` alone is
cheaper and faster. **If you know the module you just fixed is a plain module — not
swap_subs-moved, and not also bound directly as a raw Event/signal-watcher callback — `<zenka>.
reload source` is perfectly fine and is the right choice**, precisely because it minimizes that
blocked window. Escalate to `reload init` (or a full restart) specifically when the touched code
falls into one of the two gotcha classes above, or when you're genuinely unsure which case applies
and can't quickly check (grep the module's own file for a `swap_subs` call in its `init_code`
sibling, and grep call sites for the function name appearing as a raw watcher `cb`/`handler`).

**Forward-looking note from the user, not yet acted on**: this two-step recompile-then-move dance
is an *interim* property of the current loader, not a hard requirement — `%data` already collects
`moved_to` bookkeeping per subroutine, which a future improvement could use to make `reload source`
self-sufficient (capture each affected sub's current moved-to target before recompiling, immediately
re-apply the same `swap_subs` move right after compiling, without waiting for a subsequent init
pass) or to compile directly into the moved-to position in the first place. Deliberately not rushed:
it's adjacent to the still-incomplete version-aware loader rewrite (staged `%CODE` + atomic swap +
rollback, `data/md/coding-tasks/version-aware-loader.md`), and the user doesn't want to invest
further in the interim mechanism ahead of that. See
[[feedback-init-phase-idempotency-is-a-hard-invariant]] for why relying on `reload init` in the
meantime is safe by design, not a workaround.

#,,,,,,..,,,.,,.,,,,,,,,,,,.,,,.,,.,.,,,,,,..,..,,...,..,,..,,,.,,..,,,,,,...,
#5RHBIMPXURCKI27ULEK2WXMS35RV3ANILGC6H5SHGM5KF6VUJRJCVAXXMLZPYR72HXAX4E3FFSWLI
#\\\|NKWRFTNRSHQJTX3GTOHPMXNPXCQ2VFUSA6UIBKY73Y4PEQOJFJ7 \ / AMOS7 \ YOURUM ::
#\[7]ZK7Y5SSKO2IKYM5URIKHFR5MZNPMW2DIPRH3IBDXTY4K5USIIKBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
