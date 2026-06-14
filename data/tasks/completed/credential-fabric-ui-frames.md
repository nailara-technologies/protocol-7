# task: credential fabric ui — read-only browser [ phase 1 ]

## relation to CONSOLE-FOLD-TREE-PHILOSOPHY

this is the **proven specific instance** of the tri-layer
(query / render / dispatch) that
`data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md` generalises into the
zero-config baseline every node inherits. completing this phase keeps
the working reference implementation live; the generic
`base.ui.*` primitives derive their shape directly from these modules.

## dispatch
build the read-only credential-fabric management ui as a set of ascii frame
templates plus query and render modules. read first:
`data/md/design/CREDENTIAL-FABRIC-INTEGRATION-AND-UI.md` (part 2);
`modules/keys.console.list` (the only existing credential-state ui — model
the visual style on this);
`modules/ascii.frame.load`, `modules/ascii.frame.compose`,
`modules/ascii.frame.render`, `modules/ascii.frame.slot.bind`,
`modules/ascii.frame.from_mockup`;
`data/yaml/ascii-frames/task-queue.yaml`,
`data/yaml/ascii-frames/session-catchup.yaml`,
`data/yaml/ascii-frames/memory-tree-root.example.asc` for the separator-stretch
+ block-slot idiom and concrete examples;
`modules/context.provider.frame` for the inline mockup path;
`modules/credential_fabric.init_code`, `modules/credential_fabric.register`,
`modules/credential_fabric.resolve`, `modules/credential_fabric.rotate`,
`modules/credential_fabric.subscribe_rotation` for the state the queries
must surface.
do NOT add interactive selection — that is the next task. do NOT modify
ascii.frame.* internals — use them as-is.

## goal
the user can run `p7c credential_fabric.ui.show <view>` and see a fully
rendered, frame-bordered ascii view of the current fabric state. five views:

```
p7c credential_fabric.ui.show overview      [ summary + counts + holder state ]
p7c credential_fabric.ui.show slots         [ full slot registry list ]
p7c credential_fabric.ui.show slot <name>   [ single-slot detail card ]
p7c credential_fabric.ui.show relays        [ pending auth-relay queue ]
p7c credential_fabric.ui.show holder        [ key-holder child process status ]
```

each view loads its frame template, runs the matching query, fills slots,
returns the rendered string for printing to the tty (or returning over
protocol-7 as a SIZE reply).

## frame templates to create

under `data/yaml/ascii-frames/credential-fabric/`:

### `overview.yaml`
top-level summary, three lines of headline state inside one frame.
mockup:
```
.:[ ]:::::::::::::::::::::::::::[ credential fabric ]:.
:  slots: {{SLOT_COUNT}}    owners: {{OWNER_COUNT}}   relays: {{RELAY_COUNT}}  :
:  holder: {{HOLDER_STATE}}    last rotation: {{LAST_ROTATION}}  :
:.....................................................:
```
slots: `SLOT_COUNT`, `OWNER_COUNT`, `RELAY_COUNT`, `HOLDER_STATE`,
`LAST_ROTATION` — all single-line `value` slots, right-aligned within
their visual cell.

### `registry-list.yaml`
block slot for the slot table. mockup:
```
.:[ slots ]::::::::::::::::::::::::::::::::::[ {{SLOT_COUNT}} ]:.
:  {{SLOTS_BLOCK...}}                                          :
:..............................................................:
```
slot `SLOTS_BLOCK` is `type: block`, one line per slot. line format
(column-aligned, padded to frame width):
```
slot-name                     owner       type           sens
openweathermap.api-key        weather     api-key        low
atom.udt-psk                  transport   psk            high
```
slot `SLOT_COUNT` is a small value cell for the count, label-side.

### `registry-detail.yaml`
single-slot detail card. mockup:
```
.:[ {{SLOT_NAME}} ]::::::::::::::::::::::[ {{SENSITIVITY}} ]:.
:  owner:        {{OWNER}}                                  :
:  type:         {{TYPE}}                                   :
:  storage:      {{STORAGE_TIER}}                           :
:  registered:   {{REGISTERED_NTIME}}                       :
:  rotated:      {{LAST_ROTATED}}                           :
:  rotate every: {{ROTATE_INTERVAL}}                        :
:  subscribers:  {{SUBSCRIBERS}}                            :
:............................................................:
```
all single-value slots. `SUBSCRIBERS` is comma-joined zenka names.

