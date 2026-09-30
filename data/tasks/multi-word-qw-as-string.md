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

## done [ 2026-09-30, kimi ]

all fixed as plain single-quoted strings ; single-word idiom qw kept
[ status => qw| revoked |, // qw| ? |, cmd => qw| TRUE |, .. ].

- src/letsencr.cmd.enroll : l.13,14 [ error/usage hash values ],
  l.84 [ || scalar ], l.111 [ || scalar ], l.149,150 [ error/hint hash
  values -- l.150/151 also re-joined to one 78-col line per perltidy ]
- src/letsencr.cmd.revoke : l.13,14, l.72 [ || scalar ], l.107,108
  [ error/hint hash values ]
- src/forensics.handler.rule-proposal : l.33,35,77,177 [ sprintf
  format ], l.106 [ synthesized_by hash value -- shifted every following
  pair before ]
- src/forensics.event.rule-synthesis : l.111 [ sprintf '%s [%s]' -- was
  printing the literal '[%s]' ]
- src/openvas.handler.forensics-reply : l.23,25 [ sprintf format ]

single-word sprintf formats [ qw| %s/%s/rules | .. ] were rewritten too, and
reverted in review [ claude ] -- the single-word form is intended.

verified with bin/format-code -c on all five files :
all 'syntax valid', no 'Useless use of a constant' warnings, no
'would reflow' . remaining multi-word-space qw in these files : none
except the intended ternary idiom [ rule-proposal l.90 :
qw| rejected | : qw| candidate | ] . whole-src notes : the pre-existing
working-tree edits in src/v7-zenki.post_init +
src/v7-zenki.set_up_zenka_dependencies were left untouched [ not part
of this task ].

#,,.,,...,..,,.,,,,..,,..,...,..,,,,.,.,,,,.,,..,,...,...,,,.,...,.,,,,,,,,,,,
#M63M44Z67SI4E35R4T6AAPWTGXFKLP3YKPMSVYPYDABMP3NDCGHCB3VLYF7IZCUIFFZNBAVSIMN4W
#\\\|IKUZWRV5MLVGQP5CQBZODK4YZRXVSD2EJ4EYGYAKGGZGTGEC5QA \ / AMOS7 \ YOURUM ::
#\[7]I44QY7OJGRAJ3OUF464Q7RRG2KHMX37QRU3B7ETS6FYGNFKPNOAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
