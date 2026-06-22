---
name: topic-amos7-shm-phase1
description: "AMOS7::SHM phase 1 — standalone promotion of data.mount.shm.*, two real bugs found+fixed (mmap never shared, mlock unreachable standalone), self-healing IO::AIO fork guard"
metadata: 
  node_type: memory
  type: project
  originSessionId: b501d766-3643-48ba-886f-cb86d42097e2
---

Design doc: `data/tasks/amos7-shm-paging-feedback.md`. Committed `410805f43`
2026-06-22. See [[topic-tool-shm-architecture]] for how this fits the broader
SHM vision, and [[topic-summary-tree-phase1]] for the motivating incident
(BMW-L13/cube-buffer-cap hang) this generalizes a fix for.

## What landed

Promoted `modules/data.mount.shm.*`'s mmap/header-pack-unpack/permission-
signature-verification core into standalone-loadable `AMOS7::SHM`
(`data/lib-path/pm/AMOS7/SHM.pm`), via the same `$main::PROTOCOL_SEVEN`
hybrid pattern `AMOS7::CHKSUM` already proves out. All 18 affected
`data.mount.shm.*` modules are now thin wrappers calling into the package —
same relationship `modules/base.chk-sum.amos` has to
`AMOS7::CHKSUM::amos_chksum`. Zero behavior change on the zenka path was the
explicit bar, verified via `p7c data.shm-self-test` before/after.

**Critical context, don't forget**: `data.mount.shm.*` is the actual **data
zenka's own live working code** (`configuration/zenki/data/start` loads the
bare `data` token) — not a neutral shared library. `data.channel.shm.*`
builds a ring-buffer channel abstraction on top of it; reconciling that with
the new paging/feedback design is required before phase 3, not yet done.

## Two real, pre-existing bugs found during verification — not new regressions

1. **`data.mount.shm.*` "shared memory" never actually worked cross-process.**
   `Sys::Mmap::mmap()` was called with `fileno($fh)` where the documented API
   wants the filehandle itself. Confirmed empirically with a 10-line
   standalone test: `fileno($fh)` throws `Bad filehandle: 3` every time;
   `$fh` directly works. Every "SHM" segment silently fell back to a private
   per-process scalar copy — looked identical in the existing single-process
   self-test, provided zero actual sharing. **This had been broken since
   before this session**, in both standalone and zenka mode equally — not
   introduced by the promotion. Fixed by passing `$fh` directly in both
   `mmap_file` and `mmap_file_read`.

   Verification method worth remembering: a same-process slurp-fallback can
   produce a false positive (child "sees" data the parent already wrote
   *before* the child opened, since slurp-at-open captures whatever's on
   disk at that moment). The real test needs *timing*: child opens first,
   parent writes *after*, child re-reads and must see the late write. Only
   true shared memory passes that; a slurp fallback can't.

2. **mlock was unreachable in standalone mode.** `data.mount.shm.lock.memory`/
   `.lock.unlock` are zenka-only module files despite having bodies that were
   already zenka-agnostic pure Perl (no `<[...]>` calls inside). Promoted
   both into `AMOS7::SHM` as `lock_memory`/`unlock_memory`. `shm_create` now
   self-locks when standalone (`not defined $main::PROTOCOL_SEVEN`), since
   standalone has no separate thin-wrapper layer to add it externally the way
   the zenka path already does.

## A third bug, found live while verifying #2, fixed better than first planned

Calling `lock_memory` (uses `IO::AIO::aio_mlock`) and then `fork()`ing hung
the child at 100% CPU indefinitely — `IO::AIO`'s background worker-thread
state does not survive `fork()` cleanly. This is a **known, already-solved
problem elsewhere in this codebase**: `modules/base.process-into-background`,
`modules/vision-batch.parent.fork_child`, and
`modules/weather.base.fork_weather_child` all call `IO::AIO::reinit()`
immediately after `fork()` for exactly this reason — user pointed this out
directly with the exact grep results.

First fix attempt documented it as a caller-responsibility convention
(comment above `lock_memory` telling callers to remember `reinit()` after
fork). **User improved on this live**: track the pid `AMOS7::SHM` last
touched `IO::AIO` from in a package variable; compare against `$PID` on every
`lock_memory` call; a mismatch means a fork happened, so reinit
automatically. `$$`/`$PID` is a cached interpreter value, not a syscall — the
check is one integer comparison, negligible overhead. **Confirmed live with
zero awareness required in the caller** — parent creates+mlocks, forks,
child calls `lock_memory` again with no manual `reinit()` call anywhere, and
it just works.

**Lesson for future "should the package document a caller convention or
self-detect" decisions**: self-detection that's this cheap (one int compare)
is strictly better than documentation — it converts "callers must remember"
into "callers cannot get it wrong." Don't default to documentation when
self-detection is this cheap; ask whether it's possible first.

## What's still open (phases 2-4, design only)

- Paging abstraction above raw `substr()` — not built.
- Feedback-variable channel — the reader-paced vs writer-paced fork is
  deliberately unresolved in the doc; a candidate (`jobqueue`'s polling-free
  `Event->var()` watcher, via `base.event.add_var`) is flagged but its
  cross-process applicability is *unverified* — `Event->var()` watches
  in-process Perl variable writes; whether it fires on an externally
  mmap-modified scalar from a different process has not been tested.
- Full lifecycle/cleanup hooks (currently only `data.mount.shm.init_code`'s
  `$SIG{'INT'}` handler, which unlocks but does not unlink).
- The two relay origins in [[topic-summary-tree-phase1]]'s BMW-L13 work
  compute their checksums differently (byte string vs perl character
  string) — unrelated mechanism, but the same "verify cross-process/
  cross-representation assumptions empirically, don't assume" lesson applies
  if this SHM work and that one ever need to interoperate.

## Process notes

- Every `data.mount.shm.*` / `AMOS7::SHM.pm` edit needs `v7.restart data`
  (or `p7c reload`) before it's live — same lesson as
  [[topic-summary-tree-phase1]], still easy to forget mid-loop.
- `p7c data.shm-self-test` is fast and cheap — run it after every change to
  this family, not just at the end.
- When verifying "does X actually share memory/state across processes,"
  don't trust a single-process self-test or a naive same-process check —
  fork and add a timing gap, or you'll get a false positive from whatever
  fallback path silently activated.

#,,,.,,..,.,.,.,,,.,,,.,.,,,,,.,.,,.,,,.,,...,..,,...,...,.,,,,,,,...,.,.,,,.,
#2JTIQMHRPDJEHFJRJP2IOQYKCL7ALNKQTPYJBW56D53THYRSONTDVSEBI4LGFF2E67T5GIMDMPMCY
#\\\|VFSOXDM3NXPEFBVTUSY6IM4SHJWO7GCBCWEALQCO2EZIMAT5OHP \ / AMOS7 \ YOURUM ::
#\[7]D5U7PQ4AA4GMOTY7QS5SUFICP3HXYC7DSCSM5FEKMS6WIF4WKEDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
