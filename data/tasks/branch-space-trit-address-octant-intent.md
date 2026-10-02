# branch.space : trit address roles and octant intent

brief [ 2026-10-02 ]. design : `data/md/design/SPACE-ENGINE-MASTER.md`,
space.grid-* [ "address = role", "the inverted 3D plus — one shape, three
roles", `space.grid.intent` ]. small pure calc functions, fits next to the
existing `branch.space.*` modules [ `branch.space.shell`, `.rank`,
`.util.position_for` ].

## functions

1. **cell role** : `{ z, y, x }` with values `−1 0 +1` -> role by number of
   nonzero coordinates : 0 center, 1 face [ plus arm ], 2 edge, 3 corner
   [ inverted plus ]. for larger offsets : role relative to the nearest
   3×3×3 block center
2. **octant bits** : sign triple -> 3 bits [ 000–111 ] and back ; partial
   intent : 1, 2 or 3 axes lit = axis, plane diagonal, spatial diagonal
3. **intent frame** : octant bits as one 3+1 stream frame [ see
   `topic-stream-framing-protocol` : payload `000` takes the inverted
   separator ]
4. **polarity** : checkerboard parity `(x+y+z) mod 2` -> adjacent cells
   always opposite ; used later by the deconfliction rule
5. **hop ball size** : `N(h) = (2h+1)(2h²+2h+3)/3` [ N(1)=7, N(50)=171801 ]
   for honest search-coverage bounds

## tests

- all 27 cells of a 3×3×3 block : counts 1 \ 6 \ 12 \ 8
- octant bits round-trip for all 8 corners
- parity differs for every face neighbor pair
- N(h) against brute force for h = 0..20

## then

`space.grid.intent` command once a space zenka exists [ the design lists
it as a proposal ; check `cfg/zenki/` before creating anything ].

#,,,,,,.,,...,.,.,,,.,,,,,,,.,.,.,,..,.,,,...,..,,...,...,..,,,,.,,.,,,..,...,
#SG635MJRX3PZGFJXBEBM4OJYFEFJEKHW3Q5L27PPFNXETAJO4QZZE4GAYQ5SJIC5RQBIRKPELL7WS
#\\\|EEEZHA5VZRGL4LVEU6XB5TR3PUVJ3QWHBTZQUWOCUMOLXPZ4DRH \ / AMOS7 \ YOURUM ::
#\[7]OT6WIWDBGPDCGHF74CB5EVQUS7MF4ILNE5PO3A4XPJ3EOTGL7QAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
