# ui-show security levels

[ origin: 2026-06-11 — surfaced while wiring `ui-namespace-modules-load`
  (commit 5306f6450). discovered that `ui.cmd.ui-show` /
  `ui.unfold` / `ui.render.fallback` currently render an address's raw
  `%data` tree contents with no field-level filtering. opening
  `*.ui-show` to all zenki/users (the obvious next step once `ui` is in
  every `modules.load`) would let any caller read another zenka's
  internal state verbatim. this doc captures the fix the user proposed
  before that grant is made generic. ]

related: [[topic-frame-idiom-convergence]], `CONSOLE-FOLD-TREE-PHILOSOPHY.md`
(the tri-layer `ui.query.* / ui.render.* / cmd.ui-show` this doc adds a
filtering layer in front of), `data/tasks/ui-namespace-modules-load.md`
(which made `ui.*` reachable everywhere but left access at the existing
per-zenka/per-role grants — `cube/access.zenki` was deliberately left
unchanged, see session note 2026-06-11).

## the problem

`ui.cmd.ui-show` resolves an address and renders whatever `%data` holds
there. that's correct for a debugging tool used by an admin, but wrong
as a *generic, addressable-by-construction* command per the fold-tree
philosophy ("zenki acquire UI by being addressable"). "addressable by
everyone" and "everyone sees everything" must not be the same default.

## the proposal

### security level 0 = generic, non-leaking, always-on

every zenka exposes a small, structurally-derived set of "interesting
base values" that are safe for any caller:
- process pid(s), uptime, restart count
- paths to its own config/start files, log file [ paths only, not
  contents ]
- operation statistics — request counts, queue depth, error counts
- idle time / last-activity timestamp
- source age — last-modified / signature timestamp of its own modules

`ui.cmd.ui-show` at level 0 (the *default* for any caller, including
unauthenticated/low-trust) renders **only** fields tagged level 0. this
becomes the safe default for the generic `*.ui-show` grant — i.e. once
this exists, opening `*.ui-show` to `access.cmd.usr.*` is fine, because
level 0 is defined to be safe by construction.

### per-zenka "interesting base values" map

each zenka may declare `<namespace>.ui.fields` (or a `ui.fields.*`
fallback for zenki that don't): a map of

```
field_name => { value => sub {...} | address, level => N }
```

`ui.unfold` / `ui.render.fallback` walk this map instead of raw `%data`
when rendering. a zenka with no map gets the universal level-0 fallback
(pid/paths/stats/idle/source-age, derived generically from things every
zenka already has — process info, `%data{'system'}{...}`, file mtimes).

levels above 0 are zenka-defined: e.g. `credential_fabric` might put
slot *names* at level 1, slot *metadata* at level 2, and never expose
slot *values* via `ui-show` at any level (those go through
`credential_fabric.resolve`'s existing authorization path, untouched by
this doc).

### caller security level

a caller's effective level = max level granted by any group they belong
to. groups already exist (`<admin-user>`, `<AMOS-user>` — see
`access.zenki` `show-access` output, 2026-06-11 session: `taeki` ->
`..*.** **` via both groups). this doc proposes:
- a `security-level` attribute pinned per group [ admin groups default
  to "max" / unbounded, matching their existing wildcard access ]
- `ui.cmd.ui-show` reads the caller's group(s) (cube already resolves
  caller identity for access.zenki checks — reuse that resolution, do
  not add a parallel identity mechanism)
- renders all fields with `field.level <= caller.security_level`

### future: generic key-based authorization for levels

out of scope for the first implementation, but the level attribute
should be designed so that a later key-based system (per-key security
level, independent of group membership — e.g. for cross-zenka or
external callers) can plug in without changing the field-map shape:
`field.level` stays a plain integer; only the *resolution* of
`caller.security_level` gains a second source (key lookup) ORed/maxed
with the group-based one.

## non-goals

- does not change `credential_fabric.resolve` / `.rotate` / `.approve`
  authorization — those are separate, already-correct paths
- does not redesign `cube/access.zenki` group/role syntax — reuses
  existing group resolution
- does not implement levels 2+ semantics for any specific zenka in the
  first pass — only the level-0 universal fallback + the field-map
  mechanism + level-0-only generic `*.ui-show` grant

## implementation queue [ not yet task files ]

1. `ui.fields.fallback` — universal level-0 field map (pid, paths,
   stats, idle, source-age), generic across zenki
2. `ui.unfold` / `ui.render.fallback` — read from `<namespace>.ui.fields`
   (or `ui.fields.fallback`) instead of raw `%data`; filter by
   `field.level <= caller.security_level`
3. caller security-level resolution — group attribute lookup, reuse
   cube's existing identity resolution from `access.zenki` checks
4. once (1)-(3) land: add `*.ui-show` to `access.cmd.usr.*` in
   `cube/access.zenki` (the generic grant deferred from
   `ui-namespace-modules-load`, session 2026-06-11) — now safe because
   level 0 is safe by construction
5. (later) per-zenka level 1+ field maps, starting with
   `credential_fabric` (slot names/metadata) as the proven case
6. (later, separate task) generic key-based level authorization

#,,,,,...,.,,,...,...,,,,,.,.,,.,,,,,,.,,,,,,,..,,...,...,..,,..,,..,,,..,...,
#5QEZ7CY3GOQI2ZUY7SNR32YMQ6BFBMSXJUNGQMMR5MH5L3TEG465V5FHU7KVELCL46NRZRWB5XOG4
#\\\|BGDOJHEXBC7XUVXGDR3LQ2BRVBDQQOVDGZVRXJW3UX26Q5I4WOR \ / AMOS7 \ YOURUM ::
#\[7]W4VHF23237FEZ6CBKWSCOFSCIRGYZPY3A34YL2AORHNU72LXM2AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
