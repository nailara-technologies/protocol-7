# p7 syntax translator : quote-like operators inside data keys

found by kimi [ 2026-09-30, legacy strict fixes ]. fixed 5b46b49ef [ both
copies, `inside_key_chain` ; ticker sugar restored ].

## the bug

the p7 syntax translator reads a data key segment that is a perl quote-like
operator name followed by a non-word character as that operator :
`<ticker.font.y-offset>` -- the `y` at a word boundary followed by `-` [ a
legal delimiter ] starts `y///`. with a second `-` later in the line [ e.g.
`$offset_params->{` ] the rest of the line is swallowed as the quote body,
and the truncated `<ticker.font.` no longer translates. without a second
delimiter the key silently stays untranslated : valid perl, wrong meaning at
runtime.

affected : any key segment `y`, `q`, `qq`, `qw`, `qr`, `qx`, `m`, `s`, `tr`
followed by a non-word character.

## where

- `data/lib-path/pm/AMOS7/Protocol/P7Syntax.pm` : `match_qlike_op` [ l.145 ],
  called at l.460
- `bin/Protocol-7` : lockstep inline copy, `match_qlike_op` [ l.1636 ], called
  at l.1952
- both must change the same way [ bin/format-code uses the translator too ]

## fix direction

`match_qlike_op` must not fire when the keyword is a segment of a data key
chain : preceded by `.` inside `<..>` [ or directly after `<` ]. check what
the call site at l.460 \ l.1952 already knows about being inside a `<..>`
key before adding a look-behind.

## known uses

- `src/ticker.load_font_offsets_table` : worked around 2026-09-30 [ direct
  `$data{'ticker'}{'font'}{'y-offset'}`, comment in the file ]
- `src/ticker.callback.draw` l.164 \ l.167 : `<ticker.font.y-offset>` still
  in the sugar form -- compiles, wrong at runtime
- search for more : `grep -rnE '<[a-z0-9_.-]*\.(y|q|qq|qw|qr|qx|m|s|tr)[^a-z0-9_]' src/`

## verify

- a test module with `<a.y-b>`, `<a.s-t>`, `<a.m-n> + <b.q-r>` in one line
  translates to `$data{..}` for every key
- `bin/format-code -c` on all of src/ reports no new errors
- after the fix, `ticker.load_font_offsets_table` may go back to the sugar form

#,,,.,,.,,,,.,..,,..,,.,,,.,.,.,.,,.,,.,.,,..,..,,...,...,,,,,.,,,,,.,..,,,.,,
#TO7TJS7BJLGFC5NJPEMG2CLVDMUTEBEVNRKTBQXCVRY4DFSEYNOQY6TXF5NYF3K5OGNEXWOJ5W4Q2
#\\\|QCGQ5VPWWLBG2OYJJD3KLYTQSNICYIL3X6IPQ75RZDF5UKMVEKA \ / AMOS7 \ YOURUM ::
#\[7]KXEAXKLD4PEYQBEP6QJLDNELSPMXGENU42LDMNJ236XYX3BWCOCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
