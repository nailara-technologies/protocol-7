# task: AMOS7::SHM::Live — the shape-3 "live-mounted current state" primitive

## status [ 2026-06-22 ]

design is settled across `data/tasks/amos7-shm-use-case-taxonomy.md` [ shape 3 ]
and the build-order section there [ shape 3 is first among the three
shape-layers — simplest, fully unblocked by what's already landed ]. this task
builds the **flat-content** case only [ ticker's current text, a single
bounded value, fully replaced on each write ]. the **tree-shaped** case
[ `protocol-7-menu` branches, a future multi-section OSD — per-node ntime
freshness tree ] is explicitly **out of scope**, a separate future task.

read `data/tasks/amos7-shm-paging-feedback.md` first [ phases 1-3, landed,
live-verified — this composes only already-landed primitives, no new mmap /
header / permission mechanics ].

## the shape, precisely

there is **no transfer, no "done," no consumed cursor** [ unlike shape 1's
one-shot pull-verify-done, unlike shape 2's ack-then-shift stream ]. a writer
keeps a segment's content **current in place**; any permitted reader
`shm_open`s it and reads **whatever is current right now**. optionally, a
reader can be **dinged** when content changes, via the already-landed phase-3
FIFO atom — reused literally, for its more direct original meaning ["tell me
when this changed"], not phase-2's position-tracking reuse of the same atom.

## the naming decision, already made — do not call it `Mount`

`AMOS7::SHM::Mount` was considered and rejected in the taxonomy doc's open
question 4: it collides head-on with the existing `data.mount.shm.*` family and
the general "a segment is mounted" concept used by *every* shape. **use
`AMOS7::SHM::Live`** [ `data/lib-path/pm/AMOS7/SHM/Live.pm` ], mirroring the
`Page.pm` / `Feedback.pm` sibling layout.

## why no `Page` reuse — already decided, restated briefly

`AMOS7::SHM::Page` bakes **immutable-announce semantics** into its index at
`create()` time: a fixed `total_pages` and a **whole-content checksum**,
verified once after a full pull. that model is for shape 1's "announce once,
pull, verify, done" — it is **not reusable as-is** for content that mutates
live in place [ every change would need an index + checksum rewrite, which
`Page` does not support today ]. for `Live`'s flat, bounded candidates, **skip
`Page` entirely** and use the mount header's own `data_size` field directly —
it is already exactly the "how much of this segment is real content right
now" field every other layer already relies on.

## what to build — `data/lib-path/pm/AMOS7/SHM/Live.pm`

a new standalone-loadable sibling, same hybrid style as `Page.pm` /
`Feedback.pm` [ no `<[...]>` zenka-bracket syntax in it ; works identically
standalone or in-zenka ; `use AMOS7::SHM; use AMOS7::SHM::Feedback;` for the
optional notify reuse ].

### `live_create( $pub_key_b32, $content, $capacity, $options )`

- `$capacity` is the **maximum** content size this mount will ever hold —
  distinct from `length($content)`, the *initial* value, which may be smaller.
  this is the one capacity decision a caller must make up front [ the segment
  size is fixed at `shm_create` time, same as every other `AMOS7::SHM` shape —
  `Live` does not add or remove that constraint, it just means a `live_write`
  later with content longer than `$capacity` must fail cleanly, not corrupt
  anything ].
- composes: `AMOS7::SHM::shm_create( $pub_key_b32, $capacity, $options )` [
  reuse exactly as-is — same `mlock` default-on behavior every other shape
  already gets for free, no new code needed for that ], then writes
  `$content` into the data region [ `substr` at `AMOS7::SHM::SHM_HEADER_SIZE()`
  offset ] and sets `$mount->{'header'}{'data_size'} = length($content)` via
  `AMOS7::SHM::header_write` [ exactly the field every other shape already
  reads to know "how much of this segment is real content" — no new header
  field, this is direct reuse ].
- if `$options->{'notify'}` is true, also call
  `AMOS7::SHM::Feedback::create_notify_fifo($mount)` [ already-landed phase-3
  primitive, reused unmodified — creates the `.notify` FIFO alongside the
  segment ]. **optional** — a caller that doesn't need change-notification
  [ happy to poll on its own cadence ] should be able to skip this entirely
  with zero FIFO created.
- return the `$mount` hashref [ same shape `shm_create` already returns,
  nothing new to learn ].

### `live_write( $mount, $content )`

- reject [ return an error hashref, do not write anything ] if
  `length($content)` exceeds the capacity this mount was created with [ derive
  this from `$mount->{'size'}` / `$mount->{'total_size'}` minus
  `AMOS7::SHM::SHM_HEADER_SIZE()` — whichever field `shm_create`'s return
  already carries that gives you the data-region capacity without
  re-deriving it from scratch — check `shm_create`'s actual return keys before
  picking one ].
- on success: `substr` the new content into the data region [ overwriting
  whatever was there — there is no append, no framing, no length-prefix, this
  is "replace the current value" ], `header_write` the new `data_size`, and —
  **only if this mount was created with `notify => 1`** [ check whether the
  `.notify` FIFO exists, e.g. via `-p AMOS7::SHM::Feedback::notify_path($mount)`,
  rather than threading an extra flag through — confirm whichever check is
  cleanest ] — call `AMOS7::SHM::Feedback::ding($mount)` [ already-landed,
  reused unmodified ; `ding`'s own non-blocking-open behavior already makes a
  reader-less ding a safe no-op, nothing extra to handle here ].
- **no ack, no position tracking, no "shift this off a queue."** this is the
  one place shape 3 is genuinely simpler than shapes 1/2 — restate this in
  your own summary so it's clear you didn't port shape 2's ack machinery in by
  habit.

### `live_read( $mount )`

- `AMOS7::SHM::header_read( $mount->{'mmap_ptr'} )` for the current
  `data_size`, then `substr` the data region for exactly that many bytes
  [ same clip-to-real-length idiom `Page::read_page` already uses for its last
  page — same idea, simpler here since there's only ever one "page" ].
- return the current content as a plain scalar. **no checksum verify** — there
  is nothing to verify against [ unlike shape 1's announced checksum ], the
  reader simply sees whatever is current, by design.

### reading — reuse the already-landed read-only open, do not reinvent

a `Live` reader uses **`AMOS7::SHM::shm_open( $path, { mode => 'read' }, ...)`**
— already present and landed [ `SHM.pm:609` per this session's earlier work —
confirm the exact current line number yourself, it may have shifted ], not a
new mechanism. this is also what makes `Live` trivially cross-user-clean
[ a `taeki`-owned mount read by a bare-`protocol-7` reader works exactly like
shape 1's read-only-open case, no new cross-user problem to solve — confirm
this in your summary rather than assuming it ].

## scope — do not go beyond this

- **no per-node ntime tree** [ tree-shaped content is a separate future task —
  do not build it speculatively here, even if it looks like a small
  addition ]
- **no `Page` reuse** [ decided above — skip it entirely for this task ]
- **no ack / position-tracking atom** [ that is shape 2's mechanism, not this
  one — if you find yourself reaching for `read_feedback`/`write_feedback`,
  stop, that is the wrong atom for this shape ]
- do not touch `Page.pm`, `Feedback.pm`, `Channel`-anything, or any
  `data.mount.shm.*` / `data.channel.shm.*` zenka module — this task is
  **purely** the new standalone `Live.pm` file
- do not wire anything into `data.cmd.shm-self-test` — that exercises the
  zenka thin-wrapper layer, which does not exist yet for `Live` and is not
  part of this task

## verification — standalone, single-process is fine for create/write/read; cross-process for the notify ding

write `bin/dev/script-scratchpad/test-shm-live-mount.pl`:

1. `live_create` a mount with an initial short string and a generous capacity,
   `notify => 1`. confirm the file exists and `live_read` returns the initial
   content exactly.
2. `live_write` a **different**, still-within-capacity string. confirm
   `live_read` [ via a **separate** `shm_open` call, not just re-reading the
   same in-process `$mount->{'mmap_ptr'}` you already hold — open it fresh, the
   same honesty bar every prior phase in this series used ] returns the new
   content, and the **old** content is gone [ `data_size` correctly shrank if
   the new content is shorter — check this explicitly, it is an easy place to
   leave stale trailing bytes from a longer previous write ].
3. attempt a `live_write` with content **longer than capacity** — confirm it
   is rejected cleanly [ an error return, not a corrupted segment — verify the
   segment's content is still byte-identical to what it was before the
   rejected write attempt ].
4. **the notify ding, proven cross-process** [ same standalone fork +
   timing-gap technique every prior phase in this series required — a
   same-process check is not sufficient proof here either ]: fork a child that
   opens the notify FIFO reader and blocks on it [ `watch_fifo` with a
   reasonable timeout, or `open_notify_fifo_reader` + a manual `IO::Select` ] ;
   from the parent, after a short delay, `live_write` new content ; confirm
   the child's watcher actually receives the ding within its timeout. then
   confirm a **mount created without `notify => 1`** has no `.notify` FIFO at
   all [ `-p` test on the would-be path returns false ].
5. confirm a reader using `shm_open(..., { mode => 'read' })` can `live_read`
   successfully [ exercising the already-landed read-only-open path, not
   re-deriving it ].
6. print a clear pass/fail summary, run it for real, paste the output.

## style / pitfalls

same binding list as every prior `AMOS7::SHM` task this session: no
`<[...]>` / `<dotted.data>` syntax in `Live.pm` [ plain Perl, standalone-or-
zenka hybrid, mirror the `$main::PROTOCOL_SEVEN` check style only where it
actually differs behaviorally — note in your summary if `Live` needs that
branch at all, since unlike `shm_create`'s mlock-self-lock logic, nothing
here obviously differs by mode ]. do not touch any existing file's trailing
signature block. do not add a fake stub to the new file. when done, state
plainly: the exact subs added, their signatures, the test script's full
output, and an honest note on which claims were proven cross-process vs which
were only single-process-verified [ per the breakdown above — items 1-3, 5 are
fine single-process ; item 4's ding must be cross-process or it does not count
as proven, per this whole session's established bar ].

#,,.,,,,,,...,,.,,.,.,,.,,.,.,...,.,.,,,,,,.,,..,,...,...,..,,,.,,.,.,,,,,,..,
#DQHNCCLTXOKG4ZRNOBAPERU4T366N4ZXAVKJSTEVC2VKI7BPACHLS25IZIS2V3Q3GD6MX2XWSQX6Y
#\\\|AAPK5FZIKETBCRT5ZS7GJQOTTO3EJRYMDIUCFMC7M72IJDMYTJB \ / AMOS7 \ YOURUM ::
#\[7]46HCNGHB36CUJD2VFTYGD5XN2G3XBTYX32VN47O5H3DMQDNQUSCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
