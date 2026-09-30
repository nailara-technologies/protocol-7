# multi-word qw| .. | used as a string [ letsencr, forensics, openvas .. ]

found 2026-09-30 by the new `use warnings` in `bin/format-code -c`
[ "Useless use of a constant ('unknown') in void context" ].

## the bug

`qw| a b c |` is a LIST of words, not a string :
- scalar context [ `$x || qw| unknown install error |` ] : only the LAST
  word -> the error text reads 'error'
- inside a hash \ list [ `error => qw| domain parameter required |,` ] :
  three elements -> every following key \ value pair SHIFTS
- `sprintf qw| error : %s |, ..` : the format is the first word 'error'
single-word `qw| true |` is fine [ the project's idiom ].

## where [ at least ]

src/letsencr.cmd.enroll [ l.13, 14, 84, 111, 149, 151 ],
src/letsencr.cmd.revoke [ l.13, 14, 72, 107, 109 ],
src/forensics.handler.rule-proposal [ l.33, 35, 45, 67, 96, 106 ],
src/forensics.event.rule-synthesis [ l.36, 38 .. ],
src/openvas.handler.forensics-reply [ l.23, 25 ].
search all of src/ : a qw| .. | with a space inside the bars that is NOT a
real word list [ foreach \ map \ grep \ push \ ( qw| a b | ) \ @x = qw| .. | ]

## fix

a plain string : `'unknown install error'`, `sprintf '%s/%s/rules'`.
verify each file with `bin/format-code -c` [ checks use warnings now ].
the whole-src check : only download.init_code [ checker artifact ] and
weather.cmd.current:9 [ comma in qw, harmless ] may remain.

#,,,.,,.,,,..,.,,,,.,,,..,,,,,,..,,.,,...,,..,..,,...,...,,.,,,,.,,.,,.,,,...,
#FCML4HNXBPEZIHO5J76TJ5KY62LP5HPHEOJWY5CBCW3FB6JXUB2FSK77RHZB6AYI2DFYSBHQWL6Q4
#\\\|PCXX4APTDWZI7FOO4BF4GUGGMH2KTF6JRGT4JDX5WQTU2I5CGFH \ / AMOS7 \ YOURUM ::
#\[7]LRGSG2T2GHF6HLL26RWMGQB7KKUXVTDAIDFK2QIZKG2TJ3XJWMAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
