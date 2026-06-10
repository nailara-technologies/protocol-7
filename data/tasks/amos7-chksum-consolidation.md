# task: consolidate BMW + JHA into AMOS7::CHKSUM

## relation

implements the "consolidation into AMOS7::CHKSUM" section of
`data/md/design/BMW-CHECKSUM-TEMPLATE-EXPANSION.md`. depends on
`data/tasks/bmw-harmonize-l13-helper.md` and
`data/tasks/epoch-bmw-l13-truth-templates.md` having landed first,
so the contracts being lifted are already settled in the P7 module
space.

## the gap

`AMOS7::CHKSUM` today exports `amos_chksum` + `amos_template_chksum`.
the rest of the digest family [ BMW raw digests, BMW-L13 harmony,
BMW-56 AMOS7::13 key derivation, JHA fast 32-bit hash ] lives only as
`modules/base.chk-sum.bmw.*` and `modules/base.chk-sum.jha.*` zenka
modules. standalone callers [ `bin/amos-chksum`, `bin/is-true`, the
AMOS7::P7 loader path, smtpd classifiers ] have to bootstrap the P7
module loader to reach those families. consolidating them into
`AMOS7::CHKSUM` gives standalone parity and creates **one** home for
digest+template+exclusion implementation, with each `base.chk-sum.*`
module collapsing to a one-line wrapper.

## what to ship

### new files

```
data/lib-path/pm/AMOS7/CHKSUM/BMW.pm
data/lib-path/pm/AMOS7/CHKSUM/JHA.pm
```

### CHKSUM/BMW.pm — exported subs

```
bmw_digest          ##  ( $bits, $data )   → binary digest
bmw_b32             ##  ( $bits, $data )   → BASE32 string
bmw_l13             ##  ( $data )          → 13-char B32 L13
bmw_template_l13    ##  ( $template, @data ) → templated L13
bmw_harmonize_l13   ##  ( $bmw_512_bin, $validator ) → L13
bmw_56_true         ##  ( $data, $key? )   → AMOS7::13 56-bit
bmw_template_56     ##  ( $template, $data, $key? )
```

implementation source for each sub is the body of its current zenka
module [ after the L13 chokepoint work has rewrapped
`calculate_L13_sum` / `template_L13` onto a single harmony loop —
that loop's body is what `bmw_harmonize_l13` becomes ].

### CHKSUM/JHA.pm — exported subs

```
jha_num             ##  ( @data ) → 32-bit unsigned int
jha_hex             ##  ( @data ) → 8-char hex
jha_b32             ##  ( @data ) → BASE32 string
jha_b64u            ##  ( @data ) → URL-safe base64
jha_b32_harmonized  ##  ( @data ) → harmonized BASE32
jha_template_b32    ##  ( $template, @data ) → templated jha
```

implementation source is the body of the corresponding
`base.chk-sum.jha.*` module [ `jha_template_b32` is new, ported from
the `base.chk-sum.jha.truth_template_b32` module shipped by
`bmw-truth-template-family.md`; whichever lands first becomes the
source-of-truth ].

### CHKSUM.pm changes

```perl
##  data/lib-path/pm/AMOS7/CHKSUM.pm  ##

use AMOS7::CHKSUM::BMW;
use AMOS7::CHKSUM::JHA;
use AMOS7::CHKSUM::BMW384;

##  re-export every public sub from the sister packages so a single
##  use AMOS7::CHKSUM qw| ... | reaches the whole family  ##

@EXPORT = (
    qw| amos_chksum amos_template_chksum $VERSION |,
    @AMOS7::CHKSUM::BMW::EXPORT,
    @AMOS7::CHKSUM::JHA::EXPORT,
    @AMOS7::CHKSUM::BMW384::EXPORT,    ##  if BMW384 is not already
                                       ##  exporting its subs by name,
                                       ##  add an @EXPORT to it
);
```

### zenka-module collapse

after the AMOS7 side lands, rewrite each `modules/base.chk-sum.bmw.*`
and `modules/base.chk-sum.jha.*` body to one-line wrappers:

```perl
##  modules/base.chk-sum.jha.b32  ##
return AMOS7::CHKSUM::jha_b32(@ARG);

##  modules/base.chk-sum.bmw.512_32  ##
return AMOS7::CHKSUM::bmw_b32( 512, @ARG );

##  modules/base.chk-sum.bmw.calculate_L13_sum  ##
return AMOS7::CHKSUM::bmw_l13(@ARG);

##  modules/base.chk-sum.bmw.truth_template_L13  ##
return AMOS7::CHKSUM::bmw_template_l13(@ARG);
```

preserve every existing module's `# name = ...` header and signature
footer; only the body shrinks.

## acceptance

- standalone perl script with only
  `use AMOS7::CHKSUM qw| bmw_l13 jha_b32 amos_chksum |;` can produce
  every digest the corresponding P7 modules produce, with
  bit-identical output for the same input.
- every existing `<[chk-sum.bmw.*]>` and `<[chk-sum.jha.*]>` zenka
  call returns bit-identical output to today — verify by fixture
  diff across at least 100 sampled inputs per module.
- `bin/amos-chksum` and `bin/is-true` continue to work unchanged
  [ they already use AMOS7::CHKSUM — this task only adds, never
  removes ].
- `harmony` passes against each rewritten zenka module.

## non-goals

- no contract change on any sub. names of new exports follow the
  family-prefixed snake_case shape; old `<[chk-sum.*]>` paths keep
  their names.
- no removal of `AMOS7::CHKSUM::BMW384` — it remains its own package;
  CHKSUM.pm just re-exports.
- no change to `AMOS7::13::key_56` itself [ deferred per parent
  design's notes ].

## signatures note

no `#,,..` stubs in new modules. do NOT run update-signatures. do
NOT modify subroutine whitelists. lowercase comments, `[ word ]`
annotations, `$ARG` not `$_` in the P7 module wrappers. inside
`CHKSUM/BMW.pm` and `CHKSUM/JHA.pm` follow the existing CHKSUM.pm
style [ standard Perl, `$ARG[0]` via English ].

## harmony checks

```
harmony modules/base.chk-sum.bmw.*
harmony modules/base.chk-sum.jha.*
```

[ a full family sweep after consolidation; any rewrapped module
should pass cleanly. ]

#,,,.,,,,,.,.,.,,,,.,,,.,,.,,,,..,...,,,.,,,.,..,,...,...,...,,..,,.,,,,,,..,,
#SLCFMFBIDDKAZB5IRZVAZVYLBXZD6V4UPEOAVRXPDN7XJUWJSSFXX7AHVUTCSBRV5DAO6WIBREYE2
#\\\|Q6GSXSO4PWXWIO6LTDYZKVUBC6MG7QCTJI4ZHFLR6I5T5LW26RK \ / AMOS7 \ YOURUM ::
#\[7]NW5DWA7FS6TV6NADACGZS6UXXPBC3FDRMPLZE6C7RC4HG4DFCEAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
