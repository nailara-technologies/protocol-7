## [:< ##

# ring-trie geometry

a self-organizing prefix tree where each ring is exactly one character wide,
children are frequency-ranked, and the structure expands outward without bound.

---

## the core invariant

each node in the trie is an array:

```
index 0     : '.'  if this path is a complete token — absent otherwise
index 1..N  : children, ordered by descending corpus frequency
```

the `.` at index 0 is a presence flag, not a value. its position is its meaning.
a node with only `['.']` is a leaf. a node with `['.', c1, c2, ...]` is both a
complete token and a branching point. a node without `.` at index 0 is a pure
interior prefix — exists only as a path, not a token.

---

## rings

each ring corresponds to one character of depth:

```
ring 0 : single characters     — the universal entry layer
ring 1 : 2-character sequences
ring 2 : 3-character sequences
...
ring N : (N+1)-character sequences
```

every word is a radial path from ring 0 inward outward. `'love'` is four steps:

```
ring 0 : 'l'    address = freq rank of 'l' among all single chars
ring 1 : 'lo'   address = freq rank of 'lo' among all 2-char seqs
ring 2 : 'lov'  address = freq rank of 'lov' among all 3-char seqs
ring 3 : 'love' address = freq rank of 'love' among all 4-char seqs
```

the numerical address of a sequence is its path as an array of ring-level ranks.
encoding length reflects rarity — common paths have small addresses, rare paths
have larger ones. compression and addressing are the same operation.

---

## memory geometry

the key saving: each character is stored exactly once at its ring depth, shared
across all sequences passing through it. the overlap IS the structure.

current hash-based approach stores `'love'` four times as separate keys:
`'l'`, `'lo'`, `'lov'`, `'love'`. the ring trie stores each exactly once.

---

## outward expansion

rings make more space outward naturally:

```
ring 0 :   ~100-200 tokens    (unique chars in corpus)
ring 1 :   ~thousands         (2-char sequences)
ring 2 :   ~tens of thousands (rising density)
ring 3 :   peak density       (word-length sequences)
ring 4+:   gradual falloff    (longer sequences, rarer)
ring 7+:   sparse             (only high-frequency phrases reach here)
```

outer rings are mostly empty — the corpus simply does not reach there. but the
space exists freely. a new document can populate ring 20 without touching ring 3.
the inner geometry is never restructured by outer additions.

there is no encoded upper bound. the tree has no outer wall. infinite word length
is structurally free — only the corpus horizon limits depth.

---

## utf-8 safety

each ring slot holds exactly one character (one unicode codepoint) or the `.`
sentinel. no length ambiguity. a multi-byte utf-8 sequence is a single scalar
value — it occupies one slot, carries one ring-0 address. the structure is
codepoint-native, not byte-native.

---

## the sentinel as root

`.` at index 0 maps to the `''` root concept — the common root of all strings.
arriving at `.` is arriving at the invariant center. every leaf is a small
recurrence of the root structure at its ring depth. the tree folds into itself.

see also: ZERO-AS-ETERNAL-TREE.md — the 0 as current position pointer,
cross-scale invariant, common root equivalence.

---

## applications

this geometry applies wherever a token space needs:

- shared prefix compression with no restructuring cost
- open-ended depth without upper bound
- self-organizing address space from corpus statistics
- frequency as the natural ranking (no external wordlist)
- numerical path encoding for any downstream use (checksums, routing, search)

the index zenka is the first implementation. the pattern is generic.

#,,,.,.,,,..,,.,.,.,,,,,,,,,.,,,.,,.,,,,.,,,,,..,,...,...,...,,,,,,.,,.,.,,,,,
#ZCVOPS3JB5FIC4OY3FLRXPYLEWOGE23IAREFPCB3DKYC4FSYWHOVSQL4YA3EN24PAD2LYTDOLOMXK
#\\\|56IPRBJDBXQ2ZRLJOTV4XGFUQHT2UNUZRUQMT6YCTOSHVTS3Y62 \ / AMOS7 \ YOURUM ::
#\[7]JR7UE4V4JN2J4S5JYFBJPWJTND64353RAJYKHAYD5SRLQBBXMUAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
