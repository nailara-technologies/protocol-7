# task: BMW-L13 truth-template + exclusion-hashref parity

## relation

implements upstream change #1 of
`data/md/design/EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md`.

**scope-update [ 2026-06-10 ]:** this task is **not superseded** — its
acceptance criteria remain authoritative — but its implementation is
now layered on `data/tasks/bmw-harmonize-l13-helper.md` [ the L13
harmony-loop chokepoint identified in
`data/md/design/BMW-CHECKSUM-TEMPLATE-EXPANSION.md` ]. ship the
chokepoint helper first; this task then collapses to: assign templates
via `AMOS7::TEMPLATE::assign_truth_templates`, build a validator that
calls `template_is_true` + `true_int`, delegate to
`<[base.chk-sum.bmw.harmonize_L13]>`, and `reset_truth_templates` on
exit. timeout discipline lives in the helper, not this wrapper.

## the gap [ already characterized in the design doc ]

`AMOS7::CHKSUM::amos_chksum` + `amos_template_chksum` accept
`ARRAY|CODE|Regexp|sprintf` templates and integrate with
`AMOS7::TEMPLATE`'s exclusive-type callback machinery. the BMW-L13
family currently does not:

- `src/base.chk-sum.bmw.calculate_L13_sum` — zero template support
- `src/base.chk-sum.bmw.template_L13` — single template via
  `is_true_with_template`; no ARRAY/CODE/Regexp; no exclusion path

## what to ship

a new module `src/base.chk-sum.bmw.truth_template_L13` parallel in
contract to `AMOS7::CHKSUM::amos_template_chksum`:

```perl
## [:< ##

# name  = base.chk-sum.bmw.truth_template_L13
# param = <template_param>, <string>[, <string>..,]
# descr = 13-char BASE32 BMW-L13 sum, validated via AMOS7::TEMPLATE

##  template_param: sprintf | Regexp | CODE | ARRAY of any of those,
##  matching what AMOS7::TEMPLATE::assign_truth_templates accepts.
##  exclusion-style validation rides on
##  \&AMOS7::TEMPLATE::CALLBACK_exclusive_type included in the array.
```

implementation notes [ not the implementation — judgment for whoever
takes it ]:

- the bit-harvest loop is identical to `base.chk-sum.bmw.template_L13`'s
  current body. only the per-candidate validation changes:
  - replace `is_true_with_template($template, $result_str_B32, 0, 1)`
    with a guarded call to `AMOS7::TEMPLATE::template_is_true`
  - assign via `AMOS7::TEMPLATE::assign_truth_templates` once before
    the loop; reset via `AMOS7::TEMPLATE::reset_truth_templates` once
    after [ mirror `amos_chksum`'s discipline ]
  - honour `AMOS7::TEMPLATE::template_timeout()` inside the loop —
    `amos_chksum` does this at `CHKSUM.pm:225-238`; copy the shape

- keep `AMOS7::Assert::Truth::true_int($bits_num)` as the
  *floor harmony* assertion that the digest path itself owns; the
  template is the *additional* constraint, not a replacement.

- `calculate_L13_sum` [ digest-only variant ] should grow the same
  optional template parameter. when none is supplied, behaviour is
  bit-identical to today. when supplied, the same template loop runs.
  if implementing both at once feels right, do that; otherwise ship
  `truth_template_L13` first and leave the digest variant for a
  follow-up.

## signatures note

no `#,,..` stubs. do NOT run update-signatures. do NOT modify
subroutine whitelists. lowercase comments, `[ word ]` annotations,
`$ARG` not `$_`.

## acceptance

- `<[base.chk-sum.bmw.truth_template_L13]>->( "PFX:%s", "data" )`
  returns a 13-char BASE32 result whose `sprintf "PFX:%s", $result`
  passes `AMOS7::Assert::Truth::is_true( ..., 0, 1 )`.
- passing an `ARRAY` of mixed sprintf + Regexp + CODE templates works
  [ regression test against the same fixtures `AMOS7::CHKSUM` uses, if
  any exist; otherwise a small bespoke fixture ].
- passing a template + `\&AMOS7::TEMPLATE::CALLBACK_exclusive_type`
  after configuring `configure_exclusive_type_callback` yields a
  result that satisfies inclusion templates AND fails every inverted
  exclusion template — verify by direct sprintf check.
- with no template parameter and digest-input mode [ the
  `calculate_L13_sum` shape ], the result is bit-identical to today
  for the same input digest [ regression net ].
- timeout: configure a template that is mathematically unsatisfiable
  [ e.g. regex that cannot match BASE32 ], confirm the call returns
  undef within `template_timeout` rather than spinning forever.

## harmony checks

```
harmony base.chk-sum.bmw.truth_template_L13
```

[ run also against `base.chk-sum.bmw.calculate_L13_sum` and
`base.chk-sum.bmw.template_L13` if either is touched ]

#,,,,,,,.,..,,.,,,...,..,,,.,,,,,,...,.,,,.,,,..,,...,..,,..,,,.,,..,,.,.,.,.,
#VY7ZT6FQJH4HPJXX4TWYNJ7W6FFOLOOICXRMBO6DYRQVLX5XELK4OSLKKTUG3QDL2KYZIYX6M4A3I
#\\\|GDEJVELABEPJUCKX2DFQSRY2MABL5AUEL7X2WSZD4D3FYNHN66D \ / AMOS7 \ YOURUM ::
#\[7]OOYJAMWUY5BHIVQV4REHUTGSPJTUFTCOJQUWC4SFBXLG27KX7YBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
