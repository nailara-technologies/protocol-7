# task: glow_shells — numeric JSON values

## problem

`graphics-matrix.cmd.orbital-sync` builds glow_shells with:
  `push @$glow_shells, <[graphics-matrix.glow.query]>->($hop) // 0.0;`

but `glow.query` returns values via `sprintf '%.5f'` or similar, producing strings.
JSON::XS encodes them as strings ("1.00000") not numbers (1.0).
the visualization uses parseFloat() as a workaround, but orbital.json should be clean.

## fix

in `src/graphics-matrix.cmd.orbital-sync`, force numeric context on each value:

  push @$glow_shells, ( <[graphics-matrix.glow.query]>->($hop) // 0 ) + 0;

also check glow_total: `sprintf '%.2f', $glow_total` → also a string.
change to just `$glow_total + 0` (or keep sprintf and accept string — low priority).

## signatures note

do NOT add stub signature line to modified files.

#,,..,...,,,.,.,.,,,.,..,,,,,,..,,,,,,,,,,,,,,..,,...,...,,,,,.,.,,..,..,,,,.,
#Q2COKQQOWZFBZEHSF3N5K3NBMWS7KWJJ4VQGN5F2D5OJLXD764JQRKERAKBGCN2FYIXQRGLJ5IOMS
#\\\|AMFD5DDMTTPMKJMUKNOBPYF3VNCPJ3FDKQNAKUUQOJDU2L6QMUN \ / AMOS7 \ YOURUM ::
#\[7]BUIWL42KSGQD7B32ANBGTIOHOVQWLDDF5IW5NFAY5FAXZR7GTQBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
