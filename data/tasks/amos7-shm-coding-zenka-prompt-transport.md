# task: AMOS7::SHM — large-prompt transport for the coding zenka [ submit + summarize-context ]

## status [ 2026-06-22 ]

**design only — nothing implemented.** this doc is the planning artifact for
the *next* caller of `AMOS7::SHM` after the data zenka's own internal use.
phases 1-3 of `AMOS7::SHM` are landed and live-verified
[ see `data/tasks/amos7-shm-paging-feedback.md` — read it first; this doc
assumes its conclusions and its API surface ]. phase 4 [ cleanup / lifecycle ]
is still design-only there, and is a hard prerequisite for this integration —
see "phase 4 is a prerequisite, not a fast-follow" below. **scope note: the
coding integration uses phases 1 + 2 + 4 only — phase 3 [ the FIFO feedback
channel ] is deliberately out of scope here** [ see "phase 3 is not in the
coding integration" ].

## signatures note

do NOT add the single-line `#,,.,,,...` stub at end of new files.
leave files clean — signatures are added by the signing system automatically.

## objective

give the coding zenka a **backward-compatible, additive fast-path** for
moving a large prompt / summarization-input scalar from a caller
[ standalone `bin/mcp-server-p7`, or another zenka ] into a `coding.cmd.*`
handler **without** that scalar crossing a cube command line — by building a
small **generic utility layer** over the already-landed `AMOS7::SHM` /
`AMOS7::SHM::Page` / `AMOS7::SHM::Feedback`, such that any zenka's `cmd.*`
handler can adopt "writer announces a paged SHM segment + FIFO feedback,
reader pulls it" without re-deriving the mmap / paging / permission-signing /
FIFO wiring by hand.

small prompts must keep working **exactly as today** over the wire — this is
an opt-in path chosen by a size threshold, not a replacement of the existing
command format.

## why this design exists [ grounded in the actual current code — do not bury ]

### the cap is real and shared, confirmed from source

`cfg/shared-params` lines 33-34:

```
size.buffer.input            =  242707
size.buffer.output           =  242707
```

this is the **session input buffer** ceiling enforced in
`src/base.handler.command`. the critical finding — verified by reading the
multiline parser, not assumed — is that **multiline body data shares this same
cap**, it is **not** a higher-capacity framed input path:

- single-line commands match `base.handler.command:352-371` against the
  session input buffer in one regex.
- **multiline** commands [ the `cmd+\n <headers> \n <body> .\n` packet
  `bin/mcp-server-p7`'s `cube_command_multiline:1377` builds ] are matched at
  `base.handler.command:155-237` by a **single regex against the whole input
  buffer**, accumulating body lines into `$call_args->{'data'}`
  [ line 197 ]. the entire packet — `cmd+`, the header block, every body line,
  and the terminating `.\n` — must materialize in the session input buffer
  before that regex can match the closing `.\n`.
- inbound command **input** has no SIZE / STRM framing. SIZE / STRM /
  STRM-SIZE / CHRSIZE in `base.handler.command` are all **reply** [ outbound ]
  modes [ lines 832-929 ]; the inbound `$buf_limit` check at line 847-849 is
  for the reply path. there is no streaming *intake* for a command body.

therefore: **`$call->{'data'}` in a multiline `coding.submit` packet inherits
the 242707-byte ceiling exactly as a single-line arg does.** the body field is
not an escape from the cap.

### `coding.cmd.submit` is the genuinely unescaped case — lead with it

`src/coding.cmd.submit` accepts the request three ways:

- multiline `param` hash → `request` / `question` / `description`
  [ `coding.cmd.submit:14-20` ]
- multiline `data` body, appended as `"\nContext:\n" . $body`
  [ `coding.cmd.submit:34-48` ]
- single-line `args`, optional `B32:` prefix [ `coding.cmd.submit:49-66` ]

**every one of these lands in the 242707-byte session buffer.** there is no
`path=` / file-handoff option in `submit` the way there is in
`summarize-context` [ below ]. a large prompt — a multi-turn context paste, a
big file's contents submitted as a task, a batch of source — that exceeds the
cap hits the **same silent-hang failure mode** the BMW-L13 incident did
[ `data/tasks/amos7-shm-paging-feedback.md` "why this design exists" ]: no
buffer-exceeded error, the connection left in a bad state. **`submit` is the
real motivating gap; describe it first.**

### the BASE32 auto-decode in `submit` does NOT help the cap — it hurts it

`coding.cmd.submit:22-28` [ param ] and `:36-43` [ body ] auto-detect a
`^[2-7A-Z]+=*$` string and `decode_b32r` it; the single-line path honours a
`B32:` prefix at `:54-65`. it is worth stating plainly, since the task asked:

**base32 expands, it does not compress** — 8 output chars per 5 input bytes,
~1.6x. so a payload that arrives base32-encoded occupies ~1.6x its real size
*in the 242707-byte buffer*. the effective ceiling for base32-wrapped content
is therefore only **~151 KB of real bytes** [ `242707 / 1.6` ], **lower** than
raw. the auto-decode is **not** a capacity workaround; its real purpose is
**single-line transport safety** — getting newlines / control bytes / binary
through a line-oriented or whitespace-split arg intact. it makes large
payloads fail *sooner*, not later. this design does not extend it; the SHM
fast-path carries raw bytes and sidesteps base32 entirely.

### `summarize-context` already has a partial, file-based escape — confront it head-on

the central design tension, stated up front so the doc does not assume its own
conclusion: **a file-based escape already exists in production and is cheaper
than SHM.**

`bin/mcp-server-p7`'s `_do_summarize_file` [ line 2783 ] passes
`coding.summarize-context path=$path` and the coding zenka reads the file
directly [ `coding.cmd.summarize-context:46-57` slurps the path ] — the content
**never crosses the wire at all**. the obvious cheap generalization of *that*
is: writer dumps the scalar to a temp file, passes `path=`, reader reads it,
someone unlinks it. so: **what does the SHM paging/feedback channel buy over
generalizing the temp-file escape?**

honest answer, the four things a temp file does not give for free:

1. **zero-copy via mmap** — `substr()` directly into the mapped region, no
   read-load-write cycle on either side [ this is the `tool-shm-architecture`
   vision's whole point: the variable *is* the segment ]. a temp file is two
   full copies [ writer writes, reader reads ] of up-to-megabytes.
2. **cryptographic, not filesystem, access control** — `/dev/shm` is
   world-readable; a temp file's protection is OS perms, which this project
   deliberately does not rely on. `AMOS7::SHM`'s signed permission grants
   [ `permission_verify` ] are the project-native security model, and the
   reader is authorized by a grant the writer signs, not by a `chmod`.
3. **streaming-source memory bounding** — the phase-3 feedback pointer lets a
   writer that is itself streaming from a larger source keep only the
   reader's-position-forward lookahead window resident
   [ `amos7-shm-paging-feedback.md` "streaming-source case" ]. a temp file
   either materializes the whole thing or reinvents this by hand.
4. **one unified cleanup story** — phase 4 will clean up segment + FIFO on
   normal teardown for **both** zenka and standalone mode. a temp-file escape
   needs its own ad-hoc unlink-on-completion logic at every call site, which is
   exactly the per-caller-workaround pattern this whole effort exists to end.

**recommendation recorded, not assumed**: for the coding zenka's prompt /
summarization payloads — which are bounded scalars in the low-MB range, moved
once, same-trust-domain — the temp-file escape would *work*, but adopting SHM
here is what makes the *generic* mechanism real instead of accreting a second
one-off [ after BMW-L13's standalone port, after summarize's `path=` ]. that
said, **this is the single most important thing for the project owner to
confirm before implementation** — see "open questions".

### the in-zenka compaction path is NOT at risk — recorded so it is not chased

`src/coding.async.compact_context` and the blocking
`process-queued-task` compaction operate on `$state->{'messages'}`
**in-memory inside the running task's state machine** — that content never
re-crosses the cube wire, it is already resident. it is **out of scope**: only
the *intake* paths [ `submit`, `summarize-context` ] cross the buffer.

## the at-risk intake paths, precisely

| path | where the big scalar enters | escape today | cap-exposed |
|---|---|---|---|
| `coding.cmd.submit` param / data / args | `coding.cmd.submit:14-66` | **none** | **yes** |
| `coding.cmd.summarize-context` content | `coding.cmd.summarize-context:34` [ `$call->{'data'}` ] / `:40-63` [ B32 / args ] | `path=` file slurp [ `:46-57` ] | yes, on the non-`path` paths |
| `_do_summarize` text path [ mcp side ] | `bin/mcp-server-p7:2339-2344` builds `coding.summarize-context :B32:$encoded` per chunk | rolling-window chunking [ `:2348-2382` ] | yes — chunking IS the current workaround |

note the third row: `_do_summarize`'s rolling-window chunking
[ `bin/mcp-server-p7:2348-2382` ] is **itself** a hand-built cap workaround —
it splits text into `_model_chunk_size()`-sized pieces, base32-encodes each,
and sends each as a separate single-line command, carrying a running summary
forward. that is correct and should **stay** for the model-context-window
reason it also serves [ a chunk must fit the model's context, independent of
the wire cap ]; SHM does not replace it. but for the **non-chunked** single
call [ `_do_summarize:2383-2387`, when text fits one chunk ] and for any future
caller wanting to hand the zenka one large blob to page through, the SHM
fast-path applies.

## proposed generic-utility layer

the goal [ task point 2 ]: a *small* set of helpers any `cmd.*` handler can call
on the **write side** [ caller with a large scalar ] and **read side**
[ handler receiving it ] without re-deriving mmap / paging / permission / FIFO
wiring. these compose the existing `AMOS7::SHM*` subs — they add **no new
mechanics**, only a convenience envelope + the announce/pull choreography.

### where it lives — `AMOS7::SHM::Transport`, a new standalone sibling

mirrors the established layout [ `amos7-shm-paging-feedback.md` "the standalone
/ hybrid precedent" ]:

```
  data/lib-path/pm/AMOS7/SHM/Transport.pm   ## new : the convenience envelope
```

a sibling of `Page.pm` / `Feedback.pm`, same branch-free-mechanics style,
loadable standalone [ so `bin/mcp-server-p7` gets it ] and in-zenka. thin zenka
wrappers `src/data.mount.shm.transport.*` follow, same pattern as
`data.mount.shm.page.*`. **stays under `data.mount.shm.*` / `AMOS7::SHM::*`,
never `base.*`** [ the namespace lesson from the prior doc ].

### write side — `shm_announce`

```perl
## writer : page out a scalar, grant the reader read access, return a compact
## descriptor the caller passes over the wire in place of the payload.       ##
## composes : Page::create + write_page + sign_permission + add the grant     ##
##            to the header + Feedback::create_notify_fifo                     ##
my $announce = AMOS7::SHM::Transport::shm_announce(
    {   'owner_pubkey'  => $writer_pubkey,    ## writer owns the segment       ##
        'owner_privkey' => $writer_privkey,   ## to sign the reader's grant     ##
        'reader_pubkey' => $coding_pubkey,    ## who may read [ see open q. ]   ##
        'content_ref'   => \$big_scalar,      ## scalar ref : no extra copy     ##
        'page_size'     => undef,             ## undef = DEFAULT_PAGE_SIZE       ##
        'sub_path'      => 'coding/submit',   ## namespacing under the pubkey    ##
        'time_source'   => undef,             ## zenka wrapper injects <[base.ntime]> ##
        'mlock'         => 0,                 ## prompts need not be locked      ##
    }
);
## $announce = {
##   shm_path     => '/dev/shm/p7:M:<writer_pubkey>:coding/submit',
##   total_pages  => N,
##   page_size    => P,
##   content_size => L,        ## real byte length, for last-page clip         ##
##   checksum     => '<bmw-L13>',  ## announced content checksum [ Page index ] ##
##   notify_path  => '<shm_path>.notify',
##   grant_sig    => '<signed permission grant for reader_pubkey>',
## }
```

internally `shm_announce`:
1. computes the announced checksum — `<[chk-sum.bmw.L13-str]>` zenka /
   `AMOS7::CHKSUM` standalone — over the content [ same 13-char base32 the rest
   of the project uses; `coding.cmd.summarize-context:85` already uses exactly
   this for content addressing ].
2. `AMOS7::SHM::Page::create($owner_pubkey, $content_size, $page_size,
   $checksum, $options)` — sizes the segment for index + pages + feedback
   region [ `Page::create` already adds `Feedback::FEEDBACK_SIZE` ].
3. writes every page via `Page::write_page` from `content_ref`
   [ or, for a streaming source, only the lookahead window — the feedback
   pointer governs the rest ; not exercised by the coding integration, but the
   primitive supports it ].
4. `AMOS7::SHM::sign_permission` over `{ reader_pubkey, sub_path, rights =>
   ['read'], expiry }` with `owner_privkey`, and adds the grant to the header's
   `permissions` list — this is what makes `shm_open` succeed for the reader.
5. `AMOS7::SHM::Feedback::create_notify_fifo` alongside the segment.

the returned descriptor is **small** [ a path, three integers, a checksum, a
signature — well under any cap ] and is what travels the wire as the
command arg / body, in place of the payload.

### read side — `shm_receive`

```perl
## reader [ inside the cmd.* handler ] : open the announced segment, verify the
## grant, reassemble all pages byte-identically, ding read progress.          ##
## composes : shm_open [ runs permission_verify ] + read_page * N             ##
##            + Feedback::write_feedback + Feedback::ding                       ##
my $received = AMOS7::SHM::Transport::shm_receive(
    {   'announce'      => $announce,         ## the descriptor from the wire   ##
        'reader_privkey'=> $coding_privkey,   ## proves reader identity to open  ##
        'verify_chksum' => TRUE,              ## recompute + compare announced   ##
        'time_source'   => undef,             ## zenka wrapper injects ntime     ##
    }
);
## $received = { ok => TRUE, content_ref => \$reassembled, pages => N }
##          or { ok => FALSE, error => 'access_denied' | 'checksum_mismatch'
##                                     | 'segment_not_found' | ... }
```

internally `shm_receive`:
1. `AMOS7::SHM::shm_open($shm_path, {rights=>['read'], mode=>'read', ...},
   $reader_privkey)` — opens **read-only** [ the API gap above ; required for
   cross-user ], runs `permission_verify`; a reader without a valid signed
   grant gets `{error=>'access_denied'}` and never sees a byte.
2. `Page::read_index` → `Page::read_page` for `0 .. total_pages-1`, concatenated
   [ `read_page` already clips the final partial page to `content_size` ].
3. optional `verify_chksum`: recompute bmw-L13 over the reassembly, compare to
   the announced checksum — **announce-then-pull with verification**, the
   project's own pattern. a mismatch is a hard error, not a warning.
4. **one-shot coding case [ the actual integration ]: no feedback, no FIFO,
   no phase 3 at all.** the reader pulls every page immediately and the
   handler's normal reply is sufficient liveness — the writer never waits on a
   ding. so `shm_receive` in the one-shot case does **not** call
   `Feedback::write_feedback` / `Feedback::ding`, and phase 3 is **out of scope
   for this integration** [ it serves the streaming-source variant, which has
   no caller yet — see "phase 3 is not in the coding integration" below ].

### the one-shot reader must open read-only — a concrete API gap, and the fix for cross-user

this is the cross-process subtlety this project's history says burns time, so
state it as a constraint, not discover it at implementation:

- `AMOS7::SHM::shm_open` opens the segment **`'+<'` [ read-write ]**. `'+<'`
  requires the opening UID to hold **write** permission on the file.
- `shm_create` opens `'+>'`, so the file lands at the writer's umask perms
  [ ~0644 ] — **writable only by its owner UID**. `/dev/shm` is
  world-*readable*, not world-*writable*.
- phases 1-3 only ever proved cross-process via **same-user fork** tests, so
  this never surfaced. **the coding flow is NOT the cross-user blocker** —
  correction recorded after direct verification: `src/coding.init_code:33-48`
  drops privileges to `<system.amos-zenka-user>` [ = `protocol-7`, per
  `cfg/system-user-map:6` ] but **also resolves and joins a secondary
  admin group for project-file access**, and in this deployment the coding zenka
  actually runs as `taeki` [ the admin / human user ] with `protocol-7` as a
  supplementary group [ project owner, direct ]. `bin/mcp-server-p7` runs as
  `taeki` too. so a `taeki`-owned segment is readable by the coding zenka via
  shared user / group anyway — **coding is not the genuine cross-user case.**
  the genuine cross-user beneficiary is a **bare-`protocol-7`** zenka with **no**
  secondary admin-group grant [ e.g. `task`, `cfg/zenki/task/zenka.v7:28`,
  and `p7-log`, `cfg/zenki/p7-log/zenka.v7:24`, both call bare
  `[root.drop_privs:<system.amos-zenka-user>]` with no group resolution like
  coding's ] — a `taeki`-owned segment is **not** readable by such a process
  with no group overlap. the structural problem below is the same either way;
  it just bites a different caller pair. [ see open question 2. ]
- consequence as currently coded, **for the genuine cross-user caller pair**
  [ a `taeki`-owned writer → a bare-`protocol-7` reader zenka like `task` —
  re-verified: the `'+<'`-must-become-read-only finding still holds, it is the
  same structural EACCES, just for `task` rather than coding ]: the reader's
  `shm_open('+<')` fails **EACCES before a single byte is read** — the signed
  grant is never even consulted. and it would contradict benefit #2 [ "security
  is cryptographic, not OS perms" ]: a read-write open makes the mechanism
  *depend* on OS write perms to even function cross-user. [ for the coding
  caller specifically, which shares user / group with `mcp-server-p7`, even the
  current `'+<'` open would succeed — but the read-only fix is still correct: it
  is what makes the mechanism work for the `protocol-7`-only callers that are
  the actual motivating case, and removes the OS-perm dependency for all. ]
- **the fix, which is also a simplification**: the one-shot reader only reads,
  so it should open **read-only [ `'<'` ]**, which a world-readable file in
  `/dev/shm` permits **cross-user** with no OS-perm tension. `shm_open` today
  has no read-only mode — **API gap: add a read-only open path to `shm_open`
  [ e.g. `{ mode => 'read' }` selecting `'<'` ]**, and `shm_receive`'s
  one-shot path uses it. only the **streaming/feedback variant** [ reader
  writes the feedback region → needs write access ] inherits the cross-user
  OS-write-perm tension, and that variant has no caller yet here, so its
  resolution is deferred with it. [ note: the log-channel design — see
  `amos7-shm-log-channel-handshake.md` — IS exactly such a reader-writes-back
  caller, and a genuinely cross-user one [ `p7-log` is bare `protocol-7` ], so
  that doc is where the streaming/reader-write cross-user resolution actually
  comes due. ]

### the asymmetry is deliberate and minimal

`shm_announce` is **caller-side**, `shm_receive` is **handler-side** — they are
not symmetric and should not be forced to be. everything cryptographic
[ grant signing, grant verification ] is composed from already-landed subs;
`Transport.pm` adds only the **choreography** [ checksum-then-page-then-grant on
write; open-then-verify-then-reassemble on read ] and the compact descriptor
shape. no new mmap / header / permission / FIFO mechanics.

### phase 3 is not in the coding integration — scoped out, recorded

the coding integration needs **phases 1 + 2 + 4 only**. phase 3
[ `AMOS7::SHM::Feedback`, the FIFO + ntime freshness channel ] exists to let a
**streaming-source writer** learn the reader's progress without polling — that
is the only thing it buys. the coding flow is **one-shot**: a bounded prompt
scalar, fully materialized, read in full immediately. there is no streaming
source, so there is nothing for feedback to pace. pulling phase 3 in would also
force the reader to **write** the feedback region [ reader-as-sole-writer is the
whole phase-3 design ], which reintroduces the cross-user OS-write-perm blocker
the read-only open specifically avoids. **so: phase 3 stays built and available
for the future streaming/workspace caller, but the coding integration does not
touch it.** the streaming-source variant — if/when a caller appears — is where
feedback + the reader-write open + the deferred cross-user-perm resolution all
belong together.

## coding-zenka integration plan

### new thin zenka wrappers [ under `data.mount.shm.transport.*` ]

- `src/data.mount.shm.transport.announce` → `AMOS7::SHM::Transport::shm_announce`,
  injecting `time_source => sub { <[base.ntime]> }` and the zenka checksum sub,
  mirroring `data.mount.shm.page.create` exactly.
- `src/data.mount.shm.transport.receive` → `AMOS7::SHM::Transport::shm_receive`,
  same injection.
- a 6th check wired into `data.cmd.shm-self-test`: announce a multi-page scalar,
  receive it cross-process, assert byte-identical + checksum-verified + a
  rejected grant denies access. **treat a clean `p7c data.shm-self-test` as the
  hard gate**, same as every prior phase.

these live in the **data** zenka [ it owns `data.mount.shm.*` ]. the coding
zenka does not need to load `data.mount.shm.*`; the receive side it needs is
the **standalone `AMOS7::SHM::Transport`**, called directly in-process — same
judgment call `coding.cmd.summarize-context:85` already exercises by calling
`<[chk-sum.bmw.L13-str]>` directly. so:

### coding-side changes [ additive, behind a threshold gate ]

- **`coding.cmd.submit`** — add, *before* the existing param/data/args parsing,
  a branch: if the incoming arg is a `shm_announce` descriptor [ a small,
  recognizable envelope — e.g. an `SHM:` prefix mirroring the existing `B32:`
  prefix convention at `:54` ], call `AMOS7::SHM::Transport::shm_receive` and
  set `$request_str` from the reassembled content. **the existing small-prompt
  paths are untouched** — they only run when the arg is not an SHM descriptor.
  zero behavior change for callers under the threshold.
- **`coding.cmd.summarize-context`** — same additive branch alongside the
  existing `:B32:` / `:file:` / `path=` prefixes [ `:36-63` ]: a
  `:SHM:<descriptor>` prefix routes to `shm_receive`, sets `$content`. the
  `path=` / `tree=` / option parsing is all unchanged.
- a new helper `coding.shm.recv-descriptor` [ non-`.cmd.`, returns a raw
  scalar-ref / hash, not a `{mode,data}` reply ] so both handlers share one
  decode path and neither inlines the receive logic — split per the style rule
  [ `.cmd.` routines return `{mode,data}` strings; raw helpers are separate ].

### caller-side changes [ `bin/mcp-server-p7` ]

- a `_cube_command_large` helper: given a command + a large scalar, if the
  scalar exceeds the threshold, `AMOS7::SHM::Transport::shm_announce` it and
  send `<cmd> SHM:<descriptor>` over the existing `cube_command`; else send the
  scalar inline exactly as today. `_do_summarize`'s non-chunked branch
  [ `:2383-2387` ] and any direct `coding.submit` from the MCP layer route
  through this helper. **the rolling-window chunking stays** [ it serves the
  model-context constraint too ].
- `bin/mcp-server-p7` is standalone and already `use`s `AMOS7::CHKSUM` via the
  lib-path `BEGIN` block; adding `use AMOS7::SHM::Transport` is the same
  pattern — the proven BMW-L13 standalone precedent.

### the threshold — confirm there is no existing convention, then pick conservatively

[ task point 4 ] there is **no existing project convention** for "small enough
for the wire vs use SHM" — the 242707 value is a config buffer size
[ `shared-params:33` ], not a transport-decision threshold, and the only prior
decisions are per-caller [ chunk size in `_do_summarize`, the implicit
buffer cap ]. so propose one explicitly:

```
## tunable : raw-byte threshold above which a scalar takes the SHM fast-path  ##
## instead of the wire. conservative — well under both the 242707 raw cap and  ##
## the ~151 KB base32-effective cap — so neither the inline nor the base32     ##
## path can hit the silent-hang failure mode.                                  ##
coding.cfg.shm-transport-threshold = 65536    ## 64 KB raw, tunable            ##
```

64 KB is deliberately well below 151 KB so there is comfortable headroom for
the command name, headers, and any base32 expansion on the *small* path. it is
a config value, tunable per the model-load-statistics-style "survey before
picking" habit, not a magic constant. **below the threshold: send inline,
behavior identical to today. at or above: SHM fast-path.**

## phase 4 is a prerequisite, not a fast-follow — explicit answer

[ task point 3 ] a coding task's large-prompt segment **must** be cleaned up
reliably on task completion / failure / timeout. phase 4 of
`amos7-shm-paging-feedback.md` [ segment + FIFO cleanup, both zenka and
standalone mode ] is currently design-only. this integration cannot ship a
durable leak, so:

**decision: phase 4 [ at least its standalone-mode half ] is a hard
prerequisite for the *caller* side, and the *reader* side gets an explicit
interim cleanup contract regardless.** concretely:

- **the writer owns the segment lifetime, not the reader.** in the coding flow
  the writer is `bin/mcp-server-p7` [ standalone ] or another zenka; the reader
  is the coding zenka. the segment + FIFO must be unlinked when the *transfer*
  is done, and the writer is the natural owner of that decision because it
  created them. → the writer holds the segment until it has confirmation the
  reader finished [ the handler's reply, or a final feedback ding ], then
  unlinks. this needs phase 4's **standalone `END` block + explicit cleanup
  call** to guarantee cleanup even if the writer dies mid-transfer.
- **interim cleanup story if phase 4's zenka half is not done first**: the
  segment lives under `/dev/shm/p7:M:<writer_pubkey>:coding/<task-or-chk>`. add
  a **bounded interim sweep** — a `data.mount.shm.*` reaper that unlinks any
  `coding/`-subpathed segment whose header `created` ntime is older than a
  conservative TTL [ longer than the longest plausible task: e.g. the
  590s summarize alarm in `mcp-server-p7:1681`, padded — say 1 hour ]. this is
  explicitly a **safety net, not the primary path**; the primary path is
  writer-owned unlink-on-completion. the TTL sweep guarantees no segment
  outlives a crashed writer by more than the TTL, closing the "writer died, no
  `END` ran [ SIGKILL ]" hole that even phase 4's `END` block cannot.
- **the FIFO follows the segment** — `Feedback::notify_path` is
  `<shm_path>.notify`; whatever unlinks the segment unlinks the FIFO in the
  same step [ phase 4 already plans this ; the coding integration must not
  invent a second FIFO-cleanup path ].

**do not ship the coding integration until either phase 4's standalone half is
done OR the interim TTL sweep is in place** — preferably both. this is stated
as a gate, not a hope.

## backward compatibility — stated as an invariant

- every existing small-prompt `coding.submit` and `coding.summarize-context`
  call, single-line and multiline, behaves **byte-for-byte as today** — the SHM
  branch only fires on the explicit `SHM:` descriptor prefix, which no existing
  caller emits.
- the `B32:` / `:B32:` / `:file:` / `path=` prefixes are all untouched.
- `_do_summarize`'s rolling-window chunking is untouched [ it serves the model
  context window, not just the wire cap ].
- `p7c data.shm-self-test` must pass unchanged + with the new 6th check.
- no new code under `base.*`.

## style

[ same as `amos7-shm-paging-feedback.md` ; repeated as the binding list ]

- lowercase comments, `[ word ]` bracket annotations [ never `( word )` ]
- `$ARG` / `@ARG`, not `$_` / `@_`, where used implicitly
- `<mount.shm.segments>->{}` dotted-data style, not `$data{'mount'}{'shm'}{}`
- `.cmd.` / whitelisted routines return `{ mode => true|false, data => STRING }`
  — split raw-hash / scalar-ref helpers into separate non-`.cmd.` routines
- `<[base.logs]>->( N, fmt, args )` for logging, not warn / print
- config paths via `<system.root_path>/...`; never bare relative
- TRUE / FALSE / UNKNOWN constants, never literal 0 / 1
- standalone packages use the lib-path `BEGIN` + `$main::PROTOCOL_SEVEN` check
  [ mirror `AMOS7::CHKSUM` / `bin/amos-chksum` ]
- new SHM code stays under `data.mount.shm.*` / `AMOS7::SHM::*`, **never**
  `base.*`
- the descriptor envelope prefix `SHM:` mirrors the existing `B32:` prefix
  convention in `coding.cmd.submit` / `coding.cmd.summarize-context`

## acceptance [ overall ]

- [ ] `AMOS7::SHM::Transport` [ `shm_announce` / `shm_receive` ] is loadable
      both standalone and in-zenka; it adds only choreography + a compact
      descriptor, composing already-landed `AMOS7::SHM*` subs — no new mmap /
      header / permission / FIFO mechanics
- [ ] a large scalar announced by a standalone writer is received
      byte-identically by a forked reader, with the announced bmw-L13 checksum
      verified on the read side — proven with a **standalone fork + timing-gap
      script**, never a same-process check [ the phase-3 lesson ]
- [ ] the one-shot reader opens **read-only** [ new `shm_open` mode ] so the
      transfer works **cross-user** [ `/dev/shm` world-readable ] — confirmed
      with a genuinely cross-user test, not a same-user fork
- [ ] phase 3 [ Feedback / FIFO ] is **not** touched by the coding integration
      [ scoped to the future streaming-source variant ]
- [ ] a reader without a valid signed grant gets `access_denied` and reads
      zero bytes
- [ ] `coding.cmd.submit` and `coding.cmd.summarize-context` accept an `SHM:`
      descriptor additively; **every** existing inline / `B32:` / `path=` path
      is byte-for-byte unchanged
- [ ] a scalar below `coding.cfg.shm-transport-threshold` goes inline,
      identical to today; at or above, it takes the SHM fast-path
- [ ] `_do_summarize`'s rolling-window chunking is unchanged
- [ ] segment + FIFO are cleaned up on normal completion [ writer-owned
      unlink ] AND there is a bounded TTL safety-net sweep for crashed-writer
      cases — phase 4's standalone half is a hard prerequisite, the TTL sweep
      is mandatory regardless
- [ ] `p7c data.shm-self-test` passes unchanged + a new 6th transport check
- [ ] no new SHM code under `base.*`

## open questions [ for the project owner — do not decide unilaterally ]

1. **[ MOST IMPORTANT ] SHM paging/feedback vs generalizing the temp-file
   escape, for *this* use case.** `summarize-context`'s `path=` proves a
   file-handoff already works and is cheaper to build. SHM's wins are real
   [ zero-copy mmap, cryptographic grants, streaming-source bounding, unified
   phase-4 cleanup ] but for bounded low-MB prompts moved once,
   same-trust-domain, a generalized temp-file path might be the proportionate
   answer — with SHM reserved for the genuinely streaming / very-large /
   editor-workspace cases the `tool-shm-architecture` vision targets. **is the
   coding-zenka prompt path the right first non-data caller of SHM, or should
   it use a generalized file handoff and SHM wait for the workspace use case?**
   this decision sets whether `AMOS7::SHM::Transport` gets built now or later.

2. **cross-user feasibility + key provisioning across the standalone/zenka
   boundary.** two coupled gaps — **corrected from an earlier draft that wrongly
   made the coding zenka the headline cross-user blocker**:
   - **cross-user OS perms [ the harder half ] — coding is NOT the blocker, a
     bare-`protocol-7` zenka is**: re-verified, `bin/mcp-server-p7` and the
     coding zenka both run as `taeki` [ coding resolves a secondary admin group,
     `coding.init_code:33-48`; they share user / group ], so for **this** caller
     pair even the current `'+<'` read-write open would succeed and there is no
     cross-user blocker at all. the genuine cross-user case is a writer owned by
     `taeki` handing to a **bare-`protocol-7`** reader zenka [ `task`,
     `cfg/zenki/task/zenka.v7:28`; `p7-log`,
     `cfg/zenki/p7-log/zenka.v7:24` — bare `[root.drop_privs:<system.amos-zenka-user>]`,
     no admin-group grant ]. the one-shot read-only-open path above is what makes
     **that** pair work [ `/dev/shm` world-readable ], and it still **must be
     verified with a genuinely cross-user test** [ a `taeki`-owned segment read
     by a `protocol-7`-only process ], not a same-user fork. any
     streaming/feedback variant [ which needs reader-*write* ] still needs a real
     answer [ shared group + group-writable segment? ] before it can exist
     cross-user — and the log-channel design
     [ `amos7-shm-log-channel-handshake.md` ] is precisely such a cross-user
     reader-write caller, so that is where this resolution comes due.
   - **key provisioning**: `shm_announce` needs the *writer's* keypair [ to own
     + sign the grant ] and the *reader's* pubkey [ the coding zenka's, to grant
     it ]. `mcp-server-p7` authenticates to cube as `unix-$USER`, not via a
     C25519 key it holds for SHM ownership, and has no obvious way to discover
     the coding zenka's pubkey today. **where does a standalone writer get a
     C25519 keypair for SHM ownership, and how does it learn the coding zenka's
     reader pubkey** — a cube command [ `coding.pubkey` ], a shared key tree, or
     is the writer expected to be a zenka in the first instance?

3. **page size for prompt-shaped content.** `DEFAULT_PAGE_SIZE` was chosen for
   the data zenka's own tests; is it right for low-MB UTF-8 prompt text, or
   should `shm_announce` pick a prompt-tuned page size [ and does the
   announce/pull round-trip cost matter at all for one-shot transfers, where the
   reader pulls every page immediately anyway ]?

4. **descriptor on the wire — prefix vs structured arg.** the `SHM:<descriptor>`
   prefix mirrors `B32:`, but the descriptor is a small structured object
   [ path, integers, checksum, signature ]. encode it as a compact base32 /
   colon-joined string behind `SHM:`, or carry it as multiline `param` headers?
   leaning prefix-string for symmetry with the existing convention, but worth a
   nod.

#,,,.,,,,,,..,,..,,..,..,,.,.,.,.,,..,..,,,,.,..,,...,...,.,,,...,.,.,...,..,,
#F4PT5I6B7AMZQBU5FQAPKNGNSMFMOR7TE5QZIVMP53I3CMX6ZQFXR6JOKW3VDD2CKM3DBAWVRP6NA
#\\\|4YRPBOILONU4OFVDCWNBCTOKTAM3JUJOE6VEY4ULGQ4D237YAHZ \ / AMOS7 \ YOURUM ::
#\[7]FOBZ3XQLWCRF3CFA5BHDJOA4ZFZZ5TCJ4BBJFP5TUADKFA7CM4DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
