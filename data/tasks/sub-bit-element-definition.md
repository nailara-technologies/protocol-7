## [:< ##

# name  = task: sub-bit element definition — 3+1 bit stream framing
# descr = implement the minimal self-synchronizing stream framing protocol

## context

the sub-bit layer is the neutral substrate everything else builds on.
it makes storage, transport, and identity structurally untakeable
by ensuring generic elements have no category until full assembly.

the protocol is already fully derived — this task implements it.

## reference

data/ai-mem/claude/topic-stream-framing-protocol.md
data/md/design/NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md (layer 1)

## the protocol — already defined, implement exactly

### frame format

```
3 bits payload  +  1 bit separator  =  4-bit frame

payload  sep   notes
  001     .    normal  (. = 0)
  010     .    normal
  111     .    normal
  000     .    COLLAPSE — do not emit, invert separator
  000     ,    INVERTED separator (, = 1) — field saved
```

inversion rule: when payload = 000, separator inverts from . to ,
receiver knows: , on 000 payload = structural separator, not data
one rule, zero ambiguity

### direction detection (3-bit assertion window)

```
[..,]   direction: forward   (00→1)
[.,.]   direction: symmetric (0→1→0)
[,..]   direction: backward  (1→00)
```

### frame lock (sliding window)

test every 4th bit position for uniformity:
- separator column is always the same value
- payload columns vary (carry information)
- correct offset = the uniform column = LOCK

```
5 bits:  safe detection  (two separator samples)
7 bits:  certainty       (one complete frame + 3 context bits)
```

### 1001 clamp — eternal continuation

1001 = the void (00) clamped between two ones
trailing 1 means: continuation already present in sample
no terminal condition — the clamp IS the continuation signal

## what to implement

### new module: base.stream.frame

```
# name  = base.stream.frame
# descr = 3+1 bit frame encoder — payload + separator with inversion

my $payload = shift;  # 0-7 (3 bits)
my $sep     = 0;      # separator: . (0) default
$sep = 1 if $payload == 0;  # inversion rule: 000 payload → , (1)
return ( $payload << 1 ) | $sep;  # 4-bit frame
```

### new module: base.stream.frame.detect

```
# name  = base.stream.frame.detect
# descr = sliding window frame lock — find separator column offset

my $bits = shift;  # arrayref of bits
# test offsets 0,1,2,3 — which is uniform every 4th position?
# return offset or undef if insufficient data (need >= 5 bits)
```

### new module: base.stream.frame.decode

```
# name  = base.stream.frame.decode
# descr = decode 4-bit frame to payload, handling inversion

my $frame   = shift;
my $payload = $frame >> 1;
my $sep     = $frame & 1;
# if payload == 000 and sep == 1: valid (inverted separator)
# if payload != 000 and sep == 0: valid (normal separator)
# return payload (0-7)
```

## tests to include in task notes

```
encode 0 (000) → 0001  (inverted separator)
encode 1 (001) → 0010  (normal)
encode 7 (111) → 1110  (normal)

stream: 001. 010. 000, 111. → 0010 0100 0001 1110
lock at offset 3: bits 3,7,11,15 = 0,0,1,0 — wait
lock at offset 3 across multiple frames: all separators
```

## RESOLVED — 2026-07-18 (later same day)

