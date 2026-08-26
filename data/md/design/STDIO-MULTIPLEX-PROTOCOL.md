# stdio + fd multiplex protocol over unix domain sockets

## relation to prior docs and memory topics

this doc is the **wire-protocol layer** under
`data/md/design/STDIO-RELAY-FOLD-APPLICATION.md`. that doc names a
zenka's stdout as an *addressable foldable element* with source →
ingest → store → filter → render layers; this doc specifies the byte
grammar moving between those layers when they straddle a process
boundary [ i.e. between the zenka process and v7's relay, or between
any two zenki, or between a zenka and a remote attached terminal ].

it **extends** [ does not replace ] two existing primitives:

- `[[topic-stream-framing-protocol]]` — the minimal 3+1 bit
  payload/separator frame with the `000` inversion rule. that frame
  remains the low-level *self-synchronising clock*; this doc adds a
  type-tag layer **inside** the 3-bit payload group, choosing the
  payload group's 8 possible values as the type-tag alphabet.
- `[[topic-stream-reply-modes]]` — STRM bounded scalar / unbounded
  live / scalar-ref / filehandle. those reply modes are *single-
  stream* transports; this doc generalises one of them [ the
  unbounded live mode ] into a *multiplexed* transport carrying
  several typed logical streams over one socket.

user framing [ 2026-06-10, verbatim ]: *"generic stdio and file
descriptor redirection and multiplexing using unix domain sockets —
but that will require a clean protocol. i think it might expand bit
groups with types, like: silent input, echo output, ui template
output, content value numerical, content value string, and so on.
because here templates, formats, application data, user input, even
unprocessed buffered input is merging in the network, and with the UI
end getting routed and grouped/contextualized — the deeper the
network, the more central the current UI becomes."*

## the type-tag set [ 8 values, 3 bits ]

the existing 3+1 bit framing's 3-bit payload group has exactly eight
possible patterns [ `000`..`111` ], with `000` already specialised by
the inversion rule as the *field-collapse-saved* signal. that exact
shape is what makes the eight-value type-tag alphabet drop in
naturally: **the type-tag occupies a payload group**, and the
inversion rule's `000` slot becomes the framing-control / metadata
tag rather than a duplicated escape mechanism.

```
tag   bits   name        purpose
META  000    metadata    framing control [ open/close/scope/error ]
                         — the inversion-paired payload group
SIN   001    silent in   user input not echoed [ password, secret ]
RIN   010    raw in      unprocessed buffered input [ paste-block,
                         binary-fed, pre-line-discipline ]
EOUT  011    echo out    ordinary text output [ a zenka's say $line ]
TOUT  100    template    ui-template render output [ structured for
                         a UI renderer to lay out ]
NUM   101    numerical   content value, numeric form [ a metric, a
                         counter, a tick ]
STR   110    string      content value, string form [ a name, a
                         label, a status word ]
ERR   111    error       error / status / log severity payload
```

the choice of which logical value lands on which bit pattern is
deliberate:

