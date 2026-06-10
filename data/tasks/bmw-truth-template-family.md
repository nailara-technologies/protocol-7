# task: BMW + JHA family-wide template/exclusion tranche

## relation

depends on `data/tasks/bmw-harmonize-l13-helper.md` [ chokepoint ] and
`data/tasks/epoch-bmw-l13-truth-templates.md` [ L13 templated wrapper ]
landing first. parent design:
`data/md/design/BMW-CHECKSUM-TEMPLATE-EXPANSION.md`. extends the
template/exclusion vocabulary [ `ARRAY|CODE|Regexp|sprintf` +
`CALLBACK_exclusive_type` + `template_timeout` ] across the rest of
the BMW + JHA families.

## scope [ three deliverables ]

### 1. `base.chk-sum.jha.truth_template_b32`

new module, parallel in contract to
`base.chk-sum.bmw.truth_template_L13`:

```perl
# name  = base.chk-sum.jha.truth_template_b32
# param = <template_param>, <string>[, <string>..,]
# descr = templated BASE32 jhash, validated via AMOS7::TEMPLATE
```

implementation outline:

- assign templates via `AMOS7::TEMPLATE::assign_truth_templates`
- harmony loop mirrors `base.chk-sum.jha.b32.harmonized:11-26` but
  swaps the per-candidate validator from the implicit self-template
  to `AMOS7::TEMPLATE::template_is_true`
- honour `AMOS7::TEMPLATE::template_timeout` inside the loop with the
  same guard pattern as the L13 chokepoint
- reset via `AMOS7::TEMPLATE::reset_truth_templates` on exit
- exclusion support rides through `CALLBACK_exclusive_type` in the
  template ARRAY [ same wiring as
  `base.p7refs.gen_template_chksum` ]

acceptance: same shape as L13 task's acceptance section
[ sprintf + Regexp + CODE + ARRAY + exclusion + timeout ], applied
to the jha B32 path.

### 2. `base.chk-sum.bmw.truth_template_56`

new module wrapping the 56-bit AMOS7::13 path with the full template
vocabulary. today `base.chk-sum.bmw.filesum.56.TRUE` and
`base.chk-sum.bmw.B-32-56.TRUE` accept a single template via
`is_true_with_template`. this module accepts the same vocabulary
`amos_template_chksum` does, by either:

- routing through a new `AMOS7::13::truth_template_key_56` if
  `key_56`'s internal harmony loop is extracted analogously to the
  L13 chokepoint [ preferred — keeps the algorithm in one place ];
  OR
- if extracting `key_56` is out of scope, wrap externally:
  pre-assign via `AMOS7::TEMPLATE::assign_truth_templates`, drive
  `key_56` in single-template mode using a synthesised composite
  template, validate each candidate via
  `AMOS7::TEMPLATE::template_is_true`, reject and retry on failure

mark the chosen branch in the task header before implementation; the
two carry different review surfaces.

### 3. `base.chk-sum.bmw.harmonize_384` [ placeholder only ]

stub module with a fixed `return undef` and a `# TODO` comment
referencing this task and the parent design doc. no consumer today;
landing the stub flags the future shape so when a BMW384-geometry
consumer wants a templated source digest, the chokepoint slot already
exists and only its body has to be filled.

```perl
# name  = base.chk-sum.bmw.harmonize_384
# param = $bmw_384_bin, $validator_coderef
# descr = PLACEHOLDER — harmonize 384-bit BMW digest to a B32 form
#         under a caller-supplied validator predicate; see
#         data/md/design/BMW-CHECKSUM-TEMPLATE-EXPANSION.md
return undef;
```

## non-goals

- no change to the BMW384 geometry subs themselves — they remain
  pure functions of a 48-byte digest; templated input is the caller's
  responsibility once `harmonize_384` is filled in.
- no change to `bmw.calculate_L13_sum` or `bmw.template_L13`
  contracts beyond what the chokepoint task already does.
- no AMOS7 consolidation in this task — that is its own
  deliverable, `amos7-chksum-consolidation.md`.

## acceptance

per-deliverable acceptance is enumerated above. additionally:

- no existing caller of `<[chk-sum.jha.*]>` or `<[chk-sum.bmw.*]>`
  observes a contract change; only **new** wrappers are added.
- harmony checks pass for each new module.

## signatures note

no `#,,..` stubs. do NOT run update-signatures. do NOT modify
subroutine whitelists. lowercase comments, `[ word ]` annotations,
`$ARG` not `$_`.

#,,..,,.,,...,,,.,,..,.,,,...,..,,.,.,,,,,,..,..,,...,...,,..,,..,,..,.,,,...,
#6MCJCOYFU7FE3EHIPAJXKCMT5BEZ3YZZ3WWW2GXXTWBTY4MNGGJEDVIP2LHS3CN6WQMXO2WWF4W2Q
#\\\|CB7EKPT5UXESL7RCZG2G7XUE2CAQRLG2MFLU4D7IVR3SZ3RMMLH \ / AMOS7 \ YOURUM ::
#\[7]INFGAJ7LTTC3FFL676MRDWCAFUN2KAHM6OGVT3PGKM6G32CSP6CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
