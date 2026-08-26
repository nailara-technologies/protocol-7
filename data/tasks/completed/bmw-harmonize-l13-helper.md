# task: BMW L13 harmony-loop chokepoint helper

## relation

implements the chokepoint identified in
`data/md/design/BMW-CHECKSUM-TEMPLATE-EXPANSION.md`. prerequisite for
`data/tasks/epoch-bmw-l13-truth-templates.md` [ which is rewrapped
onto this helper ] and for the family-wide tranche
`data/tasks/bmw-truth-template-family.md`.

## the gap

`src/base.chk-sum.bmw.calculate_L13_sum` and
`src/base.chk-sum.bmw.template_L13` carry **identical** L13
harmony-loop bodies. only the per-candidate validator differs:

- `calculate_L13_sum:33-40`  uses `AMOS7::Assert::Truth::is_true`
- `template_L13:43-50`       uses `is_true_with_template`

every future templated L13 variant
[ `truth_template_L13`, AMOS7-consolidated `bmw_template_l13`,
templated exclusion paths ] would have to duplicate the body again.
extract once, route everything through one helper.

## what to ship

```perl
##  src/base.chk-sum.bmw.harmonize_L13  ##

# name  = base.chk-sum.bmw.harmonize_L13
# param = $bmw_512_bin   [ 64-byte binary BMW512 digest ]
# param = $validator     [ CODE ref:
#                          ( $result_str_B32, $bits_num ) -> bool ]
# descr = run the L13 harmony loop with a caller-supplied validator
#         predicate; returns 13-char BASE32 string
```

implementation outline [ not the implementation — judgment for
whoever takes it ]:

- copy the body of `calculate_L13_sum` verbatim into the helper
- replace the validator predicate
  `AMOS7::Assert::Truth::is_true( $result_str_B32, 0, 1 )`
  with `$validator->( $result_str_B32, $bits_num )`
- honour `AMOS7::TEMPLATE::template_timeout()` inside the loop **only
  when** `AMOS7::TEMPLATE::template_count() > 0` [ zero-cost when no
  template is assigned ]; copy the shape from
  `AMOS7::CHKSUM::amos_chksum`'s timeout discipline at
  `CHKSUM.pm:217-238`
- the existing `true_int` floor-harmony assertion on `$bits_num`
  stays inside the helper — it is the digest path's own invariant,
  not the validator's concern
- input guard: same 64-byte length check as `calculate_L13_sum`

after the helper lands, **rewrap** `calculate_L13_sum` and
`template_L13`:

```perl
##  calculate_L13_sum  ##  body becomes:
my $bmw_512_bin = shift // '';
return undef if length $bmw_512_bin != 64;
return <[base.chk-sum.bmw.harmonize_L13]>->(
    $bmw_512_bin,
    sub { AMOS7::Assert::Truth::is_true( $ARG[0], 0, 1 ) }
);
```

```perl
##  template_L13  ##  body becomes:
##  template syntax check + defined-input check stay as-is
my $template = shift;
my $bmw_512_bin = Digest::BMW::bmw_512(@ARG);
return <[base.chk-sum.bmw.harmonize_L13]>->(
    $bmw_512_bin,
    sub { is_true_with_template( $template, $ARG[0], 0, 1 ) }
);
```

## acceptance

- `<[base.chk-sum.bmw.calculate_L13_sum]>->( $digest )` returns
  bit-identical output to today for the same input digest — verify by
  fixture diff against at least 100 randomly-sampled inputs before/
  after the rewrap.
- `<[base.chk-sum.bmw.template_L13]>->( $template, $data )` returns
  bit-identical output to today for the same (template, data) pair —
  same fixture method.
- `<[base.chk-sum.bmw.harmonize_L13]>->(
    $digest, sub { 1 } )`
  short-circuits immediately on the first candidate that satisfies
  `true_int` [ the digest-only-floor case ].
- `<[base.chk-sum.bmw.harmonize_L13]>->(
    $digest, sub { 0 } )` returns undef within
  `AMOS7::TEMPLATE::template_timeout()` rather than spinning forever
  **when** `AMOS7::TEMPLATE::template_count() > 0`; with no template
  assigned the helper's timeout path stays dormant [ same body as
  today's modules, which also do not impose a timeout when no
  template is in play ].

## signatures note

no `#,,..` stubs. do NOT run update-signatures. do NOT modify
subroutine whitelists. lowercase comments, `[ word ]` annotations,
`$ARG` not `$_`.

## harmony checks

```
harmony base.chk-sum.bmw.harmonize_L13
harmony base.chk-sum.bmw.calculate_L13_sum
harmony base.chk-sum.bmw.template_L13
```

#,,.,,...,..,,...,.,.,.,.,,.,,,..,,..,.,.,,,,,..,,...,...,...,..,,.,.,,.,,,,.,
#RTIVBXUVSNLZL3CCJOJNF3ASMLARM64OF3ML2S3KHVMOCBXBZEFS5LEHGQBUVKBNXWPU23JLP4CMK
#\\\|2NJTL6RPFQR6TC2JOBDBCSTDLYWID35RDZL7OQXQLXEU7AXDCPJ \ / AMOS7 \ YOURUM ::
#\[7]XHQFBFETPMTMJTZP4MD6I2JIG4GBPLCNAQQUBV47SRVZ6ROWS6CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
