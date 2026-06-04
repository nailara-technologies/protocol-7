# plugin slots + context-aware selector

design for dynamic, context-aware frame slots. a slot's value can be produced
by a CODE provider at render time; a selector runs several candidate providers
and surfaces the most interesting one for the current page.

inspiration: `read-me/documentation/dev/research-notes/user-interfaces.00007.asc`
— the bottom status bar holds context-aware regions:

```
::[ :. command line .,    ..player content display --> ]::[ (>+ L O+V E S .  ]::
```

the left bracket is a *primary dynamic* region (command line OR player content
display, chosen by context, framed by flow markers `:.` `.,` `-->`); the right
bracket is a near-constant *identity* region. that is the model below.

## 1. integration site — %values , NOT a render-path change

[ revised after review: border slots already read their value straight from
`%values` in `ascii.frame.render.border_line` ( `$values->{ $el->{name} }` ).
and `render.color` is a POST-PROCESSOR — it splits an already-rendered string
and colorizes lines; it does not resolve slots. so there is ONE resolution site
and the whole feature is: populate `$values{PROGRESS}` before render. ]

the selector runs in `memory.tree.node.render` ( root variant ), where the
context — `node`, `children`, `<memory.focus>` — is already in scope. it sets
`$values{PROGRESS}` ( and `STATUS` ) to the winning provider's value. no change
to `ascii.frame.render` / `render.color`, no context threading.

### deferred : generic CODE-binding primitive [ YAGNI for now ]

a generic `binding => CODE` extension to `ascii.frame.slot.bind` + resolution in
`ascii.frame.render` ( the existing `ref eq SCALAR` spot, render ONLY — not the
color post-processor ) has real reuse value, but only for LIVE / animated slots
that must re-resolve without rebuilding `%values`. the status bar re-renders
fresh each `memory.show`, so per-render selection in `node.render` already gives
full context-awareness. defer the primitive until something needs live
re-resolution ( e.g. the player-content-display region from the inspiration ).

## 2. generic selector [ ascii.frame.slot.select — FOUNDATION, claude builds ]

```
input:  { providers => [ coderef, ... ], context => $ctx }
each provider( $ctx ) returns:
        { value => 'string', label => 'short', interest => 0..1 }
selector: run all providers -> pick max interest
          -> tie-break by registration order (earliest wins)
          -> return the winning { value, label, interest }
          -> all providers fail/skip -> { value => '' } [ harmless empty ]
output: the winning hashref [ caller uses ->{value} for the slot ]

fallback is by FLOOR INTEREST, not position: branch_count returns a small
constant interest ( 0.05 ) so it wins whenever every other provider is inactive
( returns ~0 ). it need not be registered last; that is only a convention.
[ verified: max-pick, broken-skip, earliest-tie, all-fail-empty all hold. ]
```

this is the "most interesting value for the current page" attention mechanism;
strategy is itself pluggable (a different selector could blend instead of max).

## 3. bar / decorator helpers [ ascii.frame.* — claude builds ]

- `ascii.frame.bar` — render a fractional value (0..1) as a ptd-style fill bar
  to a given width: `$char x int( $width * $frac )`, left-justified to `$width`.
  ptd reference: `bin/ptd` `show_progress` ( `:` x int(13*done/total), `%-13s` ).
- optional flow-marker decorator so providers can wrap a value as
  `:. <value> .,` / `... <value> -->` consistently.

## 4. memory status providers [ memory.status.provider.* — KIMI builds ]

each a small module: input `$ctx`, output `{ value, label, interest }`.
context shape assembled in `memory.tree.node.render`:

```
{ node => $root, visible => $n_vis, total => $total,
  focus => <memory.focus>, variant => 'root', width => 23 }
```

providers (composable via `memory.cfg.status_providers`):
- `weight_captured`  — frac = visible-slice score / total tree score;
                       interest high when the slice dominates ( skew )
