# epoch + checksum nested addressing with cross-epoch exclusion

## relation to prior design docs

this doc extends the lineage of
`data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md` and
`data/md/design/STDIO-RELAY-FOLD-APPLICATION.md` *downward* into the
checksum/addressing substrate. those docs establish that every branch is
itself a complete tree and that stdio relays can be folded into
addressable elements; both eventually want **named storage slots** for
their accumulated lines, logs, snapshots — and a homogeneous, native
default tree layout for that storage is the missing piece.

the connection to log storage is concrete: the per-zenka stdout ring
under `/dev/shm/.7/STDOUT/<sock>` mentioned in
`STDIO-RELAY-FOLD-APPLICATION.md` is, today, a flat in-memory ring; the
*persistent* counterpart [ when rotation actually lands on disk ] is
exactly the kind of thing that wants the `epoch/checksum` layout
proposed below — without dictating it for the volatile ring layer.

## the gap [ concrete ]

`AMOS7::CHKSUM::amos_chksum` already supports the full
template / exclusion vocabulary:

- hash-arg `sprintf-test-template` accepted and forwarded to
  `AMOS7::TEMPLATE::assign_truth_templates` —
  see `data/lib-path/pm/AMOS7/CHKSUM.pm:111-117`
- `AMOS7::TEMPLATE` accepts: sprintf strings, compiled regexes [ via
  `regex:` prefix or precompiled `Regexp` refs ], `CODE` refs, and
  `ARRAY` refs combining any of the above — see `TEMPLATE.pm:222-291`
- `configure_exclusive_type_callback` + `CALLBACK_exclusive_type` +
  `TEMPLATE_exclusive_type` build a reusable inverted-truth filter [ a
  candidate is rejected if it satisfies any of the inverted templates ]
  — see `TEMPLATE.pm:299-394`
- `amos_template_chksum` is the thin wrapper that assigns a single
  template and forwards to `amos_chksum` — `CHKSUM.pm:324-337`
- `base.p7refs.gen_template_chksum` is the existing precedent for
  taking `$reftypes_exclusion` as a *first-class* generation parameter
  rather than a validation afterthought, calling
  `configure_exclusive_type_callback` + composing template arrays +
  routing through `chk-sum.amos.truth_template_chksum`

the BMW-family checksums lack all of this:

- `base.chk-sum.bmw.calculate_L13_sum` takes a raw 512-bit BMW digest
  and harmonizes to a 13-char BASE32 result via the harmony loop. no
  template, no exclusion, no callback hooks. it is fundamentally
  "AMOS7::Assert::Truth::is_true" only.
- `base.chk-sum.bmw.template_L13` accepts *exactly one*
  `AMOS7::Assert::Truth::is_template_syntax_valid` template and calls
  `is_true_with_template` in its harmony loop. it does not accept:
  - an `ARRAY` of templates [ `amos_chksum` does, transparently ]
  - a `CODE` ref [ `amos_chksum` does — `AMOS7::TEMPLATE::template_is_true`
    branches on CODE ref type ]
  - a compiled `Regexp` [ `amos_chksum` does — same place ]
  - an exclusion hashref / exclusive-type callback
  - a `template_timeout` analogue
- `base.chk-sum.bmw384.*` is geometry-visualization oriented [ arc-
  segment, color, coordinate, group ]; no template path at all.
  generalising it would only make sense if a concrete consumer needed
  it — out of scope for the first pass.

**parallel needed**: a `base.chk-sum.bmw.truth_template_L13` matching
`amos_template_chksum`'s contract — accept `ARRAY|CODE|Regexp|sprintf`
templates, plumb through `AMOS7::TEMPLATE::assign_truth_templates`,
honour `AMOS7::TEMPLATE::template_is_true` instead of single
`is_true_with_template`. and a `base.chk-sum.bmw.calculate_L13_sum`
variant accepting the same template parameter so the *digest-only*
path is not the second-class citizen.

## epoch as the native outer dimension

`<[base.ntime.epoch_timestamp]>` encodes integers `0..385279`
[ ~7378 years at one-week-per-epoch ] into a `V7xxxxx` BASE32 form;
`<[base.ntime.harmonized_epoch]>` wraps it as `<V7xxxxx[;:]{4}>` with
the harmony-bit suffix searched at integer-interval `0..12`. that
encoded form is what cube exposes as `epoch-num` / `epoch_v7`.

