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

## relation

existing dedup modules work on text tokens \ trees [ `index.deduplicate`,
`memory.tree.dedup.exact` ] ; this one is the byte-level boundary layer
below them. average chunk ~13 is small for storage -- larger averages via
a larger modulus or by requiring k consecutive crossings ; measure, do not
assume.

#,,.,,,.,,,,,,,,.,,.,,..,,,..,.,,,.,.,.,.,,,,,..,,...,...,.,.,.,.,.,.,,,.,,.,,
#422BKGRLWWTYWRIGZ7I7HYENNBX42X7J6RKTIJK24HAL7GBDP4V4YTHD7XTXOK67MZ62P5PELERTW
#\\\|TJOSGBHLQEBCV7OJHLLV3U57IEGUGEJ5ZBK4FGF2PONYVMHEZ67 \ / AMOS7 \ YOURUM ::
#\[7]57PZOSBPIKVTE7JLVKRXOD7IDB2OFPD7NL6ZFMZ45ORPT263KIBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
