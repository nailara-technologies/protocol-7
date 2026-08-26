
 .:[  kimi priority queue — next session  ]:.

## Context

Phase 2 (cube-13 jump routing) is complete. Phase 3 has been redesigned.
New harmonic correlations discovered and full transit vision architecture
documented. This list reflects the updated architecture and next concrete steps.

**New primary reference** (read this first):
- `data/md/documentation/harmonic-transit-vision-architecture.md`
  — complete DTM, 15-bit footer, multi-speed lanes, sunburst promotion,
    PYTAURAZA sync, lens effect on distance. Fully actionable.

Reference documents:
- `data/md/documentation/harmonic-cycle-correlations.md` — math and design specs
- `data/md/documentation/cube-13-zulum-decoder-system.md` — system overview
- `data/md/coding-tasks/zulum-decoder-routing-reference.md` — routing patterns

---

## Tier 1 : Phase 3 — Passive Boundary Detection [ ✅ COMPLETED ]

**Status**: Implemented and committed
**Commit**: `69635653c` Fix per-stream level-6 accumulator isolation in decoder

Phase 3 was previously planned as a coordination problem: cube-13 sends
explicit boundary notifications to decoder on stream switch. That plan
is now obsolete.

**Revised Phase 3**: decoder detects boundaries passively by watching
for the value 769230 in its accumulator. This is the universal harmonic
convergence attractor — it appears naturally at every stream transition.

See `harmonic-cycle-correlations.md` §"Design Implication: Passive Boundary
Detection" for the full derivation.

**Implementation notes**:
- Passive boundary detection via 769230 already functional in `decoder.zenka.receive_entropy`
- `decoder.handler.on-boundary` exists and handles buffer closure
- Per-stream accumulator isolation completed to prevent interleaving

### 1.1 decoder.zenka.receive_entropy — watch for 769230

