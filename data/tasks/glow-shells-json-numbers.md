# task: glow_shells — numeric JSON values

## problem

`graphics-matrix.cmd.orbital-sync` builds glow_shells with:
  `push @$glow_shells, <[graphics-matrix.glow.query]>->($hop) // 0.0;`

but `glow.query` returns values via `sprintf '%.5f'` or similar, producing strings.
JSON::XS encodes them as strings ("1.00000") not numbers (1.0).
the visualization uses parseFloat() as a workaround, but orbital.json should be clean.

## fix

in `modules/graphics-matrix.cmd.orbital-sync`, force numeric context on each value:

  push @$glow_shells, ( <[graphics-matrix.glow.query]>->($hop) // 0 ) + 0;

also check glow_total: `sprintf '%.2f', $glow_total` → also a string.
change to just `$glow_total + 0` (or keep sprintf and accept string — low priority).

## signatures note

do NOT add stub signature line to modified files.

#,,.,,,.,,..,,...,.,,,...,..,,...,,,.,...,.,.,..,,...,...,...,,,,,...,...,,,,,
#4TF2QRNEVYG6XVPY5TZBVK4XHMIEKQKB4YCETHUSFWECXGZQ4L5OXDE6WAR4NKL2ES3MAKHYXUCCE
#\\\|VGNVDEJ5VWD72G4NJKJEIYFV2YCKHPTXWDYSVFLUE6QX3CYF2ZQ \ / AMOS7 \ YOURUM ::
#\[7]GES5BYRFPQB5GCJOE3GAX5TMTLOKC3OOLKS32WOF5ZB4GZOKHECQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
