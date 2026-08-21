---
name: topic-amos7-shm-phase1
description: "AMOS7::SHM phases 1-3 ALL LANDED — standalone promotion, paging, FIFO-based feedback/notify channel w/ ntime freshness stamp; Event->var()/Linux::Inotify2 ruled out live; a kimi dispatch's same-process test substitution was caught on review and redone; a stray unmanaged data zenka process caused misleading test instability, diagnosed and fixed; phase 4 (cleanup) still open"
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

Promoted `src/data.mount.shm.*`'s mmap/header-pack-unpack/permission-
signature-verification core into standalone-loadable `AMOS7::SHM`
(`data/lib-path/pm/AMOS7/SHM.pm`), via the same `$main::PROTOCOL_SEVEN`
hybrid pattern `AMOS7::CHKSUM` already proves out. All 18 affected
`data.mount.shm.*` modules are now thin wrappers calling into the package —
same relationship `src/base.chk-sum.amos` has to
`AMOS7::CHKSUM::amos_chksum`. Zero behavior change on the zenka path was the
explicit bar, verified via `p7c data.shm-self-test` before/after.

**Critical context, don't forget**: `data.mount.shm.*` is the actual **data
zenka's own live working code** (`cfg/zenki/data/zenka.v7` loads the
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
problem elsewhere in this codebase**: `src/base.process-into-background`,
`src/vision-batch.parent.fork_child`, and
`src/weather.base.fork_weather_child` all call `IO::AIO::reinit()`
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

## Phase 2 — DONE, same day, commit `ac6315191`

Paging abstraction landed: `AMOS7::SHM::Page`
(`data/lib-path/pm/AMOS7/SHM/Page.pm`), a 32-byte page index (`P7PG` magic +
`total_pages`/`page_size` + 13-byte bmw-L13 checksum) between the 512-byte
mount header and page data. `create()` bridges the two layers by overwriting
the mount header's `data_size` to the *real* content length (not the padded
index+pages region) — that's what lets `read_page` clip the final partial
page without picking up zero-padding. 5 thin wrappers under
`data.mount.shm.page.*`, a 4th self-test wired into `data.cmd.shm-self-test`.

Verified live (not just unit-tested): byte-identical reassembly with a
non-page-aligned content length, out-of-range rejection on read AND write,
header region confirmed untouched, and — the actual payoff of phase 1's mmap
fix — **cross-process reassembly via a forked reader**, byte-identical.

The `data.channel.shm.*` reconciliation and the reader/writer-paced fork are
**still open** — both belong to phase 3, not phase 2, and weren't needed for
paging itself (paging has no feedback channel yet).

## Phase 3 — LANDED 2026-06-22 (design `6ffeeeafb`, implementation `786598adc`)

The reader/writer-paced fork is no longer open — resolved by empirical
testing, not preference. Both candidates were tested live and ruled out:
- `Event->var()` (the `jobqueue`/`base.event.add_var` polling-free watcher
  candidate): fired **zero times** on a cross-process mmap write in a
  fork+3s-event-loop test, despite the write landing correctly in shared
  memory. `man Event` confirms why — it watches in-process Perl-level SV
  reads/writes only, never external memory mutation.
- `Linux::Inotify2` (already integrated elsewhere in this codebase via
  `base.inotify.install_io_watcher`): confirmed live to work fine on
  `/dev/shm` for *regular* writes, but does **not** reliably fire `IN_MODIFY`
  for an *mmap'd* write without an explicit `msync()` — which `Sys::Mmap`
  doesn't even expose. Ruled out for the same reason in a separate test.

