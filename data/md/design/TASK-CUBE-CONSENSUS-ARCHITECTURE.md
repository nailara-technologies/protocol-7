## [:< ##

# task cube consensus architecture — actionable summary

session: 2026-06-20. extends `NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md` and
`NRT.NRD.asc` with the missing piece: how participation gets verified and
rewarded without requiring trust.

## the invariant core

a node's task processor is mapped onto one face of a cube; processing
cycles through the six faces in a fixed sequence, driven by a logical
(virtual, calculated) clock rather than wall-clock time — calculated is
more precise than measured. participation in the rotation is what makes
non-participation mathematically pointless, not a policy against it.

## layer 1: clocked rotation as the participation substrate

```
the cube:            six faces, one face = one node's task/tasklist
                     position in the grid IS the participation unit

the clock:           virtual/logical, not physical — counts face
                     advances, not wall-clock ticks
                     more precise because calculated, not measured

advancement rule:    do not advance past a face until the result
                     produced there matches the expected (consensus)
                     result — the clock gates on correctness, not time
```

## layer 2: byzantine consensus over the rotation

```
quorum:              n=7, accept threshold 5 of 7 — standard BFT
                     bound (n >= 3f+1) tolerates f=2 faulty/dishonest
                     participants without losing correctness

a node submitting    excluded from the accepted result this round
a bad result:        its own tasks are stalled (it gated on its own
                     bad output, same rule applies to everyone)
                     network routes around it using nodes with
                     better success statistics

why sabotage         the network already had 5 of 7 correct results;
achieves nothing:    latency did not increase, the attempt did not
                     block anything, and the saboteur's own pending
                     work is what actually stalled — there is no
                     asymmetric cost it can impose. this is BFT's
                     design property, not a moral claim.
```

## layer 3: participation multiplies value, non-participation doesn't save anything

```
participating:       your task matrix is one of six faces; the other
                     five faces' worth of processing now reorganizes
                     and disseminates your contribution, in proximity,
                     generically — a 5x replication multiplier on the
                     value of what you contributed

burst capacity:      guaranteed by participation (replication = future
                     availability); worst case is waiting for the
                     accumulated resource threshold to reach your
                     requirement's amplitude, not being denied outright

non-participating:   your own tasks are already stopped by the gating
                     rule above — there is no resource saved by
                     withholding, only resource never accumulated
```

## layer 4: resource pools, pricing, conversion

```
pools:               dedicated, namespaced by usage category — the
                     contextualization/tree structure IS the namespace
                     of the resource pool (same token framework
                     underneath, NRT.NRD.asc)

pricing:             automatic, because usage categories are already
                     balanced against each other by the pool structure
                     itself — not externally set

conversion latency:  deliberately buffers against fluctuation; the
                     buffering is a dedicated function, not an
                     incidental delay

dissemination        each participant's existing preference profile
template:            IS the template used to route what they receive —
                     precise by construction, not negotiated per
                     transaction

other-currency path: tokens can be acquired with any other blockchain
                     currency and converted to whatever is to be
                     computed, or vice versa — the pools absorb the
                     conversion, buffered as above
```

## the actual incentive (not a belief, a measurement)

```
not:                 a claim that participation is benevolent, to be
                     believed or argued for

instead:             immediate feedback of the result already known to
                     be desirable, faster than deliberation — there is
                     no waiting for confirmation because the logical
                     clock's precision removes the gap deliberation
                     would otherwise fill

consequence:         continued voluntary participation, including
                     connecting more resources to the network, follows
                     from the measured result, not from persuasion
```

## relation to other documents

- `NRT.NRD.asc` — the token's value mechanism (total resources connected
  ÷ total accounts) that this consensus layer makes verifiable without
  trust
- `NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md` — the neutral-substrate and
  transport layers this consensus/scheduling layer sits above
- `data/yaml/reasoning-templates/demystification-through-correspondence.yaml`
  — the discipline this document itself was produced under: every term
  above (BFT quorum, logical clock, replication multiplier, AMM-style
  pool balancing) is a standard, named, already-understood mechanism —
  the cube/face framing is a precise restatement, not new physics

#,,..,.,.,.,.,,..,,..,..,,,.,,.,,,.,,,,..,.,,,..,,...,..,,.,,,..,,..,,...,.,.,
#JVON72IUT5427PSNS2F4RJVUVCY3WX5A2NNZLX73VVNU4VT3MUKBZBESSVENWGZJSF4OUHQY7ZSSW
#\\\|MELFD7Y6K7V2E5JOQVB77ILYEEQBRNO6RDFFJVVRQQDRHPOLDSA \ / AMOS7 \ YOURUM ::
#\[7]NEU3H7KDWDDBRBYTQKJYICHRT5ZATCW4IVDLEN5TGT7GABGRB4BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
