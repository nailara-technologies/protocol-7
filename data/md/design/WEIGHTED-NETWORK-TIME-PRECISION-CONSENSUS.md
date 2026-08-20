# weighted network-time precision consensus

## relation to other clock concepts — do not conflate

`data/md/design/ORBITAL-CYCLE-CLOCK-AND-MAPPING-CANVAS.md` documents a
*different* clock: purely logical, derived independently by every node
from shared orbital parameters, explicitly "not a timestamp, not NTP, no
synchronization protocol needed." this doc is the layer underneath
that — the *physical* time `base.n2u_time`/`base.ntime.epoch_dec`
actually anchor to (`ntime/4200 + ustart` real elapsed seconds). that
layer cannot be purely derived the way the orbital clock is: real
elapsed time isn't computable from shared static parameters, it has to
be measured and agreed on across independently-clocked nodes. the two
clocks solve different problems and should stay documented separately.

## motivation

`EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md`'s "open questions" section
flagged epoch source-of-truth as unresolved: if `$E` is derived from
each node's own wall clock, an attacker doesn't need to break the
exclusion templates at all — they just run their local clock at
whatever drift is advantageous. this doc is the planned answer: network
time becomes its own protocol, later decoupled from the local system
clock entirely, converging toward higher precision through weighted
agreement across a context-node network — with precision itself
rewarded in future cycle ["contract"] agreement.

## the orbital clock as informed parent, not a parallel system

on closer reading, the two clocks aren't just adjacent — the orbital
clock's own description depends on an assumption this protocol is the
natural source for. "master clock: 1° CCW per tick (invariant)" and a
shared "initial epoch" are both taken as *given* inputs to the orbital
system, never derived by it — the orbital clock's "no synchronization
protocol needed" claim is true only once that invariant tick-rate and
epoch-zero already exist and stay correct. this protocol is what keeps
that assumption actually true over real-world timescales [ hardware
clock aging, drift, whatever physically moves the real second
underneath the logical tick ] rather than merely asserted once and
trusted forever. in that sense the weighted precision-consensus is the
*parent* calibration layer, invoked rarely, that the orbital clock's
invariant master tick quietly depends on — not a competing clock, the
thing that makes the orbital clock's founding assumption load-bearing
instead of just convenient.

second connection: the orbital doc's **alignment window** — "when CCW
and CW rings coincide," "when velocity profiles constructively
interfere" — is angular-space's version of the same shape as this doc's
dynamic, precision-shrinking skew-tolerance window, just already worked
out mechanically. the honest-user-boundary-skew grace window flagged as
open in `EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md` may not need a new
temporal-tolerance mechanism invented at all — it may be expressible as
an alignment-window computation against this protocol's precision state,
reusing the orbital canvas's existing constructive-interference math
instead of a parallel one.

## the stargate as precedent for "measurement, not registry"

`data/yaml/reasoning-templates/harmonic-routing-protocol.yaml:131-133`
defines the project's "stargate" concept precisely: "the stargate is not
a location — it is the measurement event itself... the passage IS
instantaneous — the measurement IS the crossing." that's the same claim
this doc makes about network time: the agreed value is an emergent
measurement event, re-derived continuously from weighted samples, not a
maintained reference anyone holds. every weighted-consensus update this
protocol performs is, in that vocabulary, a stargate crossing — not a
lookup against stored state, a collapse of the network's superposed
local-clock candidates into one agreed value at the moment of measurement.