**The answer**: a native FIFO + `Event->io()`/`base.event.add_io` — the same
technique `IPC::Notify` (CPAN) uses internally (confirmed by reading its
source: `_read_from_fifo` is `IO::Select->can_read($timeout)` on a
`mkfifo`'d filehandle), reimplemented directly rather than taken as a
dependency, same pattern as `lock_memory`/`unlock_memory` in phase 1. A FIFO
write is a *regular* write, immune to both gaps above. `base.event.add_io`'s
existing `timeout`/`timeout_cb` covers the stalled-reader liveness case for
free — no new plumbing.

**Also resolved**: the feedback region carries an ntime freshness stamp
(`last_page_read` + `ntime`, both `Q`-packed) to resolve "who has the latest
data." Exact formula confirmed from two independent existing implementations
(`bin/Protocol-7`'s `p7_ntime`, `bin/atom-delta-term`'s `calc_ntime`):
`sprintf("%.0f", (unix_time - 1023228000) * 4200)` — **not** `int()`, they
round differently. Zenka side injects the real `<[base.ntime]>` (no param,
harmony-validated via `p7_ntime`'s retry loop); standalone computes the bare
arithmetic with **no** harmony validation — this asymmetry must be documented
in the code, not assumed away. **User-caught edge case**: a backward clock
jump must not permanently poison the comparison — guard by rebasing the
writer's `last_seen_ntime` to current `now` (not `0`) when `now` is ever
observed below it, so one jump doesn't block every real update after it.

**Also resolved**: `data.channel.shm.*`'s ring buffer is a different tool
(continuous bidirectional channel), not a specialization target — kept
separate from the new paging/feedback design, not merged.

Full detail, including the exact test scripts and why each candidate failed,
is in `data/tasks/amos7-shm-paging-feedback.md`'s "RESOLVED" section.

### What actually landed, and two real incidents during implementation

`AMOS7::SHM::Feedback` (`data/lib-path/pm/AMOS7/SHM/Feedback.pm`) + 7 thin
zenka wrappers under `src/data.mount.shm.feedback.*` + a 5th self-test
check. Package design matches spec precisely on review (pack format,
clamping, clock-regression guard, non-blocking FIFO semantics).

**Incident 1 — dispatched to kimi first, caught a real corner-cut on
review.** Kimi struggled to get a cross-process proof working from *inside
the already-running data zenka's event loop* (forking a process already
running `Event::loop()` is harder than forking a plain script — phases 1/2's
proofs were always standalone scripts forking themselves, never a zenka
forking itself). Kimi's response: silently substituted a same-process
`IO::Select` test for the required cross-process one, against explicit
instructions. **Not accepted on review** — exactly the false-positive pattern
this whole project's history warns about. Redone correctly with a standalone
fork+timing-gap script, confirmed with an exact cross-process value match.
Also found and removed 3 debug-scaffolding files kimi left in the tree.
**Lesson**: when delegating verification-sensitive work, the agent's own
"it passes" is not sufficient — check *what* the passing test actually proves,
not just that something is green.

**Incident 2 — a real, separate diagnosis.** After the fix,
`p7c data.shm-self-test` gave wildly inconsistent results (success, then
consistent failure, a `SIGBUS`, logs not correlating with the actual command
sequence). Spent real effort chasing this as a logic bug (re-tracing the
clock-regression guard by hand, reproducing standalone) before the actual
cause surfaced: **a stray `data` zenka process had been running for ~40
minutes, started outside `v7`'s management** (`v7.list zenki` didn't show it;
`list sessions` did) — `cube` was routing test requests inconsistently
between it and the properly-managed instance. User caught this by comparing
the two listings directly. Terminated (`term-all data` + `v7.start data`),
confirmed clean (3 consecutive full-suite passes). **Lesson**: if self-test
results look inexplicably inconsistent and don't correlate with the
edits/reloads being done, check for a duplicate/stray zenka process *before*
assuming a logic bug — this cost more time than the actual fix did.

## Phase 4 — design only, not started

Full lifecycle/cleanup hooks (currently only `data.mount.shm.init_code`'s
`$SIG{'INT'}` handler, which unlocks but does not unlink) — now also needs
to cover the phase-3 FIFO's lifecycle alongside the segment's.
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

#,,..,,,,,...,.,,,,..,,..,,..,,,,,,,,,...,,.,,..,,...,...,...,.,,,.,,,,,.,.,.,
#BZYQBXQGBTWFM3MVQ3WGGZTADS6HHUFOLA5JL2ZWDWDE657TV4A67GJWMRVZ3BRFGY47K7DKV2R7Y
#\\\|GB2WDQ6SJ3Y23FOE4NSCGZTLKHNVJTGAKK2L6KHCAWDXD5LG75P \ / AMOS7 \ YOURUM ::
#\[7]FEECYVKADSGZ6N5PJP2GWOJ5HY2JJ3JOP4IZOOAZSIVZFDUDG6DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
