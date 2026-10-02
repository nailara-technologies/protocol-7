# darksun : mod-13 rolling-window content-defined chunker

brief [ 2026-10-02 ]. first concrete building block of the darksun
deduplication network. background : `topic-harmonic-correlation-ledger.md`
[ "mod-13 zero crossings = content-defined chunking" ].

## idea

cut a stream wherever a rolling window reads `≡ 0 mod 13` [ a "zero
crossing" ] -> packet length = distance to the next crossing, no fixed
clock. because `10⁶ ≡ 1 mod 13`, a 6-digit window updates in one step :

```
v' = 10·v − d_out + d_in   (mod 13)
```

boundaries depend only on local content, so they re-sync by themselves
after any insert \ delete \ shift. prototype result [ 5000 random
digits ] : 369 boundaries, avg chunk ~13.5, a 1-digit insert changed zero
boundaries ; a running-prefix remainder lost all 164 boundaries after the
insert -> always the rolling window, never the prefix.

## work

1. module [ name to decide, e.g. `base.chunk.mod13_rolling` ] : bytes in,
   boundary offsets out. digits are the prototype ; for binary data use
   bytes as base-256 digits : `256³ ≡ 1` mod 7, mod 13 and mod 91 [ checked,
   order 3 for all three ] -> a 3-byte window [ or any multiple of 3 ] keeps
   the outgoing byte at weight 1 : `v' = 256·v − b_out + b_in`
2. parameters : modulus [ 13 default ; 7, 91 = 7×13 for other average
   sizes ], window, min \ max chunk length [ guards against runs ]
3. self-test : random data, insert \ delete \ shift cases, boundaries
   before and after must match outside the edited chunk
4. measure against fixed-size chunking on real project data [ git
   objects, `data/md`, image metadata ] : dedup ratio, chunk size
   distribution, boundary stability across edits
5. compare with an established CDC baseline [ rabin \ gear hash ] on the
   same data -- report honestly where mod-13 wins or loses

## status 2026-10-02

stage 1 landed [ `src/base.chunk.rolling_mod`, test passes ]. stages 4-5
first run via `bin/dev/chunk-bench` [ column `stored%` = unique bytes total, lower = better ] :

- edit stability : mod-13 and gear tie at ~99.9 % ; fixed-size 13-50 %
- dedup : gear better on every corpus [ src : 50.6 % vs 23.4 % stored at
  avg ~5 ; md : 75.9 % vs 67.1 % ] -> mod-13 does NOT yet beat the known
  improvement
- text skews mod-13 averages [ 5-8 bytes instead of 13 ] ; binary matches
  theory
- throughput : gear ~3x faster [ both pure perl ]

the run is not conclusive : chunks of 5-90 bytes are far below real dedup
sizes [ 2-8 KB, the index alone would dominate ] and the 3-byte window is
much shorter than established cdc windows [ 32-64 bytes ] -> likely cause
of the text skew. next : fair rerun at ~4 KB target, window a multiple of
the order of 256 for the chosen modulus, same corpora and edit script.

## fair rerun at ~4 KB [ 2026-10-02, `bin/dev/chunk-bench -t 4k` ]

modulus 4095 = 2^12 − 1 = 3²·5·7·13 ; 256³ ≡ 1 mod 4095 -> weight 1 for
any window that is a multiple of 3 ; windows 48 and 63, vs gear 12-bit
mask and fixed 4096, cdc guards 1–16 KB for both as a variant. real dedup
case : src/ at HEAD~200 + HEAD pooled [ 26.5 MB ] :

```
A mod4095/48   stored 58.87 %   stable 89.88 %   2.9 MB/s
C gear-4096    stored 59.32 %   stable 91.75 %   5.9 MB/s
B fixed-4096   stored 99.82 %   stable  0.36 %
```

result : at realistic sizes the mod-4095 family is **on par with gear** —
all cdc variants within 0.45 points stored, mod marginally better on
stored, gear marginally better on stability and ~2x faster in pure perl.
single-version corpora are ~100 % stored for everything [ no internal
duplicates at 4 KB ] -> noise. so it ties the known improvement, it does
not beat it on raw efficiency ; any advantage would have to come from
structure [ boundaries in the 7 \ 13 family aligning with the rest of the
addressing ], which this benchmark does not measure. unguarded runs make
1-byte chunks -> always use min \ max guards.

## relation

existing dedup modules work on text tokens \ trees [ `index.deduplicate`,
`memory.tree.dedup.exact` ] ; this one is the byte-level boundary layer
below them. average chunk ~13 is small for storage -- larger averages via
a larger modulus or by requiring k consecutive crossings ; measure, do not
assume.

#,,..,,.,,,.,,,,.,,.,,,,,,.,,,,,.,,,.,..,,.,,,..,,...,...,,,.,..,,.,.,,..,...,
#H7YF2VDWIZHUY3L525GRDAY5WAH7JTCNSME7YW7VP4C6XDJ65YRV6JZWYZZHURMJJYHRUVMJWYQQC
#\\\|UFYPEJWSBL4CMWSZS32IEKZJJP3WAEQC3ETI4OQ42C65VCPIVV3 \ / AMOS7 \ YOURUM ::
#\[7]GX4TUWZMVKJGPM3MKQNZMAZ45PCIXWOAYXKW77ENEQYCTPBLHQBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