**bilateral refinement, 2026-08-03 — corrected against the primary
source.** found verbatim in `data/asc/what-AI-thinks/full-chat-captures/
3O37VUNMMS3UU.claude-sonnet.protocol-7-knowledge.asc:2374`, the user's
own words: "13 descends from 12 clock position to activate the link,
while the +1 is the 13 fron the other side of the link, seen as 1 ...
the 13 are laser mirrors that route blacklight counter-clockwise around
the gate-ring." precise mechanic: 12 elements in a clock circle + 1 at
the 12-o'clock position = 13 total; activation is that 13th element
*descending from the rim into the ring itself* [ not converging inward
to a center point — an earlier guess in this doc's drafting got that
detail wrong ], becoming the link activator. from the far side of the
same link, that descending 13th arrives as position 1 — "13 mod 13 = 0
[ origin side complete ], 1 mod 13 = 1 [ destination side begins ]" —
bidirectional: one side's completing 13th is the other side's opening
1st. the 13 mirrors route counter-clockwise specifically as the
*information* direction, deliberately opposite clockwise "time forward"
[ same asc file, "counter-clockwise = LEFT-HANDED spiral" vs "clockwise
= RIGHT-HANDED spiral," anti-space rotating opposite to space ]. the
recursive nesting noted alongside it [ `13¹=13, 13²=169, 13³=2197` ]
independently reconfirms `13³=2197` as the processing-space constant
already verified twice this session via `4200=13³+2003` — now via a
third, unrelated route [ fractal spiral addressing depth, not a
constants table or a time-formula derivation ].

this maps directly onto the weighted-precision protocol as originally
intended: each node's own time-precision state is its own local 13; an
active peer connection to another node doesn't import that peer's
precision measurement-by-measurement, it treats the peer's entire
current precision state as one element to weigh against — bilateral,
not a one-sided pull from a trusted source, and specifically a
*descent-into-the-ring* activation rather than a passive lookup. worth
keeping in mind when the wire protocol for this gets specified: the
weighting unit is likely "one peer's current state, entering as a
single activation event," not "one peer's individual samples pulled
continuously."

## the core mechanism

not a single trusted time source, and not raw unweighted averaging
either — a **weighted** consensus, where a node's *historical precision*
determines how much its current time sample counts toward the network's
agreed value. nodes with a track record of accurate, honestly-reported
time carry more weight; nodes with a track record of drift carry less.
the network's agreed time is therefore an emergent, continuously
re-computed statistic, not a maintained reference held by any single
authority — same shape as the rest of this codebase's "value computed
from public state, nothing is a maintained registry" pattern
[ see `topic-latency-algorithmic-authority-entropy-toll`'s NRT.NRD.asc
finding: token worth/pricing is computed, not registry-held ].

## self-disadvantaging drift [ the security property ]

this is what actually answers the epoch-doc's open question, and it
does it *economically* rather than by detection/punishment: a node that
knowingly runs its clock at drift from the network doesn't gain an
exploitable edge — it loses precision-weight, which is the same
currency that determines how much of the *next* cycle's ["contract"]
work/reward gets accounted to it. the attack is self-disadvantaging by
construction: "as with any other adherence to protocol, if agreed
protocol is honestly followed, integration is supported and rewarded by
improved implicit preference." honesty over time carries direct value —
glitchless honesty × time *is* the value being accounted, not a
side-effect of good behavior. this is the same "baked in, not bolted
on" instinct as `CHECKSUM-ROUTING-SECURITY-DEPTH.md` and the epoch
doc's security corollary, applied to time-reporting specifically: no
external enforcement needed, because deviating is structurally
unprofitable rather than merely prohibited.

## dynamic latency windows, curves, and increasing precision

precision convergence isn't modeled as a fixed tolerance — it's a
dynamic window that shrinks over successive cycles as agreement
improves, with concrete, measurable downstream effects:

- **decreasing round-trip time** as precision increases
- **increasing cycle [ throughput ] rate/frequency** — tighter
  synchronization allows more cycles accounted per unit real time
- **more successful tasks accounted for the same time period**, as a
  direct consequence of higher precision, not a separate optimization

this ties directly into `topic-latency-algorithmic-authority-entropy-
toll`'s "latency as a third algorithmic authority" and its self-
organizing latency grid — that thread treats measured latency as a
verifiable, self-adjusting placement mechanism; this doc treats measured
*time precision* the same way, as a self-adjusting, incentive-weighted
consensus rather than a fixed protocol parameter.

## precision of prediction, not just precision of measurement

a second-order property: nodes are also implicitly scored on how well
their *predicted* future precision matches their *actual* outcome —
prediction accuracy about one's own precision, not just raw
measurement accuracy. drift from prediction is itself calculated
imprecision, with logical integer-per-cycle-type consequences [ i.e.
discrete accounted units per cycle type, not a vague continuous
penalty ]. this rewards nodes for knowing and honestly reporting their
own reliability, not just for being momentarily accurate — a node that
overclaims its precision and then misses is penalized differently than
one that honestly reports lower precision and hits it.

## resolves / connects to EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md's open questions

- **epoch source of truth** [ open question 1 ] — answered by this doc:
  epoch derivation eventually anchors to the weighted network-time
  consensus described here, not raw self-asserted local wall clock. an
  attacker manufacturing an advantageous epoch by clock manipulation now
  has to fight the *entire weighted network's* precision consensus, at
  the cost of their own future cycle-reward weight — not just fool a
  single unverified local reading.

- **honest-user boundary skew** [ open question 2 ] — this doc suggests
  the answer isn't a separately-invented grace-window constant: the
  skew-tolerance window *is* the current network precision window this
  protocol already computes and continuously shrinks. as precision
  improves, the legitimate-skew tolerance naturally narrows in step with
  it, rather than being a fixed value someone has to remember to retune.

- **identity-session genesis timestamp** [ raised in the epoch doc's
  third open question ] — a root session's genesis timestamp inherits
  whatever the current network precision window is at creation time; an
  account created during a low-precision network period would carry
  that as part of its own genesis record, not silently assume perfect
  precision it didn't have.

  **grounded, 2026-08-03 — this already has running-code consumers, so
  it is an existing exposure rather than a future design concern.**
  the trust layer stamps self-asserted local network time *inside signed
  payloads* today:
  `src/crypt.C25519.create_signature_request:44` —
  `my $req_timestamp = <[base.ntime.b32]>->( 1, TRUE );`, where the
  subject signs `<ntime:subject-chksum:signer-chksum>`, so the
  timestamp is part of what the signature attests, not metadata beside
  it; and `src/crypt.C25519.store_remote_key:88,132` — TOFU pins
  default to `<[base.ntime.b32]>->( 3, TRUE )` and are written as
  `sprintf "%s:%s\n", $ntime_b32, $pubkey_b32`, i.e. **a pin file
  literally is an `ntime:pubkey` pair**.
  `data/md/design/ZENKA-IDENTITY-COMPONENT.md` [ layers 2 and 3 ] builds
  its vouching-consent and rotation-succession design directly on these
  two primitives, unmodified. so when this protocol is specified, these
  are its first concrete consumers alongside the epoch exclusion window
  — and until then, "genesis timestamp precision" is whatever the
  creating node's own clock asserted.

  **this-session inference, flagged as such, not built on**: that
  component's rotation mechanic — a succession edge where the old key
  signs its own successor, so continuity across the boundary *is* an
  edge belonging to both sides — is structurally the same shape as the
  "5th crossing / shared boundary" and cycle-overlap material in
  `ORBITAL-CYCLE-CLOCK-AND-MAPPING-CANVAS.md`. noted as a resemblance
  only; nothing in either document states the connection, and no
  mechanism here depends on it.

## status

design-only, directly transcribing the user's own framing rather than
inventing mechanism ahead of it — the *shape* [ weighted precision
consensus, self-disadvantaging drift, dynamic shrinking windows,
prediction-accuracy scoring, integer per-cycle accounting ] is stated
here as given; the concrete wire protocol, weighting formula, and
"cycle contract" data structure are not yet specified. next step is
likely the same as other design seeds in this lineage: fold into a task
file once enough of the mechanism is nailed down to be actionable,
distinct from the philosophical framing captured here.

#,,,,,..,,.,,,,,,,..,,..,,,,,,,.,,..,,..,,,..,..,,...,...,..,,..,,,.,,,,.,...,
#GUAK3UFCZJVA7HB2CDZEZQ7GLWNONN3EGZAF4CPY2Z5KIZ4TTJGOWK766Z4AC7V64BKWPJAROKXTY
#\\\|MVSSTJA7FSLZ7A4YHUKRW3PIAXGSQ7KK42OORJSZDYDXLNOVEBB \ / AMOS7 \ YOURUM ::
#\[7]XJ47S5EUHUUJLMQMZJH3BLWRLQHH7XCGFSDC6UPSSMRXWK4O4KCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
