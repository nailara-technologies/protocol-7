---
name: feedback-event-watcher-callback-reload-needs-restart
description: a fix to a sub used directly as an Event watcher callback (registered without a sub{} indirection) does not take effect via code reload — needs a full zenka restart
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

#,,..,..,,,,.,,,,,,,.,.,,,.,.,,,,,,..,,..,..,,..,,...,...,.,.,.,,,..,,,,,,,.,,
#4AQFITEDBBD32V74CSGG5DDKVXEJTQPLIEKCSDSLAXCEDIVFOVDP2FU2XECAUK6UM4BJS2CYHIFUE
#\\\|OCPYA2GU4R4VXCGGWDQGD4J3U75ZR3YIYLIHUUK6PY3BCWFFI4H \ / AMOS7 \ YOURUM ::
#\[7]AL53K4B3NYHQIBMUUW7S45W5PKVYHEJJNS55GKI7Z6Q4I6PZ2QAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
