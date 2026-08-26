# task: base.path.epoch-chksum — native epoch/chksum addressing helper

## relation

implements upstream change #2 of
`data/md/design/EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md`. depends on
the AMOS7::TEMPLATE helper from `amos7-template-epoch-exclusion.md`
for the inverted-truth exclusion path; degrades to *inclusion-only*
template if that helper is not yet present.

## what to ship

a new module:

```perl
## [:< ##

# name  = base.path.epoch-chksum
# descr = canonical <encoded_epoch>/<amos_chk7> path for a payload
# param = { data, ntime?, epoch?, window? = 1, depth? = 1,
#          chksum_len? = 7, exclusion? = TRUE }
```

returns the canonical path string:

```
V7L36RY/UXA5BUI                          ##  depth = 1, default  ##
V7L36RY/UXA5BUI/V7L36RY/XYZ4567          ##  depth = 2, nested   ##
```

semantics:

- if `epoch` not supplied, derive from `ntime` [ supplied or
  `<[base.ntime]>` ]; the integer epoch is the floor of
  `<[base.ntime.epoch_dec]>`.
- encoded epoch segment is the bare `V7xxxxx` form — *no* harmony
  suffix; addressing uses the integer-encoded form. the harmonized
  `<V7xxxxx[;:]{4}>` form is for display via `epoch_v7` cube command,
  not for path segments.
- chksum segment is `AMOS7::CHKSUM::amos_chksum` with the epoch
  inclusion template `"<encoded_epoch>:%s"` and — if exclusion mode
  is on and `configure_epoch_window_callback` is available — the
  epoch-window exclusion callback configured with the requested
  `window`. when exclusion is off [ or the helper not loaded ], the
  inclusion template alone is applied; the doc's collision guarantee
  weakens correspondingly and the helper should `s_warn` once per
  process noting that.
- `chksum_len` ≠ 7 routes through `AMOS7::CHKSUM`'s existing
  `$sstr_start` / `$str_length` shortening — same homogeneity
  rule: it's a per-tree policy, not per-item, so the helper takes
  it once and applies it to every segment in the path.
- `depth` > 1 simply re-invokes the inner generation `depth` times,
  each round taking the previous round's path string as input data
  for the next chksum. the outer epoch segment is repeated unless a
  per-round epoch is explicitly threaded — first-pass keep it simple,
  repeat the epoch; the design doc's nested-grouping example shows
  the user-driven case [ session inside epoch ] is handled by the
  *caller* deciding when to invoke a second pass with a different
  epoch.

## signatures note

no `#,,..` stubs. do NOT run update-signatures. do NOT modify
subroutine whitelists. lowercase comments, `[ word ]` annotations,
`$ARG` not `$_`.

## a candidate first consumer

[ optional — flag for a follow-up, do not pull into this task unless
trivial ] when v7's stdout ring rotates to disk [ not yet implemented;
see `src/v7.callback.stdout_log_rotate` ], the rotated file's
on-disk path should use `base.path.epoch-chksum` against the rotated
content blob. that's where the design doc's "log file storage using
epoch-bucket directories" example lands. ship the helper here; wire
the consumer when rotation-to-disk lands.

cross-reference: `data/md/design/STDIO-RELAY-FOLD-APPLICATION.md`
discusses the stdio store layer as the natural home for accumulated
lines; once persistence joins the ring, this helper is the layout
authority.

## acceptance

- `<[base.path.epoch-chksum]>->( { data => "hello" } )` returns
  `V7xxxxx/UUUUUUU` matching the current epoch and a valid AMOS chksum
  whose template-inclusion check `sprintf "<encoded_epoch>:%s", $chk`
  passes `AMOS7::Assert::Truth::is_true( ..., 0, 1 )`.
- explicit `epoch => 311` reproduces a stable path against fixed `data`
  [ deterministic given the AMOS modify-bits loop ].
- with `window => 1` and the AMOS7::TEMPLATE epoch-window helper
  present, the returned chksum *fails* the sprintf-fill against
  `epoch - 1` and `epoch + 1` inclusion templates — verify directly.
- with the AMOS7::TEMPLATE helper absent, the call still returns a
  valid path [ inclusion-only ], emits one `s_warn` per process, and
  the returned chksum passes the inclusion template but may or may
  not pass adjacent-epoch templates [ no guarantee in degraded mode ].
- `depth => 2` returns a 4-segment path; each chksum segment validates
  against its own inclusion template; the second chksum is
  deterministic given the first.
- `chksum_len => 4` returns 4-char chksum segments uniformly.

## harmony check

```
harmony base.path.epoch-chksum
```

## status [ 2026-08-25 ] — DONE, landed in `25c869953`. dispatched to
## kimi (model=k3-256k, domain warranted stronger reasoning than the
## mechanical dispatch-param tasks above). validated against all five
## semantic rules and the acceptance-criteria list by reading the actual
## AMOS7::TEMPLATE source (configure_epoch_window_callback/
## CALLBACK_epoch_window/template_timeout/reset_temp_valid_timeout all
## confirmed present with the assumed signatures, not guessed), tracing
## the depth=1/depth=2 examples by hand, and independently re-running
## `bin/dev/ptd -c` (syntax ok, no lines over 78 cols). kimi's own
## standalone harness against the real AMOS7::CHKSUM/TEMPLATE libs
## passed all 6 checks (inclusion fill, exclusion rejects adjacent
## epochs, determinism, depth=2 nesting, chksum_len=4, ntime-derived
## epoch matches explicit epoch). one minor non-blocking deviation: epoch
## derivation reimplements base.ntime.epoch_dec's divisor/modulus math
## locally instead of delegating to it, since that sub has no ntime-
## override parameter and this task requires one — numerically identical,
## verified against epoch_dec's own source. not live-verifiable without a
## running zenka: the live `<[base.path.epoch-chksum]>->({data=>"hello"})`
## acceptance item and the `harmony` check above — both explicitly noted
## as such by kimi rather than faked. module signing/whitelisting were
## left to the human as instructed; base.list.subroutines was updated by
## the signing process itself when this landed, not by kimi.

#,,.,,..,,,,,,,..,,..,..,,,,,,.,.,,,.,.,.,.,.,..,,...,...,.,,,...,.,.,.,,,,..,
#5YKWA7WP2FYHPUCWOC6OSGYA2AEQFPRBB5V4JKFM4MFSKIHGB7GSGL5D3CTIFHQGVOT5HSSO75EFM
#\\\|GLVIIHFXNMCBQCYVHTOTCM6CZ544AWI4IEXSOOJFZPERZEFTAG6 \ / AMOS7 \ YOURUM ::
#\[7]VXSBJSLT4X2JR6XJKC2KKYOOPAJHXQLQGZJJM36QYEEDFQZXSGDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
