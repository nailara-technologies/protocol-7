## rank-sequence encoding

*design document : frequency-ranked integer compression for text and token streams*

---

### overview

rank-sequence encoding represents a text document or token stream as a sequence
of compact integers, where each integer is a **frequency rank** : the position
of the token in a corpus-ordered frequency table. the most frequent tokens in
the actual corpus get the smallest IDs; rare tokens get large IDs.

this is a companion format to blue-doc. blue-doc handles graphical documents
[ character glyphs as image regions ]. rank-sequence encoding handles text
documents [ encoded character sequences ]. the two may be combined at the
application layer : a blue-doc layout stream uses rank-sequence-encoded glyph
IDs for its position/identity tuples.

the encoding has two layers :

```
1. rank assignment  : token → integer rank [ corpus frequency table ]
2. integer packing  : integer rank → compact bytes [ BER comp-int ]
[ optionally ]
3. base32 wrapping  : binary bytes → 5-bit text-safe characters
```

---

### rank assignment

the frequency rank of a token is its position in the corpus frequency table,
sorted descending by occurrence count :

```
rank 0  =  most frequent token in corpus
rank 1  =  second most frequent
rank N  =  (N+1)th most frequent
```

the ring-trie in the index zenka IS the rank assignment engine. each trie node
carries a frequency count; the `index.rank` step sorts nodes at each depth by
count and assigns packed rank positions. the rank of a token is read directly
from `<index.packed_rank>` :

```perl
my $rank = unpack( 'N', substr( <index.packed_rank>->{$depth}, $pos * 4, 4 ) );
```

rank assignment is corpus-relative : the same token has a different rank in a
document-local table vs. the global corpus table. for document exchange, sender
and receiver must agree on which table is in use — either a shared global corpus
or a per-document table transmitted in the stream header.

---

### BER compressed integer

once a token has a rank, the rank is encoded as a BER compressed integer —
Perl's `pack 'w'` template, from the ASN.1 Basic Encoding Rules :

```
encoding  :  each byte contributes 7 bits of integer value [ MSB first ]
             bit 7 of each byte [ the high bit ] is a continuation flag :
               1 = more bytes follow
               0 = this is the last byte of this integer
```

examples :

```
rank    0  →  0x00           [ 1 byte  ]
rank    1  →  0x01           [ 1 byte  ]
rank  127  →  0x7F           [ 1 byte  ]  [ largest 1-byte value ]
rank  128  →  0x81 0x00      [ 2 bytes ]  [ smallest 2-byte value ]
rank  255  →  0x81 0x7F      [ 2 bytes ]
rank 16383  →  0xFF 0x7F     [ 2 bytes ]  [ largest 2-byte value ]
rank 16384  →  0x81 0x80 0x00 [ 3 bytes ]
```

Perl encode / decode :

```perl
my $encoded = pack  'w',  $rank;
my $decoded = unpack 'w',  $encoded;

## sequence of ranks : ##
my $stream  = pack  'w*', @ranks;
my @ranks   = unpack 'w*', $stream;
```

the encoding is self-delimiting : a byte with bit 7 clear terminates the
current integer. no length prefix or explicit separator is needed. the byte
stream can be scanned forward-only, and integer boundaries are unambiguous.

---

### base32 transport layer

for text-safe transport [ network protocols, AMOS signatures, file formats that
exclude binary bytes ], the BER binary byte string is wrapped in base32 using
the `encode_b32r` / `decode_b32r` functions from `Crypt::Misc` :

```perl
use Crypt::Misc qw( encode_b32r decode_b32r );

my $b32 = encode_b32r( pack 'w*', @ranks );
my @out = unpack 'w*', decode_b32r( $b32 );
```

base32 uses 5 bits per character. the LCM of 5 and 8 is 40, so a clean block
with no padding is 8 base32 characters = 5 bytes. this aligns with the cubic
grid coordinate system where 2 base32 chars = 1 byte = one cube axis.

the combination of comp-int + base32 is already used in the system for network
time encoding [ `base.ntime.epoch_timestamp` ] :

```perl
## encode epoch as comp-int then base32 ##
return Crypt::Misc::encode_b32r( pack qw| w |, $enc_numerical );

## decode : base32 then comp-int ##
my $decoded = eval { unpack qw| w |, decode_b32r($input) };
```

---

### 5-bit direct packing [ small vocabularies ]

for vocabularies of 32 or fewer tokens, a single base32 character encodes one
token directly, with no BER overhead :

```
vocabulary size  ≤ 32  →  1 base32 char per token   [ 0..31, no continuation ]
vocabulary size  ≤ 1024 →  2 base32 chars per token  [ 10-bit, fixed width ]
```

this applies in the blue-doc layout stream when the document's active glyph
count falls within 32. the most frequent 32 characters — typically 26 letters
plus a small set of punctuation and digits — fit in one character per instance.
for larger glyph sets, comp-int encoding handles the full range.

| glyph count | encoding          | bytes per instance |
|-------------|-------------------|--------------------|
| ≤ 32        | 1 base32 char     | 0.625 bytes        |
| ≤ 128       | 1 BER byte        | 1 byte             |
| ≤ 16383     | 2 BER bytes       | 2 bytes            |
| unlimited   | BER variable      | ceil(log128(N))+1  |

the 32-token boundary is not arbitrary : 5 bits covers exactly one base32
character and exactly one bit-slot in the cubic grid address space.

---

### efficiency model

the compression ratio depends on corpus match — how well the rank table matches
the actual document being encoded :

