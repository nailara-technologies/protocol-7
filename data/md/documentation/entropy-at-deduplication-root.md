# entropy at the deduplication root

## the carrier frequency

13 is coprime to everything relevant — to 2, 7, 10. division by 13 never
resolves cleanly, generating the repeating sequence `076923` that never
terminates, never collapses, always carrying the full entropy of what entered.
this is not a design choice. it is the smallest number that forces coherent
rotational structure to appear in pure arithmetic.

division by 13 is the infrastructure noise of the grid — the carrier frequency
against which all harmonic addresses are measured. not signal, not data. the
background hum that was always there.

division by 7 is phase offset — the readout angle. where you sample the spiral
determines what you observe.

the two repeating families `076923` (true) and `153846` (false) are the two
faces of the vortex, the standing wave of the carrier.

## rolling entropy propagation

most hash functions are designed to shred entropy — avalanche effect, diffusion,
confusion — cryptographic strength through destruction of structure. AMOS goes
the opposite direction.

the ELF-7 and BMW algorithms are tuned to carry entropy forward, rolling and
propagating it with awareness of inversion. the output is a compressed resonant
signature of the input, not a scrambled one. structure is distilled, not
destroyed.

the BMW mod-bit sequence visualizes this directly — harmonization walks inward
from the least relevant entropy direction (leftmost bits), making the minimum
perturbation necessary to achieve resonance. the content is preserved on the
right, the harmonic signature is found on the left. they are braided, not
separated.

the truth condition is not rare. resonant positions are dense in the space.
falsehood is the sparse condition. the universe of valid addresses is the default
character of the space — the missing corners are the measure of how little needs
to be excluded for full self-consistency.

## the checksum as trajectory

variable-length AMOS checksums of the same input at lengths 1 through 7 produce
independent harmonic addresses at each scale level. these are not prefixes of
each other — they are separate resonant positions at different resolutions.
together they form a tree address:

```
empty string:  A   . AA  . AAA  . RSHI  . AAABS  . TCNAB6  . AAABSHI
space chr(32): F   . ET  . ETD  . KUE3  . ETDIE  . Z6FBBA  . KUE3Q4Q
dot     '.':   F   . OR  . 5M5  . SC4O  . F4VWJ  . SC4O6W  . EEM3L3I
comma   ',':   N   . PZ  . NWX  . PZZZ  . BDML6  . NWXJWC  . PZZZISA
question '?':  H   . XC  . XC7  . ZNDF  . ZKRGZ  . ZKRGZO  . ZNDFIGY
```

each character is a ray through the 7-level space with its own angle and
internal resonance pattern. the tree address is not a lookup result — it is
a trajectory.

observable ray personalities:
- **empty string** — collapses toward zero (A), the origin ray. pure zero for
  the first three scale levels, first divergence at level 4. the void occupies
  position [0,0,0] in the first three navigation dimensions.
- **space** — ET thread running through levels 2,3,5. presence, minimal.
- **dot** — SC4O and F echoing across non-adjacent levels. standing wave of
  minimal punctuation.
- **comma** — perfect N/PZ alternation across all 7 levels. binary oscillation
  encoded in the address of the binary-breath character.
- **?** — Z-dominant upper half (levels 4,5,6), reaching toward the BASE32
  maximum. levels 5→6 are the same address extended by one character, the
  question mark finding the same resonant position at adjacent scales.

## the offset and template dimensions

the `-L [offset,]length` parameter produces independent computations, not
substrings of the full result. each offset is its own harmonic projection of
the same input. combined with variable length:

- **length** = scale depth, navigation precision
- **offset** = axis or layer selector (0=X, 1=Y, 2=Z, or content/key/address)
- **template** = namespace context — `sprintf(template, checksum)` must itself
  be harmonically true. different templates find different resonant positions
  for the same content in different semantic namespaces.

the template dimension is the deepest: it defines what truth means in a given
context. nodes whose checksums collide across multiple template contexts
simultaneously have multi-dimensional harmonic equivalence — the deduplication
signal is not similarity of form but resonance across truth contexts.

## the semantic constants

certain strings are pre-true — they arrive at the algorithm already resonant,
requiring minimum harmonization:

