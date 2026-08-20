---
name: zenka-shutdown-end-code-callback
description: "never assign $SIG{'INT'}/$SIG{'TERM'} directly in a zenka module; use <callbacks.end_code> for local cleanup ONLY — anything needing the event loop (network sends) must override base.sig_term/sig_int via event.add_signal instead, chaining to the default for parity"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f389ff82-5ffe-4566-bc0c-7ec2e472fbe6
---

A zenka module must never do `$SIG{'INT'} = sub {...}` / `$SIG{'TERM'} = ...`
directly. Perl only keeps the last assignment per signal, so this silently
clobbers the framework's own `src/base.sig_int` / `src/base.sig_term`
handlers — which do v7 teardown, cross-zenka shutdown notification
(`base.net.send_to_all_initialized`), and `<system.kill_list>` child killing.
A module-local direct signal assignment breaks all of that for the whole
zenka, not just adding its own cleanup.

**The correct mechanism**: `bin/Protocol-7` has an `END { ... $code{'base.
handler.end_code'}->(); }` block that fires on every exit path (including
`base.sig_int`/`base.sig_term`'s own `exit()` calls) and runs every callback
registered in `<callbacks.end_code>` (`$data{'callbacks'}{'end_code'}`), in
reverse-registration order, by module name (not coderef — "direct code refs
currently not supported", `bin/Protocol-7` ~line 3768). Register with:

```perl
push <callbacks.end_code>->@*, qw| your.module.name |;
```

Precedent: `src/v7.setup_stdout_redir` → `push <callbacks.end_code>->@*,
qw| v7.stdout_log.close |`. The callback module itself is plain cleanup logic,
no `exit()` call inside it — the process is already exiting via whatever path
triggered the END block; the callback just does its cleanup and `return TRUE`.

**CORRECTION / caveat (2026-08-01, confirmed via a real segfault,
`bac000eef`):** `<callbacks.end_code>` is safe ONLY for local, non-blocking
cleanup (closing file handles, unlinking temp files — see `v7.stdout_log.
close`). It is NOT safe for anything that needs the event loop to actually
run before the process exits — e.g. a `route-send` that needs a follow-up
`event.once`/`Event::loop` pump to flush to a socket. `bin/Protocol-7`'s
`END { $code{'base.handler.end_code'}->() }` fires during Perl global
destruction, after the main event loop has already stopped; reentering
`Event::loop` from that context is unsupported territory for the `Event`
XS module and segfaulted in practice (`src/radio.end_code`, trying to
fade `mpv[audio-0]` out via a `route-send` + `event.once` before exit —
removed).

**The correct mechanism for that class of need**: override the zenka's own
`base.sig_term`/`base.sig_int` watcher via `event.add_signal` instead (see
`tile.init_code`'s precedent, and the new `radio.init_code`/`radio.handler.
sig_term`, `bac000eef`) — this callback runs from a normal `Event::signal`
dispatch, a safe context to do I/O and pump the loop. Since `base.event.
add_signal` cancels/replaces the prior watcher for that signal
(`undef $SIG{$signal}`), and the override does NOT automatically chain back
to the default (`web-browser.handler.sig_term` doesn't either — it owns its
own `exit(0)`), your override must explicitly call `<[base.sig_term]>` (or
`base.sig_int`) itself afterward if you still want the standard
teardown/exit(0) behavior, not just skip it.

**Decision rule going forward:** cleanup that's purely local → `<callbacks.
end_code>`. Cleanup that needs a network send / IPC / anything requiring
the event loop to actually run → override `base.sig_term`/`base.sig_int`
via `event.add_signal`, chaining to the default handler for parity.

**Why this surfaced (original finding)**: found while reviewing kimi's AMOS7::SHM phase-4
cleanup-on-exit work — the *original* phase-1 code already had this bug for
SIGINT alone (`src/data.mount.shm.init_code`); kimi's phase-4 task asked
it to add SIGTERM cleanup too, and it extended the same direct-`$SIG`-assignment
pattern, which would have also clobbered `base.sig_term`. Fixed by replacing
the direct assignment with the `<callbacks.end_code>` push (see
[[topic-amos7-shm-phase1]]).

**How to apply**: any time a module needs cleanup-on-shutdown logic, reach for
`<callbacks.end_code>` first. Only standalone (non-zenka) Perl scripts/packages
— which have no Protocol-7 callback framework at all — legitimately need a
real `$SIG{...}`/`END` block of their own; `AMOS7::SHM.pm`'s standalone-mode
`END` block is the correct counterexample, gated on `not defined
$main::PROTOCOL_SEVEN`.

#,,.,,,,,,,,,,.,.,..,,...,.,.,,,,,.,,,.,.,.,.,..,,...,...,,.,,,.,,,.,,,..,,..,
#IKWDMVFOH7TMBFDC4PHLHBTBCGDM47TRF36BZVNRZNUW6EKMU227WIOFG3U3QBZRYTO4WPSGD4GOW
#\\\|PTUHK5EGRZUQABXIVVM3RH3IU6KZKU23WQXNFM2AIFSX4QVQRM2 \ / AMOS7 \ YOURUM ::
#\[7]KXM343IRYQOHDH7QLMRUPISUTWQNPMJYS2SVRBM4NO35ZKX7DMBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