### `rotation-log.yaml`
block slot for recent rotations (last 20). mockup:
```
.:[ rotation log ]:::::::::::::::::::::::[ last {{LOG_COUNT}} ]:.
:  {{ROTATIONS_BLOCK...}}                                      :
:..............................................................:
```
line format: `<ntime_b32>  <slot-name>  by:<actor>  result:<ok|fail>`.

### `auth-relay-queue.yaml`
block slot for pending relays. mockup:
```
.:[ auth relays ]:::::::::::::::::::::[ {{RELAY_COUNT}} pending ]:.
:  {{RELAYS_BLOCK...}}                                            :
:................................................................:
```
line format: `<req_id>  <domain>  <age>  <status>`.

### `key-holder-status.yaml`
single-frame status panel. mockup:
```
.:[ key-holder ]::::::::::::::::::::::::::[ {{HOLDER_STATE}} ]:.
:  pid:          {{HOLDER_PID}}                                :
:  locked:       {{HOLDER_LOCKED}}                             :
:  last op:      {{HOLDER_LAST_OP}}    ({{HOLDER_LAST_AGE}})   :
:..............................................................:
```

### `access-map.yaml` [ optional this phase, write the spec only ]
block listing zenka → command access edges. defer rendering until phase 2
needs it for grant/revoke. include the yaml file with descr only, no slot
definitions yet.

each template includes the standard `border_style: single`, `modes:
[expanded]` per the existing convention.

## modules to create

### query layer
under `modules/credential_fabric.ui.query.*` — pure reads, no rendering:

- `credential_fabric.ui.query.overview` — returns `{ slot_count, owner_count,
  relay_count, holder_state, last_rotation_b32 }`
- `credential_fabric.ui.query.slots` — returns `{ slots => [ { slot, owner,
  type, sensitivity, storage }, ... ] }` sorted by slot name
- `credential_fabric.ui.query.slot_detail` — args `{ slot }`. returns
  `{ slot, owner, type, sensitivity, storage, registered, last_rotated,
  rotate_interval, subscribers => [ ... ] }` or undef
- `credential_fabric.ui.query.rotation_log` — returns `{ rotations => [
  { ntime_b32, slot, actor, result }, ... ] }` last 20
- `credential_fabric.ui.query.auth_relay` — returns `{ relays => [ { req_id,
  domain, ntime, age_s, status }, ... ] }`
- `credential_fabric.ui.query.key_holder` — returns `{ state, pid, locked,
  last_op, last_op_age_s }`

state sources:
- slot/owner/sensitivity/storage from `<credential_fabric.registry>`
- subscribers from `<credential_fabric.rotation_subscribers>`
- relays from `<credential_fabric.auth_relay_pending>`
- holder pid from `<credential_fabric.key_holder.pid>` (created by
  `credential_fabric.key_holder.parent` — if absent, state is `not started`)
- rotation log: append to `<credential_fabric.rotation_log>` on every
  `credential_fabric.rotate` call. keep last 100 in memory, persist to
  `var/credential_fabric/rotation.log` for crash recovery. **this requires
  a small edit to `credential_fabric.rotate`** — add the append call and
  initialise the in-memory ring buffer in `init_code`.

### render layer
under `modules/credential_fabric.ui.render.*` — load template, fill slots,
return string:

- `credential_fabric.ui.render.overview`
- `credential_fabric.ui.render.registry_list`
- `credential_fabric.ui.render.registry_detail`
- `credential_fabric.ui.render.rotation_log`
- `credential_fabric.ui.render.auth_relay_queue`
- `credential_fabric.ui.render.key_holder_status`

each module:
```perl
my $params = shift // {};
my $entry  = <[ascii.frame.load]>->('credential-fabric/<name>');
return '' if not defined $entry;
my $data   = <[credential_fabric.ui.query.<name>]>->($params);
## fill value slots
## for block slots: join the per-row strings with newlines, pass as one
## scalar to ascii.frame.compose
my $output = <[ascii.frame.compose]>->({
    frame  => 'credential-fabric/<name>',
    slots  => { ... built from $data ... },
});
return $output;
```

