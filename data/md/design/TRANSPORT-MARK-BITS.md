# transport mark bits, conversion chain, zenki as first users [ 2026-11-17 ]

owner ideas from the session that built the resource ledger [ RESOURCE-ACCOUNTING-UNIFIED.md ],
n7fs format 4 [ N7FS-FORMAT-4.md ] and the substrate synthesis [ SUBSTRATE-SYNTHESIS.md ].
design notes, nothing here is built. the ledger idea set of the same night [ remainders, nested
units, clean units, trunks, shadow accounts, buffer pools, fairness curves ] is already folded into
the ledger doc, sections 15 to 22.

## 1. zenki as the first users

the network needs no outside users to run its economy : our own zenki offer their services to each
other, so priorities, allocations and reservations are balanced by the one zero-sum ledger from the
start, and its visualization shows real efficiency and stability.

- zenki already hold C25519 keys, so each zenka can be a ledger account
- first meters at hand : `ltok` from the inference usage fields, `store` from n7fs receipts [ ledger stage 2 ]
- the ledger then acts as the local resource scheduler

## 2. format conversion as a chain

- each new format reads only the one before it ; a chain of one-step converters reaches any old
  format without the live code growing
- the old reader is needed only AT the format boundary : after `confirm` the old format and its
  reader can be wiped. very old data converts by running a version that still read it, so the chain
  lives in version history -- keep tagged signed versions runnable [ floor perl, deps ]
- n7fs has one use today [ the windows-host files on four holders ] : prefer a CLEAN CUT -- re-issue
  everything in format 4 with new addresses in one rehearsed roll-out. `json3` at most transient,
  `Prior` a one-time converter, nothing left for stage 8 to retire
- conversion and protocol translation are workloads when needed : a dedicated zenka anyone can run
  on their own data [ local first ], or a paid network service. conversion is deterministic, so a
  second host re-running it and comparing checksums is a cheap proof of correct work

## 3. the three spare bits of the AMOS 7 character form

7 base32 characters hold 35 bits, an AMOS checksum uses 32. the 3 spare bits are zero in every
stored checksum : the last character is always `A I Q Y` [ checked since cf9aa909c ].

**rule : the bits are TRANSIENT.** only the transport layer sets and reads them ; they are cleared
before any comparison, key use or storage. stored checksums stay plain.

### 3.1 the octal direction mark

| value | meaning |
|---|---|
| 0 | at rest \ stored \ local [ = the cleared state ] |
| 1 .. 6 | `+x -x +y -y +z -z` |
| 7 | up to the parent scale, one way |

the mark is an absolute "hyperspace lane" direction between cells and layers. the existing relative
route form of `bin/dev/division-13-table` [ `00 <f> <dd> <hhh>` : forward or a 90 deg turn U L R D
relative to the heading = 5 of 6 cube faces, back excluded, plus a 3 bit hop count ] is local
steering inside a cell. lanes carry an item between regions, local steering takes the last steps.

### 3.2 departed by mismatch

setting the mark makes the address stop matching locally : the item counts as DEPARTED at once,
never in two places. clearing it at the destination makes it match there : ARRIVED. an atomic move
by one bit flip. in-flight loss : the marked form still names its route, so a timeout clears it back
at the origin -- the symmetric return logic of shadow accounts.

### 3.3 lease for bids and offers

the same mark as a workload state : set = dedicated to one taker, completed = cleared at the taker,
timed out = flipped back to available for a retry or another taker. one mechanism for move,
reservation and retry ; the ledger's slot hold [ question 18 ] has the same shape. transport is
itself a workload, so moving an item is offer, claim, complete.

### 3.4 chaining and filling

one bit as a continuation flag [ like BER compressed integers ] chains an address to the next one :
multi-hop routes, multi-part items, packed references -- leaving 2 bits for marks. the uses compete
for the same 3 bits, so the meaning is per layer or per transport type.

filling a token : drops are marked as a chain "belongs to the token being filled" ; complete = one
token, clearing the marks releases them back as units. the remainder \ nested-units rule at bit level.

### 3.5 entropy of a full chain

4200 drops x 32 bits = 134400 bits of input for the token's BMW384 address. while the drop addresses
are independent and unpredictable, that far exceeds the output, and it is enough for several
derived values by DOMAIN SEPARATION -- never by cutting one output into parts :

- three axes : `BMW384( "x" . chain )`, `( "y" . chain )`, `( "z" . chain )`
- or six directions : labels `+x` .. `-z` [ 2304 bits ], fitting independent traffic per direction
  [ the link-upgrade lesson : never one key for both directions ]

limit : past ~384 bits of real entropy more length adds no hash strength, and predictable drop
addresses add none.

## 4. open

- which layer may use which of the 3 bits [ mark, continuation, routing digit ]
- timeout lengths for in-flight returns and leases [ align with the ledger frames ]
- a 3D relative route form beside the lane mark
- read `bin/dev/division-13-table` as a source for the transport design pass

#,,.,,.,.,..,,,,.,,,.,,,.,.,.,,,.,,,,,,,.,.,,,..,,...,...,..,,,..,.,.,,,,,,..,
#4N6L35EUSZV4VUFJBDXLXA4MXUJU23TZBWCP4AYB7XLBARKKHONEFPBMF7FFALSKFFORZETR25BDA
#\\\|M6RGXITEQJLXUS2BGEVOVZ6W6VTEUIVVA4CPMSEW6D7LWCCP7GE \ / AMOS7 \ YOURUM ::
#\[7]BBT6RBYW5YM3U5XNGYVQBWOPO4JBNEK4Y7K2MVGJCKCQUSEUUYCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
