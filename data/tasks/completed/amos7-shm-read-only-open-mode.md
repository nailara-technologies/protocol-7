# task: AMOS7::SHM — add a read-only open mode to shm_open

## status [ 2026-06-22 ]

design is settled, this is the first concrete implementation slice. read
`data/tasks/amos7-shm-use-case-taxonomy.md` section "the read-only-open gap"
for full context — this task implements exactly that one gap, nothing more.

## the gap, precisely

`data/lib-path/pm/AMOS7/SHM.pm` — `sub shm_open` (around line 599) always does:

```perl
open( my $fh, '+<', $shm_path )
    or return { 'error' => 'open_failed', 'path' => $shm_path };
```

`'+<'` is read-write. opening read-write requires the calling OS user to hold
**write** permission on the underlying file. `shm_create` (around line 514)
creates the segment with `open( my $fh, '+>', $shm_path )`, so the file lands
writable only by its **owner UID** (standard umask, e.g. ~0644). `/dev/shm` is
world-**readable**, not world-writable.

consequence: a reader running as a *different* OS user than the segment's
creator gets `open_failed` from the bare filesystem permission check, **before
`permission_verify` (the actual cryptographic access-control layer) is ever
consulted**. that defeats this project's whole point with `AMOS7::SHM` —
access is supposed to be governed by signed permission grants, not OS file
permissions — for any reader that only ever needs to *read*.

note: `mmap_file_read` (around line 234, called later in `shm_open`) already
requests `Sys::Mmap::PROT_READ()` only — the mmap protection is already
correctly read-only. the bug is purely in the **filehandle open call**, one
level up.

## what to change

add an explicit `mode` option to `shm_open`'s `$options` hashref (the second
positional arg). when `$options->{'mode'} eq 'read'`, open `'<'` (read-only)
instead of `'+<'`. any other value, or the key absent entirely, keeps **today's
exact behavior** (`'+<'`) — this must be purely additive, no existing caller's
behavior changes.

```perl
my $open_mode = ( ( $options->{'mode'} // '' ) eq 'read' ) ? '<' : '+<';

open( my $fh, $open_mode, $shm_path )
    or return { 'error' => 'open_failed', 'path' => $shm_path };
```

that one-line change is the entire fix. nothing else in `shm_open` needs to
change — `mmap_file_read` already only ever requests `PROT_READ`, regardless
of how `$fh` was opened.

## scope — do not go beyond this

this task is **only** the `shm_open` change above. do **not**:
- touch `shm_create`, `Page.pm`, or `Feedback.pm`
- build `AMOS7::SHM::Transport` / `::Channel` / `::Mount` — those are separate,
  larger tasks that depend on this primitive but are not this task
- wire anything into `src/data.cmd.shm-self-test` — that 5-check self-test
  exercises the **zenka** thin-wrapper layer (`data.mount.shm.*`), which this
  task does not touch at all. this task is purely inside the standalone
  `AMOS7::SHM.pm` package.

## verification — write a standalone test script, single process is fine here

unlike phases 1-3's cross-process mmap-sharing claims (which specifically
needed a fork + timing gap to avoid a same-process false positive — see
`data/tasks/amos7-shm-paging-feedback.md` if curious why), **this specific
claim does not need cross-process verification**: the thing under test is
"does the open-mode string passed to `open()` behave as Perl's `open()`
already guarantees," which is fully and honestly verifiable in a single
process. do not claim more than that — do not claim this proves cross-user
behavior works (it doesn't test OS permissions across users at all, only the
open-mode semantics); the human will do a real cross-user check separately
later when this primitive gets its first real caller.

write a small standalone script (suggest
`bin/dev/script-scratchpad/test-shm-read-only-open.pl` or similar under
`bin/dev/script-scratchpad/` if that directory exists — check first; if not,
ask before inventing a new location) that:

1. uses the existing standalone-loading pattern (`BEGIN` block adding
   `data/lib-path/pm` to `@INC`, same as `bin/amos-chksum` — read that file for
   the exact pattern if unfamiliar) and `use AMOS7::SHM;`
2. creates a segment via `shm_create` with a known pubkey-shaped string and
   known content written into it (use `mmap_file`'s returned pointer, same
   pattern `shm_create`/existing tests use — check `data.mount.shm.test.basic`
   or `AMOS7::SHM::Page`'s own test sub for the exact idiom of writing through
   an mmap'd scalar ref)
3. opens it via `shm_open(..., { mode => 'read' })` and confirms: the returned
   mount hashref has no error, and reading through `$mount->{'mmap_ptr'}`
   yields the exact content written in step 2
4. confirms writing through that same read-only-opened handle's mmap region
   fails or is refused — `Sys::Mmap`'s `PROT_READ`-only mapping should make an
   attempted write die or fail; assert that it does NOT silently succeed
5. separately, opens the **same** segment via `shm_open(...)` with **no**
   `mode` option (or `{ mode => 'write' }`) and confirms this still succeeds
   exactly as before — proving the default path is unchanged
6. prints a clear pass/fail summary for each of the above

run it, paste the output. fix anything that fails before reporting done.

## style / pitfalls — read before writing any code

- `AMOS7::SHM.pm` is a standalone-or-zenka hybrid package (the
  `$main::PROTOCOL_SEVEN` check pattern, same as `AMOS7::CHKSUM`) — it is
  **plain Perl**, not a zenka module file. do **not** use `<[...]>` bracket
  syntax or `<dotted.data>` syntax anywhere in `SHM.pm` — that syntax is only
  valid inside `src/*` zenka files, which this task does not touch.
- this is editing an **existing, already-signed** file. it has a trailing
  signature block (`#,,.,,,...` line + checksum lines) at the very end. **do
  not touch, regenerate, or attempt to fix that block** — leave it exactly as
  it is, even though your edit will make it stale. the human re-signs after
  review; this is normal and expected, not something to investigate or fix.
- do not add a `#,,.,,,...` stub to any **new** file you create either (the
  test script) — same reason, the signing system (if the file needs one)
  handles that separately, and a fake stub blocks signing.
- TRUE/FALSE constants are `5`/`0` in this codebase if you need them, but this
  task is unlikely to need them at all — it's a small, self-contained change.
- when you're done, state plainly in your final summary: the exact line(s)
  changed in `SHM.pm`, the path of the test script you wrote, and the full
  output of running it.

#,,,,,,..,,.,,,,,,,.,,,.,,..,,...,...,,,.,,..,..,,...,...,.,,,.,.,,..,.,.,,.,,
#67YA2THGPJHZWPFW2GBYB2SLCZTVFNQIFUO45XVFY4CTXTME2MCDODWAIZXZHQSPVOYGKFDFS55Z2
#\\\|R3OPFGSC2MJ44OOGD3OE6YJWBSG7WINO5NDV6F3JQ4DITO3NGJN \ / AMOS7 \ YOURUM ::
#\[7]K67ULNC7BBID2MXO5PSJDYOKGMYBAJ2TEFVT5Q5Q4NGGJTE3YUAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