block-slot row formatting lives in the render module — that's the only
place that knows the column widths. derive column widths from the
template width (left after subtracting borders + padding) and the data
(max name length etc.), matching the keys.console.list pattern.

### dispatch layer

`modules/credential_fabric.ui.show` — entry point. args: view name + optional
slot name. dispatches to the right render module(s):

- `overview` → compose `render.overview` + `render.registry_list` (compact)
  + `render.auth_relay_queue` (compact) stacked
- `slots` → `render.registry_list` only, full width
- `slot <name>` → `render.registry_detail` only
- `relays` → `render.auth_relay_queue` + `render.rotation_log` stacked
- `holder` → `render.key_holder_status`

returns the concatenated rendered string. on tty, also colorises using
the project teal/purple convention (see `keys.console.list` lines
188-244 for the post-render colorisation pattern — copy the same regex
approach, adapted to slot names and column markers).

### the entry command

register `credential_fabric.ui.show` as a callable command in
`configuration/zenki/credential_fabric/access.zenki` (or wherever the
cube access list lives for this zenka — confirm during implementation).
the user invokes via `p7c credential_fabric.ui.show <view>`. on no view,
default to `overview`.

## what NOT to do

- do **not** add interactive selection — selection state, focus,
  keyboard handling all belong to the next task (`credential-fabric-
  ui-interactive.md`).
- do **not** extend ascii.frame.* internals. if a frame feature seems
  missing, use a render-layer workaround (column padding done in render,
  not in the frame) and flag the gap in the design doc instead.
- do **not** add a new zenka. these modules live inside the existing
  `credential_fabric` zenka.
- do **not** render frames inline by string concatenation. always go
  through `ascii.frame.compose` + a template. this is enforceable: if
  any render module hardcodes a `.:[ ]:.` border, that is a bug.

## acceptance
- `p7c credential_fabric.ui.show overview` on a freshly seeded fabric
  produces a three-frame stacked output with realistic numbers,
  rendering inside the correct frame borders.
- `p7c credential_fabric.ui.show slots` shows the full slot registry
  with column-aligned rows; pipe to `wc -l` to confirm row count
  matches `credential_fabric.ui.query.slots`.
- `p7c credential_fabric.ui.show slot openweathermap.api-key` returns
  the detail card with every field populated.
- `p7c credential_fabric.ui.show relays` shows the auth-relay queue;
  with no pending relays, the block slot renders as empty (one blank
  content line inside the frame, not a broken frame).
- the output of `keys.console.list` and the new ui share the same
  visual feel — same teal/purple, same `'name'` quoting style, same
  frame idiom where present.

## harmony checks
```
harmony credential_fabric.ui.show
harmony credential_fabric.ui.query.overview
harmony credential_fabric.ui.query.slots
harmony credential_fabric.ui.query.slot_detail
harmony credential_fabric.ui.query.rotation_log
harmony credential_fabric.ui.query.auth_relay
harmony credential_fabric.ui.query.key_holder
harmony credential_fabric.ui.render.overview
harmony credential_fabric.ui.render.registry_list
harmony credential_fabric.ui.render.registry_detail
harmony credential_fabric.ui.render.rotation_log
harmony credential_fabric.ui.render.auth_relay_queue
harmony credential_fabric.ui.render.key_holder_status
```

re-run harmony on `credential_fabric.rotate` and
`credential_fabric.init_code` (the rotation log addition touches both).

## signatures note
do not add the `#,,..` stub to any new file. the signing system writes
it. lowercase comments, `[ word ]` annotations. no emoji.

#,,..,...,,,..,...,,,..,,,,..,..,,.,,,,..,,..,..,,...,...,...,..,,...,,,.,...,

#,,.,,.,,,..,,,,,,.,,,..,,,.,,..,,,,.,,,,,.,,,..,,...,...,.,.,,.,,.,,,.,.,,,.,
#ZSNXUYKFXRX4HRYSI6JSDCUWNVAPHYH2B7T2KWSYIRN4SDDSSK3EEDYRTXQ5GPWK3SYWIEGISWSGE
#\\\|KGFEGKFNHJTULNB5366WMHMOMWCWKO76DLXP5DAU5CFZ54YP2R3 \ / AMOS7 \ YOURUM ::
#\[7]LCJSVH6PBQYC6SX2DSSUAX4EYUNVFBODIXTC67OJNDDEMDF7UWBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
