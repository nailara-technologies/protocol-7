# open design questions from the 2026-10-02 session

answer one, and it becomes its own task file. each entry : the question,
where in the repo the answer may already be, what it unblocks.

concrete tasks already written from the same session :
`darksun-mod13-rolling-chunker.md`, `branch-space-trit-address-octant-intent.md`,
`invoke-qwen21-vram-budget-tuning.md`,
`space-deterministic-deconfliction-high-speed-routes.md` [ needs stages ].

## 1. 3+1 frame shift validation

was the expansion logic that detects a shifting window [ binary ticker,
`11001100…` aliasing ] sequence-based or 5-bit-window-based ?
- look : `topic-stream-framing-protocol.md` [ expanding assertion window ],
  `bin/dev/division-13-table` comments, `CONTEXT-TREE-INDEXCUBE-INTEGRATION.md:86`
  [ "5 bits = mod-15 per axis" ], the 2026 chat capture
- unblocks : a stream reader module ; the count \ chain binding rule

## 2. name reuse exclusion in nameserv

does `nameserv` keep a first-seen time per name today ? `nameserv.cmd.set-record`
only sets a zone `serial => time()`.
- look : `src/nameserv.*`, `cfg/zenki/nameserv/`, user records [ `users.*` ]
- decide : which names get the one-epoch exclusion [ nodes, users, zenki,
  zones ] ; local or global epoch
- unblocks : first-seen + exclusion period
  [ `EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md`, "the stream cannot be reversed" ]

## 3. rolling agreement

who proposes the next cycle's agreement, and how is it confirmed ? how
does the cycle length adapt to measured bandwidth \ variance ? what
exactly may the fast revocation path do [ only take away, never grant ] ?
- look : `CHECKSUM-NESTED-ADDRESSING-AND-EPOCH-VALIDITY.md`,
  `base.ntime.*`, `categorical-compartmentalization.yaml` [ triple window ]
- unblocks : the field's self-adjusting agreement ; nested rhythms per ring

## 4. home zenki ring and lambda session setup

which states does the ring's state machine have [ request, granted,
completing, completed, dropped ] ? which messages, which timeouts ? how
does the forward \ reverse key asymmetry enter the handshake ?
- look : `NESTED-CHECKSUM-HARMONIZATION-AND-ADDRESSING.md` §6,
  `DANCING-ZENKI-RHIZOME-STATE.md`,
  `data/md/protocol-7-knowledge/03_FORMATIONS/dancing_kittens_formation.md`
- unblocks : roadmap 7.2 [ dancing zenki formation ] ; route validation

## 5. last-mile veto \ threshold key release

who holds the key shares [ shamir k-of-n, 5 of 7 ] ? how are the 7
last-mile nodes chosen, and how is the target authenticated before release ?
- look : `crypt.C25519.*`, `keys.*`, the AONT \ "key last" capture
  [ chat capture :13321 ]
- unblocks : segment \ group keys with time, zone and epoch conditions

## 6. anti-affinity

what makes two elements "related" or "incompatible" [ same operator,
same key lineage, same latency group, similar behavior ] ? which
measurements decide, and how is a misclassified honest node protected
[ separate only, never exclude ] ?
- unblocks : sybil \ eclipse defense in quorum group assignment

## 7. sybil cost

exactly how does a key's checksum map to a grid position and group ?
needed to calculate the key-grinding cost of landing 3 of 7 in one group.
- look : `topic-checksum-addressing.md`, `branch.space.util.position_for`,
  `nameserv.handler.p7ref_lookup`
- unblocks : the attack cases in the deconfliction simulator

## 8. layered multicast

which encoding carries the resolution layers [ progressive \ wavelet
style ] ; how do layers map to segments, keys and epochs ?
- look : `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md`, `graphics-matrix.*`
- unblocks : the "multicast galaxy scan" stream ; visualization lookahead

#,,,.,,.,,,.,,,,.,,,.,,..,...,.,,,.,,,..,,,,.,..,,...,...,..,,.,,,...,,..,.,.,
#TMVP4N5PWR3DRSI477VX4BVWAPCX6GT4KVKE56TTUSPI3I7QVBHDUNSBAG3WFO6T5BP33BN44WTWM
#\\\|BAOTZYFQ6SU64Z7XPUZ7PWY3TLTW4FUFFMSUN5CW5Q5V3F6WU6X \ / AMOS7 \ YOURUM ::
#\[7]N3SNOYCENZXGKWMJD7IK6LBJDYM6FAS3ENHQZN7RY65UABXKAQBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
