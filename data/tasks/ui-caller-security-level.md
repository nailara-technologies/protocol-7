# task: ui.caller.security-level — group-attribute resolver

## relation

`data/md/design/UI-SHOW-SECURITY-LEVELS.md` step (3) of the
implementation queue. resolves the caller's effective security level
by reusing cube's existing identity resolution from `access.zenki`
checks — no parallel identity mechanism.

[[ui-unfold-fields-filtering]] is the sole consumer in the first
pass: its filter step calls `<[ui.caller.security-level]>->()` to gate
field visibility. siblings [[ui-fields-fallback]] and
[[ui-unfold-fields-filtering]] do not depend on this task landing
first — they only depend on the *shape* of its return value [ a plain
non-negative integer, `0` meaning "default / unauthenticated / safe-
by-construction" ].

read first:
- `data/md/design/UI-SHOW-SECURITY-LEVELS.md` ("caller security level"
  + "future: generic key-based authorization" — the latter must be
  designable as a second source ORed/maxed in later, without reshaping
  this task's API)
- `modules/base.handler.command` — the live access path. line ~1588 has
  `<[base.has_access]>->( $user, $cmd_usr_str )`; surrounding code
  (lines ~459-505) shows how `$user` and `$cmd_usr_str` are derived
  from `$session` and `$data{'session'}{$sid}{'user'}`. THIS is the
  identity resolution to reuse — not a new one
- `modules/base.has_access` (26 lines — short; read in full to
  understand the access-conf check it delegates to)
- `modules/base.parser.access_conf` (the access-conf parser; gives the
  vocabulary of "groups" — admin-user, AMOS-user — that this task
  reads attributes from)
- `modules/base.access.special-user-map` (the `<admin-user>` /
  `<AMOS-user>` / `<unix-admin>` group expansion table; identifies
  which groups exist for attribute pinning)
- design-doc session note 2026-06-11: `taeki` resolves through both
  admin-user and AMOS-user groups via `show-access` output — confirm
  your resolver reaches the same conclusion for that user

## scope

### `modules/ui.caller.security-level`

```perl
## [:< ##
# name  = ui.caller.security-level
# descr = resolve the effective ui-show security level for the current caller
# param = none [ reads ambient session context, like base.handler.command does ]
# note  = [ returns a plain integer; 0 = default safe-by-construction ]
```

contract:
- returns a non-negative integer
- `0` is the floor — any caller, including unauthenticated / unknown,
  gets at least level `0` [ which is the only level that should ever
  be considered safe by construction; see [[ui-fields-fallback]] ]
- group-based resolution:
  1. derive the calling user the same way `base.handler.command`
     does — from the active session / `$data{'session'}{$sid}{'user'}`.
     factor out the lookup if practical, but do NOT duplicate the
     resolution logic; ideally call into an existing helper, otherwise
     mirror it in one place and add a `[ keep aligned with
     base.handler.command:NNNN ]` annotation
  2. expand the user's group membership via the same path
     `base.has_access` / `base.parser.access_conf` already uses for
     access-conf checks [ `<admin-user>`, `<AMOS-user>`, group aliases
     from `base.access.special-user-map` ]
  3. look up a per-group `security-level` attribute in the parsed
     access-conf data structure [ wherever the access parser stores
     group attributes; if no slot exists yet, add a minimal one
     scoped to this attribute only — do not redesign group syntax,
     per the design-doc non-goal ]
  4. effective level = `max` over all matched groups; admin groups
     [ `<admin-user>` and equivalents that already hold wildcard
     access ] default to a sentinel "unbounded" represented as a
     large integer [ e.g. the highest declared field level + 1, or a
     conventional sentinel like `1_000_000` — pick one and document
     in a one-line comment ]. the comparison in
     [[ui-unfold-fields-filtering]] is `field.level <= caller.level`,
     so a large integer correctly admits everything
  5. unknown / unauthenticated / no matching group -> `0`

- second-source hook for future key-based level: leave a single
  clearly-labelled `[ future: key-based level source maxed in here ]`
  one-line comment at the `max` step. do NOT implement key lookup —
  step (6) of the design doc, separate task

### access-conf attribute slot [ if needed ]

if the existing access-conf parser does not already retain per-group
attributes, add the minimal extension to do so:
- attribute key `security-level`, value a non-negative integer
- attribute is optional; missing means "no level granted by this
  group" [ resolver treats as 0 for that group, not for the user
  overall — the `max` still admits whatever other groups grant ]
- no changes to existing access-conf grammar for command/zenka
  matching — only the attribute slot

if the parser already supports group attributes generically, use that;
do not add a new mechanism.

### where the resolver lives

`modules/ui.caller.security-level` is a `ui.*` module so it loads
alongside the rest of `ui.*` via the `modules.load = ... ui ...`
change from [[ui-namespace-modules-load]]. it does NOT live in `base.*`
— the security-level system is a `ui.*` concern, even though it reads
ambient session state that the base handler also reads.

## acceptance

- `perl -c modules/ui.caller.security-level` clean
- called from a context where `$data{'session'}{$sid}{'user'}` resolves
  to `taeki` [ confirmed admin-user + AMOS-user member per session note
  2026-06-11 ], returns the "unbounded" sentinel — sufficient to admit
  any declared field level
- called from a context with no session or an unknown user, returns
  `0` — never dies, never undef
- called from a context where the user is in a group with
  `security-level = 1` attribute and no other groups, returns `1`
- the resolver does NOT re-implement identity lookup — it shares the
  `base.handler.command` path. grep confirms only one place in the
  codebase derives the calling user from the session

## non-goals

- no key-based level source — step (6) of the design doc, deferred.
  the `max` step has a labelled hook comment; that's all
- no changes to `cube/access.zenki` grammar or to which groups exist —
  reuses the existing `<admin-user>` / `<AMOS-user>` / etc set
- no changes to `base.handler.command` access checking — that path is
  for command authorization, untouched. this resolver runs *after*
  command authorization has already admitted the caller and is purely
  about field-level filtering inside the response
- do NOT add `*.ui-show` to `cube/access.zenki` — step (4) of the
  design doc, explicitly out of scope
- no per-zenka `<namespace>.ui.fields` authoring — that's step (5)

## signatures note

no `#,,..` stubs. do NOT run update-signatures (pre-commit hook
re-signs on commit). lowercase comments, `[ word ]` annotations, `$ARG`
not `$_`.

## checks

```
perl -c modules/ui.caller.security-level
```

#,,,,,.,,,,,.,.,,,,,.,...,,..,,.,,,,.,.,.,.,,,..,,...,..,,.,,,,.,,.,.,.,.,,..,
#KC6VMJCN5G52C67Q5GZ5JIZ52UFBW27QXKDH7O7Z3BNCAIDPR53YPZKMACJDLETZOPWWIRMPYLOGM
#\\\|ZIIGBIRV3NYJQKSMZAIGA672GGQTKAG6ZEQHVMBRX73DU6FB4WK \ / AMOS7 \ YOURUM ::
#\[7]EL2QZR464WLR5HVVXL3PNCBBCAKOQSK4XAURBJQRBKTT6OML7WCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