- **META = `000`** keeps the framing inversion rule unambiguous: when
  the receiver locks the separator column [ per the framing
  protocol's sliding-window lock ] and reads payload `000`, it knows
  both (a) the separator just inverted from `.` to `,` per the
  framing rule, and (b) the *semantic content* of this payload group
  is "framing metadata," not stream data. one bit-pattern, two
  consistent meanings, no duplicated escape.
- **SIN / RIN** [ `001` / `010` ] are the two single-bit-set inputs
  in their lowest positions — minimal entropy, matching the
  "minimal-state input" they represent.
- **EOUT / TOUT** [ `011` / `100` ] are the two ordinary-text outputs
  the user explicitly named [ "echo output", "ui template output" ].
  EOUT precedes TOUT because plain text is the simpler, more
  primitive output; TOUT is structured-text.
- **NUM / STR** [ `101` / `110` ] are the two content-value outputs
  the user named [ "content value numerical", "content value
  string" ]. NUM precedes STR for the same numerical-before-textual
  ordering reason.
- **ERR = `111`** [ all-ones ] is the maximally-different pattern,
  matching its role as the maximally-attention-demanding stream;
  pattern hamming-distance to META `000` is 3, so even a single bit
  flip in transit cannot turn an error into framing metadata or vice
  versa.

eight tags is enough for the user's explicit list plus the framing
metadata channel; if more are wanted later, the **next** widening of
the framing window's payload group [ from 3 to 4 bits — see the
framing protocol's "8 bits = 3 payload + 3 frame-type + 1 sep + 1
inversion flag" note ] extends the alphabet to 16 without breaking
backwards compatibility, since the high bit at the wider window is
zero for every value in this set.

## how the type-tag composes with the 3+1 bit framing

the framing protocol's frame is `<3-bit payload> <1-bit sep>`. this
doc proposes a **two-level grammar** layered on it, using framing
metadata frames as the level switch.

```
level 0 — the framing stream itself, unchanged.

level 1 — typed-payload run:

    [ META frame ]
        payload = 000
        sep     = ,           [ inverted, per framing rule ]
        meaning = "next N frames carry tag T and content C-encoded
                   payload" — N + T + C packed into the
                   immediately-following payload groups
    [ N data frames ]
        each frame's 3-bit payload carries:
            - one nibble of the typed content [ if C = nibble-pack ],
              or
            - one byte split across two frames [ if C = byte-pack:
              6 bits across two consecutive payloads + 2 bits taken
              from the next META frame ],
              or
            - one Base32 character index [ if C = b32 ],
              one of the natural P7 encodings already in the network
              [ via Crypt::Misc::encode_b32r ]
        sep is `.` for normal data frames; an inverted `,` in this
        run terminates the run early [ next frame is another META ]
```

a META frame's downstream payload nibbles encode:

```
nibble 0   : tag T  [ 3 bits ] + reserved 1 bit
nibble 1   : content-encoding C  [ 2 bits: 00=b32, 01=nibble,
             10=byte-pack, 11=reserved ] + run-length high 2 bits
nibble 2   : run-length low 4 bits
nibble 3+  : tag-specific header [ scope id, fd index, etc. — see
             tag-specific section below ]
```

**why this layout**: the type-tag is itself a 3-bit value matching the
payload-group width, so it ships in one payload group; the encoding
flag determines how the rest of the run is read; the run-length
[ 6 bits → 1..64 frames per typed run, with 0 meaning "until next
META" ] gives the receiver a bound for buffer allocation without
forcing it.

worked frame-stream example, conceptually [ separators shown as `.`
and `,`, payloads shown as 3-bit groups for clarity ]:

```
000,            META         — start of typed run
011.            tag = EOUT
100.            encoding = b32, run = 4 chars
001.            "B" [ b32 index ]
010.            "C"
011.            "D"
100.            "E"
000,            META         — end of run / start of next
111.            tag = ERR
000.            encoding = nibble, run = 1 nibble  [ short status ]
101.            value = 5    [ severity 5 ]
000,            META         — close stream
000.            tag = META   [ sub-meta ]
111.            sub-op = close-scope
```

the framing layer is unchanged. the type-tag layer is purely a
*reading* of the payload groups inside the framing layer.

## unix-domain-socket mapping — one socket, multiplexed

two options are physically possible; this doc picks **one socket,
multiplexed by type tag** and explains both for completeness.

### option A — one socket per fd [ rejected ]

one unix socket per logical stream: separate sockets for stdin,
stdout, stderr, ui-channel, etc. simpler to implement [ each socket
carries one stream, no multiplexing ]. rejected because:

- N sockets per zenka × M zenki = N·M socket fds, scaling badly
- ordering between streams [ "this output line corresponds to that
  input prompt" ] is lost; the receiver has to time-correlate across
  sockets
- detach/reattach has to coordinate N sockets atomically; with one
  socket it is one operation
- the existing v7 stdout relay already runs on a single per-zenka
  socket [ `/dev/shm/.7/STDOUT/<sock>` per
  STDIO-RELAY-FOLD-APPLICATION.md ]; this doc preserves that
  topology

### option B — one socket, multiplexed [ chosen ]

one unix socket per zenka [ or per zenka pair, for cross-zenka
streams ]. the frame stream described above is the wire grammar;
each typed run carries one logical stream's payload. the receiver
demultiplexes by tag.

ordering is **preserved by construction**: typed runs interleave in
arrival order on the wire, so "EOUT line", "SIN prompt accepted",
"NUM tick=42", "TOUT render hint" arrive in exactly the order the
sender emitted them. the receiver may reorder for *display* [ e.g.
buffering SIN secrets out of the TOUT render channel ] but never
loses provenance.

**fd identity within the multiplex** — when a stream needs to carry
fd-level identity [ stdin vs stdout vs stderr vs a custom fd ],
this rides in the META frame's tag-specific header:

```
META header for EOUT/ERR runs:
    nibble 3 :  fd index  [ 0=stdin, 1=stdout, 2=stderr,
                            3..15 = custom fds, addressable in the
                            sender's fd table ]
```

so the same EOUT tag can carry stdout *or* a custom fd's output;
demultiplexing tags pick out *kind* of stream [ silent input,
echoed output, etc. ], the fd-index in the META header picks out
*which* fd within that kind. layered, no duplication.

## "the deeper the network, the more central the current UI becomes"

this is the user's framing for what happens as a stream is relayed
through multiple hops [ zenka → v7 → another zenka → user terminal ]:
each hop must preserve *enough* context that the terminal UI
endpoint can correctly fold/group/filter the resulting tree.

the protocol supports this with **provenance META frames** prepended
to each typed run as the run crosses a relay boundary:

```
META subtype = scope-enter
  hop_id    : 4 nibbles  [ 16-bit relay-local hop counter, sortable
                          ntime-derived in the addressing case ]
  slot_addr : variable    [ slot address per
                          console-stdio-slot-addressing.md, encoded
                          as b32 nibbles, length-prefixed ]
  origin    : variable    [ origin zenka name + sub-tree path,
                          length-prefixed ]
```

each relay hop **wraps** the inbound run by emitting its own
`scope-enter` META, the inbound run verbatim, then a matching
`scope-leave` META. the resulting structure is a nested tree of
typed runs where every leaf carries its full ancestral provenance
on the wire — no out-of-band correlation needed.

the terminal UI's job is then exactly the philosophy doc's
fold/render tree: walk the META scope tree, render each leaf typed
run through the appropriate `<zenka>.stdout.view.*` binding,
collapse scopes via `ui.fold`. zero special-casing for "this
stream came from three hops away" — the META frames *are* the
namespace path.

this is why the user's observation holds: *as relay depth grows,
the META framing overhead grows linearly with depth* [ each hop
adds one scope-enter + one scope-leave ], *but the leaf-run payload
stays the same size, and the UI's job stays exactly the same*. the
UI is the convergence point because the entire tree's worth of
provenance arrives at it with no decode loss; intermediate hops
need only forward, never interpret.

cross-link to existing addressing primitives:

- **slot addresses** [ from
  `data/tasks/console-stdio-slot-addressing.md` and the
  STDIO-RELAY-FOLD-APPLICATION.md doc ] are exactly what the
  `scope-enter` META's `slot_addr` field carries on the wire.
- **per-zenka address roots** [ `<zenka>.stdout.*` from the relay
  fold doc ] are exactly the `origin` field's content.
- **fold/unfold operations** at the UI are operations against the
  scope tree the META frames describe — they do not change the wire.
- **epoch/chksum addressing** [
  `data/md/design/EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md` ] is the
  natural future encoding for `slot_addr` and `hop_id` once the
  helper at `data/tasks/epoch-chksum-path-helper.md` lands — META
  scope frames then carry the same fixed-width epoch/chksum path
  segments the persistent storage layer uses, so a relayed run can
  be addressed end-to-end without recoding. not a prerequisite for
  this protocol [ slot_addr is opaque to the wire ], but the
  alignment is the reason the field is length-prefixed rather than
  fixed-width.

## worked end-to-end example

a zenka [ `weather` ] running interactively under v7's console wants
to:

1. emit a normal stdout line  → `say "loaded config"`
2. prompt the user for an api key, *silently*
3. render a ui-template payload for the v7 console to display the
   current location
4. emit a numeric tick [ refresh interval ]
5. emit an error if the api times out

on the wire to v7's console relay [ conceptual, separator dots
omitted for brevity, payloads shown as 3-bit groups separated by
spaces, META frames bracketed ]:

```
[META scope-enter origin=weather slot=v7.console]
[META enter-run tag=EOUT  enc=b32 run=15 fd=1]
   <15 frames of "loaded config" b32-packed>
[META end-run]

[META enter-run tag=SIN   enc=b32 run=0    fd=0]
   ## run=0 = open-ended; consumer of SIN ends with field-close META
   <user types api key, framed silently, never echoed back as EOUT>
[META close-field]

[META enter-run tag=TOUT  enc=b32 run=24 fd=3]
   <24 frames carrying the ui-template payload, b32-packed>
[META end-run]

[META enter-run tag=NUM   enc=nibble run=2 fd=4]
   <2 frames: tick value = 42>
[META end-run]

[META enter-run tag=ERR   enc=b32 run=18 fd=2]
   <18 frames of "api timeout: 30s" b32-packed>
[META end-run]

[META scope-leave origin=weather]
```

v7's console relay [ the demultiplexer ] reads the META scope-enter,
allocates the `weather.stdout` sub-tree, walks each typed run, routes
to the appropriate slot binding:

- EOUT (fd=1) → the default render line view at `weather.stdout`
- SIN (fd=0)  → the silent-prompt slot [ the user's input is paired
                back through the same multiplexed transport in the
                inbound direction; it is *never* echoed to EOUT ]
- TOUT (fd=3) → the UI-template binding at `weather.stdout.view.
                template`, which is the vterm-rendered surface per
                STDIO-RELAY-FOLD-APPLICATION.md
- NUM (fd=4)  → the status-bar slot at `weather.stdout.metric.tick`
- ERR (fd=2)  → the v7 console's error pane at `weather.stdout.err`,
                surfaced through the existing `base.log` severity
                ladder

all five streams reached v7 over one socket, in the order the zenka
emitted them, with their identity tags carried in-band and their
provenance carried in the wrapping META scope. detach = unbind the
slot bindings without closing the socket; the META frames keep
arriving and the store layer keeps storing. re-attach = bind a fresh
slot at the corresponding address; the next typed run repaints it.

## non-goals

- not a wire-level implementation spec [ bit-packing details and
  encoding conformance live in the task files below, not here ].
- not a replacement for the STRM reply modes — STRM modes remain
  the *intra-command* reply transport. this protocol is the
  *inter-process* stdio transport, riding the same socket plumbing
  but with its own framing.
- not a new socket topology — the existing per-zenka
  `/dev/shm/.7/STDOUT/<sock>` socket is the carrier. only its
  byte grammar gains structure.
- not a hotkey, UI, or rendering decision — that work belongs in
  the slot-addressing + render-tree tasks already queued.
- not a security boundary on its own — META scope authority [ which
  zenka may emit a `scope-enter` claiming which origin ] rides
  through the existing `cube/access.zenki` access-control gate;
  this protocol does not invent a new gate, it merely formalises
  what the gate already controls.

## task tree rooted here

```
CONSOLE-FOLD-TREE-PHILOSOPHY.md            [ first principles ]
└── STDIO-RELAY-FOLD-APPLICATION.md        [ relay-layering doc ]
    └── STDIO-MULTIPLEX-PROTOCOL.md        [ this doc — wire protocol ]
        ├── stdio-multiplex-type-tag-codec.md
        │       [ base.stdio.frame.* encoder/decoder pair ]
        ├── stdio-multiplex-unix-socket-transport.md
        │       [ base.stdio.transport.* unix-socket carrier riding
        │         the type-tag codec ]
        └── v7-console-stdio-multiplex-demux.md
                [ v7.handler.stdio_multiplex demultiplexer routing
                  typed runs to existing slot bindings + ingest layer ]
```

dependency order: codec → transport → demux. the existing v7 relay
[ `v7.handler.process_output_line` etc. ] gains the demux as an
**alternate ingest path** alongside its current line-relay path; the
two coexist while zenki are migrated to the multiplexed transport,
so no zenka has to flip atomically.

#,,,,,,..,.,,,,,.,.,.,,,.,,,.,.,,,,,.,,,.,,..,..,,...,...,...,...,,,.,..,,.,,,
#2F7YIGVDJ374A7VQKZMGPBMQ7VZSRAA2QNXU3EQE26ZWAXYJVF6LREG6DXGHNXUD7HDUBIZHVEJWW
#\\\|6PTBO7OJQ6YSORAY2QFTH5BEVQTJB27BH2QGOW7HLRU6SZT52HS \ / AMOS7 \ YOURUM ::
#\[7]UXF3ELE5MGZBUQ4QRR7TYUYF56QZB4FSO2VT7OVJMUENHCZAVGDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