- `focus_saturation` — frac = matched focus weight / tree; interest ~0 when no
                       focus is set, rises as focus concentrates
- `branch_count`     — value `N of TOTAL`; low constant interest = the
                       always-available fallback ( registered LAST )
- `rebuild_age`      — interest spikes right after a rebuild, decays with age

`memory.cfg.status_providers = weight_captured focus_saturation rebuild_age branch_count`
( same composable pattern as the scoring attributes — see memory.tree.score )

## 5. wiring [ memory.tree.node.render — claude builds the hook, then kimi fills ]

for the root variant, bind the `PROGRESS` slot to a plugin descriptor whose
`select` list resolves from `memory.cfg.status_providers`, with the assembled
`$ctx`. the yaml mockup gets the inline border slot, matching the already-proven
node/composite frames:

`memory-tree-root.yaml` top border:
`  ..[{{PROGRESS}}]..[ memory tree ]:.`   ( PROGRESS = inline border slot )

optional second region: a `STATUS` / identity slot on the right, lowest-interest
constant ( mirrors composite's `[ memory : {{STATUS}} ]` ).

## build order

1. claude: `ascii.frame.slot.select` + `ascii.frame.bar`  [ generic, needed ]
2. claude: wire `memory.tree.node.render` root PROGRESS slot via `%values`
   + yaml mockup, prove end-to-end with ONE provider ( branch_count )
3. kimi: remaining providers + `memory.cfg.status_providers` config + register
4. verify: `p7c memory.show 1` against `/tmp/frame.asc`; vary focus via
   eval-code to see the selector SWITCH providers

## future : vertical slots [ the frame as instrument panel ]

the horizontal border became a display surface ( the bracket status slot ). the
symmetric move is to make the VERTICAL border one too — every edge a slot.

- **vertical scrollbar by INVERSION** — the thumb renders at the OPPOSITE border
  width of the track: `:` against a `::` track, `::` against a `:` track. costs
  no extra column ( stays 2-wide, frame rigid ), distinguishable by contrast not
  addition. this is exactly what the variable-border-width parser unlocked,
  applied per-row on the vertical axis.
- **bottom-right mini echo** — a small horizontal bar at the bottom right that
  mirrors the vertical scrollbar's VALUE : same state shown twice at different
  scales ( full vertical thumb + compact horizontal echo ).
- generalizes: once the vertical edge carries per-row state, it is any vertical
  indicator ( focus depth, activity, a meter ), as the bracket became a slot.

IMPLEMENTATION COST ( why this is "later", not now ): `ascii.frame.render` uses
a SINGLE `border->{left}/{right}` for the whole frame. a scrollbar needs PER-ROW
border state — a "vertical slot" the renderer consults per content line. clean
extension, but a renderer change, not just a provider. the current state works
perfectly without it; scrollbars + bottom echo are purely additive.

## invariants

- guarded selection: a broken provider -> skipped , never a dead render
- fallback guaranteed: last provider always returns a value ( interest floor )
- generic layer stays zenka-agnostic: `ascii.frame.*` knows nothing about memory
- FIXED slot width ( old bracket = 23 ): every provider pads / truncates its
  value to the bracket width so the top border never jitters as the selector
  switches. `ascii.frame.bar` left-justifies to `$width`; text providers
  ( "7 of 162" ) must pad too.

#,,..,,.,,,.,,...,...,.,,,,,.,.,.,,..,.,.,...,..,,...,...,.,.,.,,,,..,,,.,.,,,
#GREUWSR5CNYW6PJVHJSSABK43CHLVDS7M5PHLB46DW5HM2EPLQE3BAJCGJZOWJMFFO7RLPTMGX7XO
#\\\|ELA4RLDQHIYO43AHLWJ5Y3ZDA3IXYNNHNVCORTRPGS54RTQR6AQ \ / AMOS7 \ YOURUM ::
#\[7]52NVVP7WOIIG4BZTFWFV3O6XZNV3CWS5ESW7HVIJXKRM2MV5ZIDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