When the decoded accumulator value reaches 769230 (or when the base32
buffer contains `L\` — its ASCII representation), treat it as a boundary:
close the current level buffers and begin a fresh accumulation segment.

```perl
## in decoder.zenka.receive_entropy, after extracting each value ##
if ( $decoded_value == 769230 ) {
    ## natural boundary — harmonic convergence attractor ##
    ## close all level buffers, emit boundary event ##
    <[protocol-7.route-send]>->(
        {   'command'   => 'decoder.handler.on-boundary',
            'call_args' => { 'args' => "$stream_id 769230" },
        }
    );
}
```

No modification to cube-13 needed. The boundary is self-announcing.

### 1.2 decoder.handler.on-boundary — new module

Handle the boundary event:
- emit `[ boundary detected — stream $sid at convergence root ]` to log
- close all level buffers: mark each as `'closed'` in state
- push current stream's P7REF onto `@INDEXCUBE` (see Tier 2)
- optionally reset accumulator for fresh segment

```perl
## decoder.handler.on-boundary ##
my ( $stream_id, $boundary_value ) = split m| +|, $call->{'args'}, 2;

## close all level buffers for this stream ##
for my $level ( keys %{ $data{'decoder'}{'buffers'} } ) {
    $data{'decoder'}{'buffers'}{$level}{'state'} = 'closed';
}
## log boundary ##
<[base.log]>->( 2, "decoder boundary at stream $stream_id [ $boundary_value ]" );
```

### 1.3 Verify with live stream

```bash
## run stream until 769230 appears ##
for i in $(seq 1 50); do
    echo "zulum.step 1" | p7 zulum
done
echo "decoder.show-accumulator" | p7 decoder
## expect: boundary event logged, buffers reset ##
```

769230 is guaranteed to appear in every stream — it is algebraically
forced by `(076923 × N) / (N/10) = 769230`. The iteration count until
first appearance depends on starting position and step size.

---

## Tier 2 : cube-13 Correctness Fix — jump reverse Entry Point [ ✅ COMPLETED ]

**Status**: Implemented and committed
**Commit**: `36160ccc2` Fix cube-13 jump reverse entry point and add root jump

**Bug**: `jump reverse` in cube-13 may be using stream 7 (×7 = 538461)
as entry point. Only stream 3 (×3 = 230769) produces a true digit
reversal under /0.7. Stream 7 only rolls left by one position.

**Fix applied**:
- `jump reverse` now correctly returns stream 3 (230769), the harmonic mirror entry point
- Old buggy behavior: decremented stream ID, which doesn't reach 230769
- New behavior: always jumps to stream 3 where /0.7 produces true reversal

**Bonus**: Added `jump root` to stream 10 (769230), the convergence attractor

From `harmonic-cycle-correlations.md` §"The /0.7 Operator":
```
538461 / 0.7 = 769230     ## roll left once — stays in cycle family ##
230769 / 0.7 = 329670     ## true digit reversal — 076923 → 329670  ##
```

### 2.1 Check src/cube-13.cmd.jump

Read the current `jump reverse` implementation. If it switches to stream 7,
correct it to switch to stream 3 (or, if it reverses the current position
value, verify that it uses `/0.7` on 230769 not on 538461).

The correct behavior:
- `jump reverse` → switch active stream to stream 3 (230769 = gen × 3)
- from stream 3, the `/0.7` operator gives 329670 — the true mirror

### 2.2 Add cube-13.jump root

New jump direction: return any stream directly to the convergence root.
Stream N uses operator `/0.N` — no lookup table needed:

```perl
## in cube-13.cmd.jump, add 'root' direction ##
'root' => sub {
    my $stream_n = $ARG;
    ## (gen × N) / (N/10) = 769230 algebraically guaranteed ##
    ## switch active stream to stream producing 769230 ##
    ## equivalently: compute target = current / ("0.$stream_n" + 0) ##
    return 769230;    ## the attractor — any N reaches here in one step ##
},
```

The jump router switches to whichever stream is currently at position
769230, or marks the active stream's next emission target as 769230.

---

## Tier 3 : Decoder Level 6 — Linguistic Projection [ ✅ COMPLETED ]

**Status**: Implemented and committed
**Commit**: `557172226` Tier 3: Decoder Level 6 — Linguistic Projection

From `harmonic-cycle-correlations.md` §"Encoding Depth as Projection Layer":

`asc-enc -d3` encodes 3 digits per character → Unicode 100-999 → IPA,
phonetic, linguistic territory. Level 6 of the decoder adds this projection
as a parallel output channel alongside binary/octal/base32.

### 3.1 decoder.zenka.init_code — level-6-D3 buffer

✅ Level-6-D3 buffer initialized alongside level-5-B32:
- Per-stream state: `<decoder.level6>->{$stream_id}`
- Buffer: `level-6-D3` with 65536 max_size

### 3.2 Projection logic: per-stream D3 accumulator

✅ `decoder.zenka.receive_entropy` extracts 3-digit groups → Unicode codepoints:
```perl
## level-6 : accumulate 3 decimal digits → unicode codepoint [ per-stream state ] ##
<decoder.level6>->{$stream_id}{'accumulator'} //= '';
my $L6 = <decoder.level6>->{$stream_id};
$L6->{'accumulator'} .= sprintf '%d', $decimal;
while ( length( $L6->{'accumulator'} ) >= 3 ) {
    my $code_point = 0 + substr( $L6->{'accumulator'}, 0, 3 );
    $L6->{'accumulator'} = substr( $L6->{'accumulator'}, 3 );
    my $unicode_char = chr($code_point);
    <[base.buffer.add_line]>->(
        qw| level-6-D3 |,
        join( ' ', sprintf( "%03d", $code_point ), $unicode_char ), 0
    );
}
```

### 3.3 decoder.cmd.show-buffer — level 5/6 support

✅ New module `decoder.cmd.show-buffer` maps level to buffer:
- `decoder.show-buffer 5` → `level-5-B32` buffer
- `decoder.show-buffer 6` → `level-6-D3` buffer

### 3.4 decoder.cmd.show-accumulator — per-stream level-6

✅ Updated to display per-stream level-6 accumulator state alongside level-5.

---

## Tier 4 : @INDEXCUBE Stream Tagging [ ✅ COMPLETED ]

**Status**: Implemented and committed
**Commit**: `40359a72e` Tier 4: @INDEXCUBE Stream Tagging

From `zulum-cube13-decoder-integration.md` §"Connection to @INDEXCUBE":

Each stream has a cube coordinate derived from its cycle position.
Decoder tracks which stream is active by pushing P7REFs onto @INDEXCUBE.

### 4.1 zulum.cmd.stream-status — return P7REF

✅ Returns formatted status with P7REF:
```perl
## generate P7REF: TYPE:CHKSUM7:ADDR_B32 ##
my $cycle_val = $stream->{'seed'};    ## 76923 × stream_id ##
my $amos_chk  = $code{'chk-sum.amos'} // $code{'base.chk-sum.amos'};
my $chksum7   = $amos_chk->($cycle_val);
my $addr_b32  = substr( $chksum7, 0, 6 );
my $p7ref     = "STREAM:$chksum7:$addr_b32";

return {
    'mode' => qw| size |,
    'data' => sprintf(
          "stream    : %d\n"
        . "p7ref     : %s\n"
        . "seed      : %d\n"
        . "iteration : %d\n"
        . "attached  : %d\n",
        $stream_id, $p7ref, $stream->{'seed'},
        $stream->{'iteration'}, $attached_count
    )
};
```

### 4.2 decoder.handler.on-boundary — push to @INDEXCUBE

✅ Queries zulum for P7REF and records traversal:
```perl
my $stream_status = <[zulum.cmd.stream-status]>->(
    { 'stream_id' => $stream_id }
);
my $p7ref = "STREAM:UNKNOWN:XXXXXX";
if ( $stream_status->{'mode'} eq 'size' ) {
    ( $p7ref ) = $stream_status->{'data'} =~ m|^p7ref\s+:\s+(\S+)|m;
    $p7ref //= "STREAM:PARSE_ERROR:XXXXXX";
}

push @{ $data{'decoder'}{'INDEXCUBE'} }, {
    'stream_id'      => $stream_id,
    'boundary_value' => $boundary_value + 0,
    'boundary_n'     => $boundary_n,
    'p7ref'          => $p7ref,
    'timestamp'      => time(),
    'depth'          => scalar @{ $data{'decoder'}{'INDEXCUBE'} },
};
```

Traversal log = sequence of visited cycle positions = proof of navigation.

---

## Tier 5 : Correctness Fixes Carried Forward [ ✅ COMPLETED ]

**Status**: Verified — both fixes already applied in prior commits.

### 5.1 models.handler.llm_response — use format.json.decode

✅ **Fixed in commit `83a4d0f5a`**
Uses `<[format.json.decode]>->($body)` instead of `JSON::PP::decode_json($body)`.

### 5.2 base.p7ref.self — ADDR_B32 from AMOS7 checksum

✅ **Fixed in commit `262d0f130`** (swap-boundary dispatch)
ADDR_B32 derived from AMOS7 checksum:
```perl
my $amos_chksum = $code{'chk-sum.amos'} // $code{'base.chk-sum.amos'};
my $addr_b32 = substr( $amos_chksum->($addr_input), 0, 6 );
```

---

## Next Session Candidates (Claude suggestions)

Well-suited for Kimi (self-contained, documented, ~2h scope):

### decoder.cmd.harmony — /13 chain tool as live zenka command
Wire `bin/dev/display-D13-collection` or similar /13 chain tool as a live decoder command feeding from the accumulator. Pure decoder work, well-scoped.

### decoder.cmd.D13-collection — harmonic display command
Expose `bin/dev/display-D13-collection` as `decoder.cmd.D13-collection`. Shares harmonic math context with harmony command.

### decoder.cmd.show-vterm damage query — screen readback
Expose what's landed on the 25×80 vterm surface. Documented in roadmap, fits decoder context. Query damage/screen state.

### passive prefix detection table — ANSI/Hayes/JJFE lookup
Architecture section 8 prefix table as live lookup module in decoder. Creative/architectural, good fit.

**Suggested starting point**: decoder.cmd.harmony + D13-collection as a pair (shared harmonic math context), then vterm screen readback if time remains.

---

## Do Not Attempt

- `fix-list-alignment-offset-truncation.md` — needs live captures first
- `lm-vision-binary-rebuild.md` — low priority
- `zenka-key-identity-infrastructure.md` — large, separate track
- Any changes to `base.parser.decode_harmonized_refstr` — recently fixed

---

## Notes for Kimi

- **769230 = `L\`** — this is the boundary marker AND the harmonic
  convergence attractor. Passive detection: no explicit notification
  from cube-13 needed.
- **jump reverse uses stream 3** (230769, gen × 3) as entry point —
  not stream 7. Only stream 3 produces true digit reversal under /0.7.
- **Level 6 = linguistic** — 3 digits per char → IPA/phonetic Unicode.
  The ×9 position (692307) at -d3 gives `ʴĳ` — phonetic territory.
- **`(076923 × N) / (N/10) = 769230`** for all N — stream N reaches
  convergence in one step via its own `/0.N` operator. operator = stream#.
- See `bin/dev/octal-stream-window` for the 4-bit/5-bit window safety proof
  visualization; 5-bit minimum is now documented and visualized.
- Sign all new files: `bin/Protocol-7 sourcecode update-signatures`

#,,..,..,,..,,..,,,,.,,,.,,,.,,,.,...,...,...,.,.,...,...,,,.,.,,,,,,,...,,.,,
#MJMNMLCLXBKWQHKRGFMYMDQZTDRIOLJBCII6BKLOVXHKRP25GNCKH3DOY226CT7UPWTQZJEW7THBG
#\\\|MOIO6EMRE32ZJJYRRP2FTOFH7K2RHQFC4RF7IYFNF5YR3RSEQJ4 \ / AMOS7 \ YOURUM ::
#\[7]MNN7SYEWVVOJR3TDOFIJ4TQGFKJDUS6BOI4666INMYG5ZMSWIGCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