epochs are **about one week long**. that low resolution is the point:
network activity collapses into ~weekly clusters and the prefix becomes
a coarse load-balancer for everything keyed off it.

## the native default tree layout

```
<encoded_epoch> / <amos_chk7> [ / <encoded_epoch> / <amos_chk7> ... ]
```

worked example for log storage of one line written at epoch 312:

```
V7L36RY / UXA5BUI
```

worked example for nested grouping [ session inside epoch ]:

```
V7L36RY / 3K4N7QA / V7L36RY / UXA5BUI
   ^         ^         ^         ^
   |         |         |         line checksum
   |         |         epoch the line arrived in
   |         session anchor checksum [ harmonized in the session
   |         template — see exclusion mechanism below ]
   outer epoch [ session-creation bucket ]
```

both segments are equal-length: encoded epochs are always the
`V7xxxxx` 7-char form [ the harmony suffix is dropped from the path
component — addressing uses the *integer* encoded form, harmony lives
on the rendered/printed form ], and AMOS checksums default to 7 chars
[ `$str_length = 7` in `AMOS7::CHKSUM` ]. *"equal length for all
items and participants"* falls out of two fixed widths:

- 7 chars for an encoded epoch path segment
- 7 chars for an AMOS checksum [ optionally shortened uniformly via
  `$sstr_start` / `$str_length`, but the choice is per-tree-policy
  not per-item — so length stays homogeneous within a tree ]

an N-deep `epoch/chksum` path is therefore always `N * 14` characters
[ plus N separators ] regardless of payload. this gives the latency
homogeneity the user's framing names: every lookup walks the same
fixed-width keys, every entropy filter [ checksum ] has the same
collision profile, and the only dimension that varies is *tree depth*
itself.

## cross-epoch exclusion as collision load-balancer

