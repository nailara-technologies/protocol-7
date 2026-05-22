# self-delimiting token pattern — 2-bit type system

## core insight

a checksum is only meaningful if the receiver knows what it was computed over.
the naive approach requires a separate size field, a framing protocol, or
out-of-band agreement. all three introduce coupling.

the self-delimiting checksum encodes that knowledge intrinsically:

```
0 + zero-padded-decimal-size + AMOS7-checksum
```

example: `01303UGKDZQ` = AMOS7 checksum over 13 bytes of input.

the `0` prefix is outside the base32 alphabet (which uses A-Z and 2-7).
`0` and `1` cannot appear in base32 output — they are permanently available
as unambiguous sentinels at any position in any base32 stream.

---

## properties

### self-describing
the token carries its own context. a receiver seeing `01303UGKDZQ` knows
immediately: "this is a checksum over 13 bytes" — without a framing protocol,
without a length prefix field, without a schema.

### separator-free chaining
multiple tokens concatenate without delimiters:

```
01303UGKDZQ0130YYFIJII
```

two AMOS7 checksums, each over 13 bytes, no separator needed. the `0` sentinel
re-synchronizes the parser at each token boundary.

### size as security
a forged or replayed checksum claiming the wrong size fails immediately against
the actual received bytes. the size is not decorative — it is load-bearing
for integrity. an attacker cannot substitute a valid checksum from a different
context without also matching the size declaration.

### composable at every layer
the same token works at any granularity:

- chunk level: inline anchor in a DATA-CHANNELS stream
- page level: DATA-PAGE END checksum
- channel level: DATA-CHANNEL close verification  
- stream level: DATA END checksum
- session level: multi-hop rhizome bubble checksum tree leaf
- standalone: branch node reference, dep-graph module identity

no special casing per layer — the pattern is identical throughout.

---

## 2-bit type system

the sentinel space gives four unambiguous token types via 2-bit prefix.
the MSB encodes domain, the LSB encodes the level of claim:

```
domain bit (MSB):
  0x  — data domain    : about the content itself, passive
  1x  — reference domain : points outward, relational

claim bit (LSB):
  x0  — basic claim
  x1  — extended claim
```

### the four types

```
00  checksum      — data domain, basic integrity
                    size + AMOS7 checksum, passive, no side effects
                    example: 01303UGKDZQ (checksum over 13 bytes)

01  signature     — data domain, extended integrity
                    size + stronger cryptographic claim, passive
                    reserved — format identical to 00, stronger verifier

10  incomplete ref — reference domain, basic
                    points to a location, no invocation, no side effects
                    sticky — persists as routing context until consumed
                    analog: cursor moved to position in grid

11  complete ref   — reference domain, extended
                    points AND invokes — function call or data retrieval
                    reply expected
                    transparent — collapses after successful completion
```

### persistence semantics

`10` is **sticky** — it remains as active context after being processed.
a chain of `10` tokens builds a routing path hop by hop, each hop adding
to the accumulated context. the cursor stays where it was moved.

`11` is **transparent** — it consumes the accumulated `10` context, fires
the invocation, and collapses on success. on failure or deferred reply,
it remains active (effectively demotes to `10` semantics while waiting).

### group vs individual collapse

a chain `10 10 11` has two behaviors depending on declaration:

```
10 <A> 10 <B> 11 <C>  [keep]   — 11 collapses alone after invocation,
                                  10 10 route persists for reuse

10 <A> 10 <B> 11 <C>  [close]  — entire chain collapses together after
                                  11 completes, route released
```

analog to HTTP connection semantics:
- `keep` = connection: keep-alive — route establishment amortized across
  multiple calls, efficient for high-frequency access to same destination
- `close` = connection: close — one-shot route, clean, no residual state

policy determines default: close is safer and explicit, keep-alive is
promoted when usage pattern warrants it (repeated calls, media streams,
standing connections through gates).

### routing chains and gate traversal

`10` tokens chain as hops through the reference space:

```
10 <gate>     — move cursor to gate position
10 <inner>    — now inside gate's coordinate space, position within it
11 <target>   — invoke at destination, reply expected
```

the second `10` is already operating in the destination cube's coordinate
space — the gate became an implicit coordinate transform. each hop shifts
the reference frame for subsequent tokens in the chain.

`10 10 [keep] 11` — standing route through gate, reused across calls.
`10 10 [close] 11` — one-shot jump, gate traversal and call as a unit.

---

## usage in DATA-CHANNELS stream

inline validation anchors use the self-delimiting format directly:

```
DATA-CHANNELS <chksum_A> <chksum_B>\n
0: <B32_CHUNK>\n          ← channel 0 payload
0: <B32_CHUNK>\n
1: <B32_CHUNK>\n          ← channel 1 payload
0| 01303UGKDZQ\n          ← inline anchor: channel 0, covers 13 decoded bytes
1: <B32_CHUNK>\n
0: <B32_CHUNK>\n
0| 01303UGKDZQ\n          ← next anchor, receiver locks validated region
DATA-CHANNELS END <AMOS_CHECKSUM>\n
```

- `:` after channel index = payload line
- `|` after channel index = validation anchor line
- the anchor's self-delimiting checksum tells the receiver exactly what range
  was validated — no separate range declaration needed

receiver maintains two pointers:
- **validated-to**: everything before last confirmed anchor — safe to lock,
  release from validation buffer, commit to output
- **buffered-ahead**: speculatively received, playing at constant speed,
  awaiting next anchor

for media streams: validated frames are locked and freed from re-validation
requirement. playback continues uninterrupted. validation cost is amortized
across anchor intervals, not paid per-chunk.

---

## usage as branch node reference

a branch node's identity in the checksum tree:

```
01303UGKDZQ   = this node's content checksum (13 bytes)
```

the size component makes the reference self-verifying — a node claiming this
identity must produce exactly 13 bytes that hash to `3UGKDZQ`. size mismatch
is detected before the hash is even computed.

---

## connection to checksum tree wire format

the checksum tree uses `1[zeros]1` bit-length separators for tree structure.
the self-delimiting checksum pattern provides the leaf values that populate
that tree. together they form a complete, self-describing integrity structure:

- tree wire format: how nodes relate (structure)
- self-delimiting checksum: what each node contains (identity + size)

see `DANCING-ZENKI-RHIZOME-STATE.md` for the full checksum tree context.

---

## generic application principle

this pattern should be applied wherever:

1. a checksum or signature needs to be embedded in a stream or concatenated
   with other tokens
2. the receiver needs to know the input domain without out-of-band context
3. composability across layers is desired

the test: if you find yourself adding a separate size field next to a checksum,
use the self-delimiting format instead. the size and the checksum belong
together — separating them is the source of the coupling the pattern eliminates.

---

## related documents

- `DATA-PROTOCOL-SYNC.md` — DATA/DATA-PAGES/DATA-CHANNELS wire formats
- `CHECKSUM-ROUTING-SECURITY-DEPTH.md` — routing security via checksums
- `UNIFYING-PRINCIPLE-CHECKSUM-COORDINATES.md` — checksums as coordinates
- `DANCING-ZENKI-RHIZOME-STATE.md` — checksum tree wire format, bubble travel
- `AMOS_CHECKSUM_BLOCKCHAIN.md` — AMOS7 left-shift blockchain properties

#,,,,,,..,...,,,,,...,.,.,,,.,,..,.,.,,,.,,.,,..,,...,...,.,,,...,..,,,,.,..,,
#LWW23YAP4EWM2VE4GUR5UZ74PKQ232XMWCRGK7PMST6EVISZSVNGXOBRU6NA77OQN7YJKJW2IQ3YS
#\\\|6HVPBDVTPJDYYPG5DKRRYGG3ZG6M4VWV55VYTEBR75PJM2MIFMA \ / AMOS7 \ YOURUM ::
#\[7]EXFYENNNCUWMV4U7ZX6MPDP5LVDFU4X2WFMOPXLSA2236EHBJSBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
