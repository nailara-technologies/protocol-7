# task: epoch-window exclusion callback in AMOS7::TEMPLATE

## relation

implements upstream change #3 of
`data/md/design/EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md`. ships the
substrate the path helper [ task `epoch-chksum-path-helper.md` ] and
any future epoch-keyed checksum producer rides on.

## what to ship

a small additive helper inside
`data/lib-path/pm/AMOS7/TEMPLATE.pm` that mirrors the contract of
`configure_exclusive_type_callback` but takes an *epoch window radius*
instead of an explicit type list:

```perl
sub configure_epoch_window_callback {
    my $current_epoch_num    = shift;    ##  integer in 0..385279  ##
    my $window_radius        = shift // 1;
    my $sprintf_templates_ar = shift;    ##  same shape as
                                         ##  configure_exclusive_type_callback
}
```

semantics:

- builds the encoded epoch strings for `current - radius .. current +
  radius` via `<[base.ntime.epoch_timestamp]>` [ or its non-zenka
  equivalent — see "loader" note below ].
- the *selected* type is the single current encoded epoch; the *full
  list* is the current ± radius range; the inverted-truth templates
  are the caller-supplied sprintf templates [ one `%%s` for the type
  slot, one `%s` for the candidate slot — identical to
  `configure_exclusive_type_callback`'s validation rules at
  `TEMPLATE.pm:317-328` ].
- stores the resulting config under
  `$AMOS7::TEMPLATE::callback_setup->{'epoch-window'}` so it doesn't
  collide with the existing `'exclusive-type'` slot; a tree can use
  both at once.
- a companion `CALLBACK_epoch_window` / `TEMPLATE_epoch_window` pair
  parallel to the existing `CALLBACK_exclusive_type` /
  `TEMPLATE_exclusive_type` — the *inner* logic is literally identical
  to `TEMPLATE_exclusive_type` since both walk an inverted template
  list against an explicit "wrong types" list. consider whether the
  cleanest implementation is just to expose a slot-name parameter on
  the existing pair rather than duplicating; if the cost of doing so
  is a wider blast radius than the rest of this task, prefer
  duplication.

## "loader" note

`AMOS7::TEMPLATE` lives in `data/lib-path/pm/AMOS7/` and must be
usable both inside zenki and from standalone scripts [ same as the
rest of `AMOS7::*` per the CLAUDE.md "AMOS7 Module System" notes ].
that means `configure_epoch_window_callback` cannot call
`<[base.ntime.epoch_timestamp]>` directly — that is module-loader
syntax usable only inside a running Protocol-7. mirror the encoding
arithmetic from `src/base.ntime.epoch_timestamp`:

```perl
##  encode integer epoch [ 0..385279 ] -> "V7xxxxx"  ##
my $encoded = Crypt::Misc::encode_b32r(
    pack qw| w |, 99999999 - $epoch_int
);
```

[ same use of `Crypt::Misc` `AMOS7::CHKSUM` already imports — see
`CHKSUM.pm:17,18` ]

if a future refactor lifts the encode/decode helper into
`AMOS7::Protocol::P7` [ which already exists per CLAUDE.md ], use that
instead; otherwise inline the four-line arithmetic with a clear
`## mirror of base.ntime.epoch_timestamp encode path ##` comment.

## signatures note

no `#,,..` stubs. do NOT run update-signatures. do NOT modify
subroutine whitelists. lowercase comments, `[ word ]` annotations,
`$ARG` not `$_`. `AMOS7::TEMPLATE` already has its own signature
footer — leave it.

## acceptance

- `AMOS7::TEMPLATE::configure_epoch_window_callback( 312, 1,
  [ '%%s:%%%%s:%s' ] )` returns a hashref whose `excl-type-list`
  contains exactly the encoded forms for epoch 311 and 313 [ not 312 ].
- with the callback configured and `CALLBACK_epoch_window` included in
  a template array fed to `amos_chksum`, the resulting checksum
  satisfies a current-epoch inclusion template AND its sprintf-fill
  against either adjacent epoch fails `AMOS7::Assert::Truth::is_true`
  [ verify both directly ].
- larger radii [ 2, 3 ] produce the expected fan-out; verify by
  inspecting `excl-type-list` length.
- coexistence: `configure_exclusive_type_callback` and
  `configure_epoch_window_callback` configured in the same run both
  enforce; one is not overwritten by the other.
- the template-validation rules from
  `configure_exclusive_type_callback:317-328` [ `%%s` + `%s` count
  exactly one each ] still apply and reject malformed sprintf
  templates with the same error path.

## non-goals

- no implicit "current epoch" lookup inside the callback config — the
  caller passes the integer in. that keeps the helper standalone-safe.
- no cube command for it; the path helper task is the user-facing
  surface.

#,,.,,,.,,,.,,,.,,..,,,,,,,.,,.,,,,,,,...,,,.,..,,...,...,...,,,,,.,,,..,,,..,
#BGPPRLN2GF5OMR6ZGQEHSAO5SLIQFROZCGU3IIH3QFWUV4EAI6AT2QX6QCYSX6W4RPA7XBJKHED2M
#\\\|GAXEZNP2GZIZWUOEU5JAYCIPSS3Z2PVN5TUIKZLR3S2IHOKBOVY \ / AMOS7 \ YOURUM ::
#\[7]IKK3KGYN4YBMSG5PHZVGVTKFCPA3BHOWYHSKBFN2DCF4BRLZRCDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
