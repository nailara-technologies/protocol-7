# task: credential_fabric ui-show — slot-name/metadata security levels

## relation

`data/md/design/UI-SHOW-SECURITY-LEVELS.md` step (5) of the
implementation queue ("per-zenka level 1+ field maps, starting with
`credential_fabric` (slot names/metadata) as the proven case").

steps (1)-(4) are landed and live: `ui.fields.fallback`,
`ui.unfold`/`ui.render.fallback` field-map filtering, `ui.caller.
security-level` resolver, and the generic `*.ui-show` grant in
`cube/access.zenki`. all of that machinery is available to call into.

## the gap

`credential_fabric.cmd.ui-show` is a tier-2 "specific ui-show command"
in `ui.unfold`'s dispatch (see `modules/ui.unfold`, tier 2: `defined
$code{"$address.cmd.ui-show"}`). per the design doc, tier-2 renderers
are "trusted to do their own filtering" — but
`modules/credential_fabric.cmd.ui-show` currently does **none**. any
caller who can reach `credential_fabric.ui-show` [ now anyone, via the
generic `*.ui-show` grant from step 4 ] sees:

- `overview` view: counts only [ no names — already safe ]
- `slots` view (`<[credential_fabric.ui.render.registry_list]>`): full
  slot **names** + owner/type/sensitivity for every registered slot
- `slot <name>` view
  (`<[credential_fabric.ui.render.registry_detail]>`): full per-slot
  **metadata** card (owner, type, storage tier, rotation timestamps,
  subscribers)

slot *values* are never rendered anywhere in this path — that's
already correct and out of scope.

## read first

- `data/md/design/UI-SHOW-SECURITY-LEVELS.md` (whole doc, especially
  "per-zenka interesting base values map" — "slot *names* at level 1,
  slot *metadata* at level 2, and never expose slot *values* via
  `ui-show` at any level")
- `modules/ui.caller.security-level` — the resolver to call. returns a
  plain non-negative integer; `0` = default/unauthenticated
- `modules/ui.unfold` — confirms tiers 1/2 are unfiltered by design,
  tier 3 already does field-map + level filtering. this task brings
  tier-2 `credential_fabric.cmd.ui-show` in line with that intent
  using the SAME resolver, not a new mechanism
- `modules/credential_fabric.cmd.ui-show` — the dispatcher to modify
- `modules/credential_fabric.ui.render.registry_list` and
  `.registry_detail` — the two views to gate. both already render via
  `<[ascii.frame.load]>` / `<[ascii.frame.render]>` — do NOT touch the
  frame templates (`credential-fabric/registry-list`,
  `credential-fabric/registry-detail`) or `ascii.frame.*`, only gate
  whether these renderers are *called*
- `modules/credential_fabric.ui.render.overview` — confirm it stays
  reachable at level 0 (counts only, no names) — no change expected
  here, just verify

## scope

### `modules/credential_fabric.cmd.ui-show`

at the top of the dispatch (after `$view`/`@rest` are parsed), resolve:

```perl
my $caller_level = <[ui.caller.security-level]>;
```

then gate per view:

- `overview`: unchanged — counts-only overview
  (`ui.render.overview`) stays at level 0. but the `registry_list` and
  `auth_relay_queue` sections currently appended to `overview`'s output
  must themselves respect the same gates as their standalone views
  below [ i.e. `overview` is not a bypass route to slot names ]
- `slots` (-> `registry_list`, slot **names** = level 1): if
  `$caller_level < 1`, replace the rendered block with a one-line
  `[ restricted — slot list requires security level 1 ]` message
  [ no frame call ]. if `>= 1`, render as today
- `slot <name>` (-> `registry_detail`, slot **metadata** = level 2): if
  `$caller_level < 2`, replace with
  `[ restricted — slot detail requires security level 2 ]`. if `>= 2`,
  render as today
- `relays` / `holder`: out of scope for this task — leave unchanged
  [ separate concern, not "slot names/metadata" ]

restricted-message strings: plain text, no `ascii.frame.*` call, no
ansi markup needed [ the existing post-render colorisation block in
`cmd.ui-show` operates on the whole `$output` string and is harmless
on plain restricted messages — leave it in place, do not special-case
around it ]

### `overview` view composition

`overview` currently does:

```perl
$output .= <[credential_fabric.ui.render.overview]>;
$output .= "\n" if length $output;
$output .= <[credential_fabric.ui.render.registry_list]>;
$output .= "\n" if length $output;
$output .= <[credential_fabric.ui.render.auth_relay_queue]>;
```

apply the same `$caller_level < 1` gate to the `registry_list` segment
here as in the standalone `slots` view — either by extracting the
gate-and-render-or-restrict logic into a small local helper (a `sub`
inside this module, or a private `credential_fabric.ui.render.*`
helper if that fits existing conventions better) and calling it from
both places, or by inlining the same check twice. prefer the shared
helper if it's a clean fit — avoid duplicating the restricted-message
string as a literal in two places either way

`auth_relay_queue` in `overview`: unchanged, out of scope [ relays not
covered by this task ]

## non-goals

- no changes to `ui.unfold` / `ui.render.fallback` / `ui.fields.
  fallback` / `ui.caller.security-level` — steps (1)-(3), already
  landed
- no `<namespace>.ui.fields` map for `credential_fabric` — that generic
  field-map mechanism is for zenki using ui.unfold's tier-3 fallback.
  `credential_fabric` uses its own tier-2 `cmd.ui-show`, so the gating
  lives inside that command directly, using the same resolver
- no changes to `ascii.frame.*` or the `credential-fabric/*` frame
  templates — gating happens around the existing render calls, not
  inside the frames
- no changes to `relays` / `holder` views
- no changes to `credential_fabric.resolve` / `.rotate` / `.approve` —
  separate, already-correct authorization paths, untouched
- step (6) — generic key-based level authorization — remains separate
  and later

## acceptance

- `perl -c modules/credential_fabric.cmd.ui-show` clean
- with `<[ui.caller.security-level]>` resolving to `0` [ e.g. an
  unauthenticated/non-admin caller — see [[ui-caller-security-level]]
  for how to construct such a context, or temporarily stub the
  resolver call's return for a manual test, restoring afterward ]:
  - `credential_fabric.ui-show slots` -> restricted message, no slot
    names anywhere in the output
  - `credential_fabric.ui-show overview` -> counts/holder/relay
    summary only, no slot names
  - `credential_fabric.ui-show slot <any-real-slot-name>` -> restricted
    message, no metadata
- with the caller resolving to `taeki` [ admin, unbounded sentinel
  level per [[ui-caller-security-level]] ]:
  - `slots`, `overview`, and `slot <name>` all render exactly as they
    did before this task [ no regression for admin callers ]
- no slot *value* is rendered in any view, at any level [ unchanged
  from before — confirm, do not introduce a new path that would ]

## signatures note

no `#,,..` stubs. do NOT run update-signatures (pre-commit hook
re-signs on commit). lowercase comments, `[ word ]` annotations, `$ARG`
not `$_`. the module already exists on disk — edit in place, preserve
the existing header comment block and signature footer.

## checks

```
perl -c modules/credential_fabric.cmd.ui-show
```

#,,..,,.,,...,,,.,,,.,,..,.,.,.,,,.,,,.,.,,,,,..,,...,...,...,...,,,,,.,.,..,,
#JFYF2ZRWRRGWDPJ5DI5T3H3HXDC3Z3PBHPAOVE5QMALYAEXZZFNOSAZ5HKENZQ5WMWNL5U7V2ULBQ
#\\\|RWC465KAEPQ46ASKDWHXZDAISDQFNBWW6OO5YNWUCKVSU3AKUGD \ / AMOS7 \ YOURUM ::
#\[7]IAXWSOBCIANQX3QKD266BIBNFN2XTXFVMEOADRSZVWWXE4KIFMAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