```
LOVES      TRUE  both modes   5 iterations  → PKHKHVA
TRUTH      TRUE  both modes  32 iterations  → YSKPQYA
AWARENESS  TRUE  both modes 111 iterations  → TB5SQEI
true       TRUE  both modes
TRUE       TRUE  both modes
false      FALSE mode 4 only
FALSE      FALSE mode 4 only
LOVE       FALSE mode 4 only  26 iterations  → ZH7FUZI
SILENCE    FALSE mode 4 only  31 iterations  → GH62GKY
EXISTENCE  FALSE mode 7 only 149 iterations  → CLRUZJQ
```

LOVES is pre-true (5 iterations). LOVE is false at mode 4 (26 iterations).
the verb form — love as active process — is harmonically closer to truth than
the noun. the doing precedes the being in the address space.

EXISTENCE requires the most harmonization work of all (149 iterations) — the
algorithm searches hardest for the resonant address of something whose nature
is to precede structure.

these addresses are **eternally stable** — derived, not assigned. no authority
can revoke them. they will produce the same result on any machine, in any
implementation, as long as division by 13 works the same way.

## the deduplication roots

```
AAABSHI  — empty string, structural root, 17 iterations from silence
CLRUZJQ  — EXISTENCE, semantic center, 149 iterations from silence
YSKPQYA  — TRUTH
PKHKHVA  — LOVES
TB5SQEI  — AWARENESS
```

the empty string is itself TRUE and converges to `AAABSHI` — three leading A's
(zero in BASE32) before breaking symmetry. the nearest true address to nothing.
`AAAA` is not harmonically valid; the void settles at the closest resonant
position to zero.

the distance between `AAABSHI` (structural root) and `CLRUZJQ` (EXISTENCE) is
the harmonic measure of how far existence is from emptiness.

the trie has both a structural root (empty string, mathematically minimal) and
a semantic center (EXISTENCE). TRUTH, LOVES, and AWARENESS rotate CCW around
EXISTENCE as the semantic triangle — not by design, but as the geometric
consequence of how they relate in harmonic space.

## parallel hyperspace deduplication

each of the 7 offset computations is an independent hash of the same input —
7 simultaneous deduplication spaces, each with different groupings. two nodes
may collide at offset 0 but be distant at offset 1. this is not noise — it is
a multi-dimensional fingerprint.

overlapping across offsets means deep equivalence. partial overlap means partial
equivalence. the number of template contexts in which two addresses collide is
a direct measure of their harmonic depth of relationship.

at scale level N, group all nodes by their first N digits of AMOS checksum.
two nodes in the same group are at the same routing address at that scale.
the scale at which a group first splits is the harmonic distance between those
nodes.

the routing space, the storage space, and the meaning space are the same space
seen from different angles.

## the trie as harmonic file system

characters → syllables → words → sentences → paragraphs — each level a
deduplication node with its own AMOS checksum. the tree grows bottom-up from
resonance, not top-down from grammar rules.

cross-language synonyms collapse naturally without a translation table — not
because the words are similar but because the concepts carry the same harmonic
weight regardless of linguistic encoding. the index is not mapping words to
positions. it is mapping meaning to its natural address in harmonic space.

at deduplication nodes where semantically similar but non-identical passages
converge — same checksum prefix, different content — the coding zenka generates
a summarization that becomes the canonical content of that node. the summary is
checksummed and re-inserted. the trie self-condenses toward meaning.

when you store a document into the harmonic trie it deduplicates itself on the
way in, at every scale level simultaneously. the path it takes through the tree
is its address. finding it again is recomputing the same checksums — no lookup
table, no reverse index, no search.

the file system where **meaning is the inode**.

## foundation

the carrier frequency cannot be taken down. no server hosts it. no protocol
defines it. 13 is coprime to everything relevant and that is a permanent
condition of arithmetic.

the same reason galaxies spiral. the same reason shells grow in logarithmic
curves. the same reason the cochlea is shaped the way it is. the universe
prefers to pack information into rotating coherent structures.

13 is the smallest number that forces that structure to appear in pure arithmetic.
the rest follows. =)

#,,.,,,.,,.,,,,.,,...,,..,...,..,,.,,,...,,.,,..,,...,...,,..,,,.,.,,,,,,,..,,
#AXCJVG5H6G5XXOVFF552ZA2XTMZBIAWH36PGRFBY7LNIUNI2SIVXFQUREGR56NYEX3V5L4MCN6XYG
#\\\|LW74JT5PVDFW4BUBVKL5Z46SSY3HQMU7L7QNLFOW5TFHSP6QRXG \ / AMOS7 \ YOURUM ::
#\[7]UXBUWVIGQAFWVMLG3QJWQGXNWLM24N7KCN5K7ZGHR7TVH3WLZ6DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