**`base.stream.frame.detect.grammar` ships as tier 2.** Two independent
derivation passes (claude-opus, claude-fable — separate dispatches, neither
saw the other's work) converged on the same algorithm and the same proof.
Neither of the harmonic/rotation/matrix leads below turned out to be the
mechanism — they were real, grounded observations, just not the answer to
*this* layer's problem. The actual result:

- **Impossibility proof**: no function of a single candidate column's bits
  — harmonic, checksum, or otherwise — can ever discriminate the separator
  column from a payload column, because both can contain identical bit
  sequences (constructive counterexample: two different streams produce
  the same 4-bit column content in different roles). This is *why* the
  `true_int()` attempt below was never going to work, regardless of which
  harmonic primitive was tried — confirmed by testing the correct, full
  `is_true()` (mode 4 + 7) as a tie-breaker too: still worse than chance.
- **The actual discriminator is the frame grammar itself**: `sep == 1 iff
  payload == 000`. An offset is valid iff every complete frame aligned to
  it decodes under the already-shipped `base.stream.frame.decode`. Lock
  requires exactly one fully-determined, valid offset — ambiguity or
  insufficient data both defer to "sample more," never a guess.
- Verified independently by both passes (2M+ and 2000 randomized streams,
  zero false locks in either) and re-verified a third time directly in
  this session against the worked example, phase-shifted variants,
  multi-collapse-frame streams, and degenerate periodic streams — all
  matching expectations exactly.
- **Where truth validation actually belongs, explained cleanly**: it's
  well-posed only once a *larger constructed value* exists to assert truth
  over (the `create_harmonic_footer`/RECALC regime) — at 2-4 bits there's
  no entropy for the division-by-13 cycle to express anything over, and
  `true_int(n)` was shown to reduce exactly to `TABLE[n mod 13]` (13
  residues, no exceptions across three full periods) — a `0001` collapse
  frame (the most important valid frame) even comes back FALSE while the
  impossible `0000` frame comes back TRUE, confirming truth-over-4-bits is
  actively unrelated to frame validity, not just uncorrelated.
- `base.stream.frame.detect.harmonic` is left exactly as it was — wrong,
  and honestly documented as wrong in its own header — rather than deleted
  or overwritten, per the standing principle this session settled on: a
  superseded attempt stays written down because it may be the right piece
  for a different edge of the layering (and here, concretely, it's the
  worked proof of *why* the grammar approach is the only one that could
  work, not just an alternative to it).

**Third independent convergence**: a delayed Kimi K3 pass (same prompt,
cold-started, never saw the Opus/Fable work) landed on the same
grammar/inversion-consistency algorithm independently. K3 also supplied
the exact algebraic reason behind the "bit-shift left flips truth,
period 12" fact noted earlier: the FALSE set `{1,3,4,9,10,12}` mod 13
is precisely the quadratic residues mod 13, and 2 (the shift base) is a
primitive root mod 13 — so `<<1` flips truth with period 12, while
`<<4` (`2^4 ≡ 3 mod 13`, itself a QR of order 3) preserves it. Verified
correct; grounds an empirical observation in actual number theory
rather than leaving it as a pattern.

**Primary sources, rescued from the ephemeral subagent transcripts**:
the full Opus and Fable derivation sessions (reasoning, test scripts,
proposed code, and the cross-model comparison exchange) are preserved at
`data/md/recovered-subagents/opus-tier2-discriminator.md`,
`data/md/recovered-subagents/opus-FINAL-REPORT.md`,
`data/md/recovered-subagents/fable-tier2-discriminator.md`, and
`data/md/recovered-subagents/fable-FINAL-REPORT.md`. These are the
derivation record beneath the summary above, same principle as keeping
`.harmonic` in place rather than erasing it — read them before
re-deriving anything in this area.

**Leads that turned out not to be the mechanism, but weren't wrong either**:
the rotation-cycle and 35-bit-matrix leads below are real, grounded
observations — just not applicable at this specific layer. Both derivation
passes suggested they likely belong one layer up, at packet-raising, which
remains open. The confirmed third state (`mod 13 == 0`, distinct from both
true and false — see `-vhzd` highlighter note below) and the general
`AMOS7::Assert::Truth` → `mod 13` reduction are genuine additional findings
from this session, independent of the frame-lock resolution itself.

## status — 2026-07-18

**implemented and tested against the spec above**: `base.stream.frame`,
`base.stream.frame.decode` — round-trip correctly for all 8 payload values.

**implemented, correct for what it claims**: `base.stream.frame.detect`
(tier 1, grammar-only strict column uniformity). Verified against the
worked example above — correctly returns `undef` rather than a false
lock, resolving the "wait" this task's own notes flagged: a `000,`
collapse-frame's inverted separator breaks strict uniformity if it lands
inside the sampled window, so a clean lock isn't guaranteed within any
fixed small window under this test alone.

**blocked, not shipped**: `base.stream.frame.detect.harmonic` (tier 2,
meant as a tolerant fallback for exactly that case). Tested against real
`AMOS7::Assert::Truth::true_int()` — not usable as written: `calc_true()`
defaults to TRUE for anything not specifically near the `230769`
false-family, so 3 of 4 candidate offsets (including payload columns)
all assert true. Static per-column truth is the wrong primitive; the
real signal is that truth flips under left-shift with period 12
(`data/md/documentation/harmonic-cycle-correlations.md`), not a fixed
property of one sampled value. Module is left in place with this finding
documented in its own header rather than deleted, per the working
principle: a superseded/non-working attempt stays written down because
it may be exactly the right piece for a different edge of the layering.

**most promising lead for resolving tier 2**: the 4-offset search
`detect()` already performs structurally matches a 4-step -90° CCW
rotation cycle (`data/ai-mem/claude/archive/topic-orbital-data-space-
archive.md`, "the rotating cube eye" — north→west→south→east→north,
"seeing and routing are the same operation"). That doc's "thirteen
cycles = one harmonic period" and the period-12 shift-flip fact above
both keep landing near the same 12/13 relationship without an exact
derivation yet. Also flagged as needing a proper read before continuing:
`data/md/design/TASK-CUBE-CONSENSUS-ARCHITECTURE.md` and the broader
"5 of 7 consensus" material (30+ files reference it) — tier 2 needs the
parent-grid layer-mapping this connects to worked out first, not another
guess at the discriminator in isolation.

**second lead, added same day, possibly the stronger one**: truth
validation (division by 13) may be the mechanism that *raises* larger
packets from these fixed-size small framings, not just a filter on them.
Also: division-by-13 may have a third state beyond true/false —
exact `mod 13 == 0` (no remainder) — as a packet-boundary marker
distinct from either. Division by 7 alongside division by 13 may be
part of a "trunk mapping": not single bitstreams but geometric trunks
of them, multi-bit "beams" along a space axis in a 3D bit matrix. This
connects to something already concretely real, not speculative: the
AMOS checksum itself is a 7-char base32 value = 7×5 = **35 bits = a
5-of-7 matrix** (`data/ai-mem/claude/topic-base32-namespace.md`,
`data/md/design-specs/fractal-data-architecture-holographic-tty.md`:
"the 7x5 bit matrix (35 bits) encodes 5 rows of 7-bit sub-states").
If true, the "5 of 7" / "5th subbit" concept referenced throughout this
task isn't a separate abstraction to design — it's already the shape of
every AMOS checksum in this codebase, and the parent-grid mapping tier 2
needs may already be sitting in plain sight.

**confirmed, not speculative** (`data/md/data-zenka/DATA_ZENKA_HOLOGRAPHIC_
TOPOLOGY.md`): the same 64-bit D13 state's 7-bit decoded-payload field
already has a defined `1` + 6-bit encoding that selects into a **5×7
pixel matrix for UI glyph rendering** — nodes-as-pixels-in-a-bit-matrix
is a real existing encoding, not a new proposal. Same doc: "every 64-bit
value must pass `is_true()` checks... failed values → RECALC (regenerate
with phase shift)" — truth validation as the mechanism that *constructs*
a valid larger value, not a filter that rejects one, the same
iterate-until-true shape as `source.create_harmonic_footer`.

**third-state lead confirmed real** (2026-07-18, via live `-vhzd` highlighter
output on `base.gen_id` division-by-13 streams during a bare `[exit]` run):
exact-zero-remainder (`mod 13 == 0`) renders as its own distinct visual
case — dim, all-zeros tail — separate from both the true-rotation family
(bright green) and the false/shifted-multiple family (dim blue). Not
folded into either. Confirms the "third state beyond true/false" lead
above is a real, already-visually-distinguished case in existing
tooling, not speculation — still unresolved whether/how it maps to a
packet-boundary marker at the framing layer specifically.

**three converging, mutually-reinforcing leads now on record for tier 2**:
(1) the 4-offset search = a 4-step -90° CCW rotation cycle
(rotating-cube-eye doc), (2) the 35-bit = 5×7 AMOS-checksum matrix as
the parent-grid structure itself, (3) this glyph-rendering encoding +
RECALC-on-failure as truth-as-construction rather than truth-as-filter.
Good entry point for a fresh, dedicated derivation pass rather than
further live speculation.

See `data/md/design/ZENKA-IDENTITY-AND-TRUST-TOPOLOGY.md` and
`data/ai-mem/claude/topic-latency-algorithmic-authority-entropy-toll.md`
(ai memory) for the wider identity/topology thread this connects to —
the parent-grid mapping tier 2 needs is the same open work, not a
separate problem.

## signatures note

leave new files clean — signing system adds footer on commit.
do not add stub footer.

## style

$ARG not $_ in loops
<[base.logs]>->( N, fmt, args ) for logging
lowercase comments, [ word ] bracket annotations
no use statements or pragmas in zenka modules

#,,.,,.,.,,..,.,.,...,,,.,..,,,..,.,,,.,,,...,..,,...,...,..,,,,.,.,,,..,,..,,
#7DSQU7ENMK4LVJU277RAK4MHFLJMFGF37YCT5EB2O4XAYOHO4M7QGP4BQAEZ6XGSMUENNPX63KIT2
#\\\|6Q7BY3VKR4RVTHMUOS43GFEX4AGRHWO5GCJEAJRTEGSNKY2WY5H \ / AMOS7 \ YOURUM ::
#\[7]JFKNZRUJEC5QQ4QDMT3OTHSSMZ2BZDOXIFNZV7XEFSHA75MQN6CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