```
ideal case    : document IS the training corpus
               → all frequencies match → maximum rank concentration at low IDs
               → nearly every token encodes in 1 byte

typical case  : document is drawn from the same domain as the corpus
               → common tokens still rank low → most tokens 1-2 bytes

worst case    : document has no relation to corpus [ random or novel ]
               → ranks uniformly distributed → same byte count as naive binary
```

for language-specific corpora, common words in the target language will occupy
ranks 0..127, encoding in 1 BER byte each. the long tail of rare tokens
(proper nouns, technical terms, hapax legomena) use 2-3 bytes, but their
infrequency means their contribution to total stream size is small.

this mirrors UTF-8's strategy (ASCII in 1 byte, rarer code points in 2-4 bytes)
but with corpus-adaptive rather than standard-defined breakpoints.

---

### stream format

a rank-sequence encoded document stream :

```
[ header ]
  corpus_id   : AMOS7 checksum of the corpus used for rank assignment
  corpus_ver  : version or timestamp of the corpus snapshot
  token_type  : character / word / ngram / glyph-id

[ payload ]
  sequence of BER-encoded rank integers, self-delimited
  [ OR base32 string if text transport required ]

[ optional footer ]
  checksum of the rank-sequence stream [ AMOS7 or BMW ]
```

no token separator is needed in the payload — BER is self-delimiting. the
stream is forward-scannable and appendable without rewriting earlier content.

---

### connection to the ring-trie

the ring-trie in the index zenka provides the rank table directly :

```
trie depth  =  token length [ in characters ]
rank at D   =  position of this N-gram in frequency-sorted order at depth D
```

for character-level encoding (single characters as tokens), depth 1 of the
trie gives all character ranks. for word-level encoding, a word boundary
detector extracts words, looks up each in the trie, and uses the terminal node's
rank.

the index trie is also the natural decoder : given a rank at a depth, look up
`<index.packed_rank>->{$depth}` to retrieve the token. no separate rank table
file is needed if the trie is available.

---

### connection to blue-doc glyph IDs

in the blue-doc layout stream, each position tuple is `(glyph_id, x, y, scale,
color_variant)`. `glyph_id` is the rank of that glyph in the document's glyph
frequency table — most frequent character (typically 'e' or space) gets ID 0.
the full layout stream is then rank-sequence encoded, giving :

- 1 base32 char per common character instance [ ≤32 unique glyphs ]
- 1 BER byte per character instance for larger glyph sets [ up to 128 unique ]
- text-safe output when base32-wrapped

the glyph table header carries the corpus_id pointing to the document's glyph
frequency snapshot, so the stream is self-contained for rendering without
requiring a live trie instance.

---

### open questions and next steps

- **corpus synchronization** : how sender and receiver agree on corpus version;
  delta-sync protocol for corpus updates between encoding sessions
- **mixed depth encoding** : character-level and word-level ranks in the same
  stream; separator token between levels, or explicit depth prefix per token
- **streaming corpus** : rank table evolves as the document is encoded;
  ranks at the start of a long document differ from ranks at the end;
  whether to snapshot once at start or update rank incrementally
- **base32 alignment padding** : when stream length is not a multiple of 5 bytes,
  the final base32 block needs padding; formalise the padding convention
- **format identifier** : file/stream magic bytes for rank-sequence encoded data;
  `.zxrs` extension (zx=xz transport, r=rank, s=sequence) is a candidate
- **implementation** : `base.comp-int.encode_from_buffer` and
  `base.comp-int.decode_to_buffer` are currently stubs — filling these out
  completes the encoding layer

---

### existing work

integer encoding tools — all using base32 as transport layer :

```
bin/comp-int     — BER variable-length integer [ pack 'w' + base32r ]
bin/vax-int      — 32-bit little-endian integer [ pack 'V' + base32r ]
bin/quad-integer — 64-bit integer [ pack 'Q' + base32r ]
```

all three share the same encode / decode structure : `encode_b32r(pack $T, $n)`
and `unpack $T, decode_b32r($b32)`. they differ only in `$T` and the value
range they cover. comp-int is the variable-length member of the family and the
natural choice for rank sequences.

- `modules/base.comp-int.is_valid` — BER integer validation [ pack 'w' ]
- `modules/base.comp-int.encode_from_buffer` — BER encoder [ stub ]
- `modules/base.comp-int.decode_to_buffer` — BER decoder [ stub ]
- `modules/base.ntime.epoch_timestamp` — live usage : comp-int + base32r
- `modules/base.base32.encode` / `modules/base.base32.decode` — base32 layer
- `<index.packed_rank>` — live rank table in index zenka [ pack 'N*' ]
- `data/md/design/BLUE-DOC-FORMAT.md` — glyph ID usage, layout stream

#,,..,,..,.,,,.,,,,.,,,,.,,,.,,.,,..,,...,,..,.,.,...,...,..,,,.,,,..,,,,,,.,,
#7FIZ4KVEG3Y3BO426U5WSCEIGVY3AT5RWSI3IIBXT263UCCIWHGQKJUGXVXBAZLASZGZSUHIXBIC4
#\\\|62IAUG3NTI4FHLMB4RDFRBZI5HIXTXBLZIL5L27K6QXGJJEP5VO \ / AMOS7 \ YOURUM ::
#\[7]MA5CSSGRSSEJHQ6QBYVGN5FWBKRKJHTYLKV6PHBO5GQRV2UNEQBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