the mechanism: a checksum generated *within* epoch E carries a
template that excludes the checksum spaces of E-1 and E+1 [ and as far
out as a tree's policy demands ]. mechanically:

```perl
## within epoch E, generating chksum for $payload ##

my $E_prev = <[base.ntime.epoch_timestamp]>->( $E - 1 );  ## V7xxxxx ##
my $E_curr = <[base.ntime.epoch_timestamp]>->( $E );
my $E_next = <[base.ntime.epoch_timestamp]>->( $E + 1 );

## inclusion: must look like a current-epoch chksum ##
my @truth_templates = ( sprintf qw| %s:%%s |, $E_curr );

## exclusion: must NOT look like an adjacent-epoch chksum ##
##  using the same mechanism base.p7refs.gen_template_chksum uses
##  for reference-type exclusion: a sprintf template per excluded
##  prefix, fed to configure_exclusive_type_callback ##
my @excl_templates = (
    sprintf( qw| %%s:%%%%s:%s |, $E_prev ),
    sprintf( qw| %%s:%%%%s:%s |, $E_next ),
);

AMOS7::TEMPLATE::configure_exclusive_type_callback(
    [ $E_curr ],                              ##  selected  ##
    [ $E_prev, $E_curr, $E_next ],            ##  full list ##
    \@excl_templates                          ##  inverted templates  ##
);

my $template_set = [
    @truth_templates,
    \&AMOS7::TEMPLATE::CALLBACK_exclusive_type,
];

my $payload_chk = <[chk-sum.amos.truth_template_chksum]>->(
    $template_set, \$payload
);
```

this is the **same pattern** `base.p7refs.gen_template_chksum` uses for
P7REF type exclusion — only the "type" is now an *epoch*, not a Perl
ref kind. the existing `configure_exclusive_type_callback` machinery is
already exactly the right shape.

**why this load-balances**: a candidate checksum that happens to
sprintf-pass `E_prev`'s or `E_next`'s template is rejected during the
`amos_chksum` modify-bits loop, forcing it to keep iterating. the search
space shrinks slightly within each epoch and the surviving namespace is
*disjoint by construction* from its neighbours' surviving namespaces.
collisions between adjacent epochs become structurally impossible
rather than statistically rare. the per-epoch checksum harvest is what
gets "categorized" at write time; the cost is paid by the generator
once and amortized over every reader for the life of the data.

the time-locality of access patterns then maps onto resource locality:
a query addressed `E_curr / xxxxx` can be served entirely from the
current epoch's bucket; a query for `E_curr - 5` is a cold-fetch.
bandwidth and scheduling decisions naturally cluster around `epoch =
current`, and "inevitable incoming agreement for future resource
allocation and result coordination" is just: any request that addresses
`E_next / ...` is, by definition, future work and can be queued against
the future bucket without any explicit scheduling layer.

## tightening the exclusion window

a policy parameter `$epoch_window` chooses the radius:

- window 1 → exclude `[ E-1, E+1 ]` [ minimal disjoint guarantee ]
- window N → exclude `[ E-N .. E+N ] \ { E }`

larger windows raise generation cost [ more sprintf passes per
candidate ] but extend the disjoint-namespace guarantee. checksum
generation timeout should scale with window size; reuse the existing
`AMOS7::TEMPLATE::template_timeout` knob — `base.p7refs.gen_template
_chksum` already demonstrates the idiom of bumping it before exclusion
work and resetting after.

## worked example — log storage across an epoch boundary

a log line arrives near the end of epoch 312:

```
ntime:        V7L36RZ4 ... [ epoch_dec = 312.97 ]
encoded_E:    V7L36RY
chksum:       generated with exclusion window=1
              against V7L36RX [E-1] and V7L36RZ [E+1]
stored at:    V7L36RY/UXA5BUI
```

the next line, three minutes later, has crossed the boundary:

```
ntime:        V7L36RZ7 ... [ epoch_dec = 313.00 ]
encoded_E:    V7L36RZ
chksum:       generated with exclusion window=1
              against V7L36RY [E-1] and V7L37AA [E+1]
stored at:    V7L36RZ/VYB3K4N
```

the *previous* line's checksum, `UXA5BUI`, by construction does *not*
satisfy the V7L36RZ-bucket's inclusion template; the *new* line's
checksum `VYB3K4N` by construction does *not* satisfy the V7L36RY-
bucket's inclusion template. a query

```
V7L36RY/UXA5BUI  →  hits exactly the first line
V7L36RZ/UXA5BUI  →  is, by template, an impossible address
                    [ a name that cannot have been generated in
                      that epoch — early rejection is free ]
```

so a lookup against the wrong epoch is detected *without consulting
the bucket* at all — exclusion templates are also a free
client-side prefilter. cluster rebalancing can move whole epoch
buckets around; the addresses inside each bucket remain stable forever
because they are mathematically bound to that bucket's template.

## what changes upstream

1. **BMW-L13 template parity** — see task
   `epoch-bmw-l13-truth-templates.md`. parallel of
   `amos_template_chksum` for the BMW-L13 harmonized digest path,
   accepting the full `ARRAY|CODE|Regexp|sprintf` vocabulary and
   exclusion callbacks.
2. **epoch path helper** — see task `epoch-chksum-path-helper.md`. a
   `base.path.epoch-chksum` that takes a payload + optional `ntime` and
   returns the canonical `<encoded_epoch>/<chksum>` string, with the
   exclusion window baked in.
3. **cross-epoch exclusion config helper** — see task
   `amos7-template-epoch-exclusion.md`. a reusable
   `AMOS7::TEMPLATE::configure_epoch_window_callback` that mirrors
   `configure_exclusive_type_callback` but takes a window radius
   instead of an explicit type list.

## non-goals for this dispatch

- no migration of the in-memory `/dev/shm/.7/STDOUT/<sock>` ring to
  this layout. the ring is a volatile relay artefact and stays flat;
  if rotation lands on disk later, *that* path adopts epoch/chksum.
- no change to BMW384 visualization-family modules. they have no
  template consumer today.
- no change to `epoch-num` / `epoch_v7` cube commands. they already
  expose what's needed.
- no policy decisions about *which* trees adopt the epoch outer
  dimension. that's per-consumer; this dispatch ships the substrate.

#,,,,,,,.,,,.,.,.,,,.,,,.,,..,,.,,..,,,,,,,.,,..,,...,...,...,..,,.,.,,.,,.,,,
#A3VDAQQ3KMZBRHWZZOSTEWOOP6PQURTNHPFLFSJGTP2HSMOBMTV5NYPENY4UUFPHNAOQ2NB3ANMU2
#\\\|GM34JBS7A2QAG34UXI4BCIM6L33FXMAMFQ4OV52D6ROHKXDQLQV \ / AMOS7 \ YOURUM ::
#\[7]NXS6ERWRGYFOTWYABUCULQVLHCULJMTUL2J637UFIPHNUYLN2MBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
