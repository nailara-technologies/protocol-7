# task: v7 console stdio multiplex demultiplexer

## relation

depends on `data/tasks/stdio-multiplex-type-tag-codec.md` and
`data/tasks/stdio-multiplex-unix-socket-transport.md`. consumes the
slot-addressing primitives from
`data/tasks/console-stdio-slot-addressing.md` and the fold/render
primitives from `data/tasks/console-fold-primitive.md` +
`data/tasks/console-foldable-render-baseline.md`.

implements the *terminal endpoint* of the multiplex protocol — the
side that walks the META scope tree and routes each typed run to
its bound slot.

## the gap

v7's existing relay [ `v7.handler.process_output_line`,
`v7.handler.output_zenka_stdout`, `v7.stdout_log.write` ] consumes a
flat per-line stream from each zenka. it has no awareness of typed
runs, no scope tree, and no SIN/TOUT/NUM channels. the multiplex
protocol cannot land without a v7-side consumer of the new transport.

## scope

### `v7.handler.stdio_multiplex_demux`

```
# name  = v7.handler.stdio_multiplex_demux
# param = $record   [ typed-run record from base.stdio.frame.decode ]
# descr = route a typed-run record to its target slot binding
```

routing table [ keyed on `$record->{tag}` ]:

```
META         → scope-tree manipulation only [ enter/leave/close ]
EOUT (fd=1)  → <zenka>.stdout default view [ existing line-relay
                refresh ]; provenance from current scope's slot_addr
EOUT (fd=2)  → routes via base.log severity ladder [ stderr ]
EOUT (fd>=3) → <zenka>.stdout.fd.<n> sub-tree slot binding
SIN          → silent prompt slot at <zenka>.stdio.prompt; the
                returned input rides back via the same transport's
                upstream direction as a paired typed run
RIN          → <zenka>.stdio.raw sub-tree; default render is hex/b32
                fold per the framing protocol's debug view
TOUT         → <zenka>.stdout.view.template binding; payload is the
                ui-template render hint consumed by vterm.*
NUM          → <zenka>.stdout.metric.<header.name> [ status-bar slot
                or arbitrary metric tree node ]
STR          → <zenka>.stdout.value.<header.name>
ERR          → <zenka>.stdout.err sub-tree + base.log severity 1+
```

### `v7.handler.stdio_multiplex_listen`

```
# name  = v7.handler.stdio_multiplex_listen
# descr = open the v7-side listener on /dev/shm/.7/STDIO/<zenka>
#         for any zenka that has opted in [ start config flag ]
```

walks `<v7.start_setup.zenki.config>` [ per
[[feedback-prefer-parsed-config]] — do NOT FS-rescan ] for zenki
with `stdio.multiplex = yes`, opens a listener per such zenka, and
attaches `v7.handler.stdio_multiplex_demux` as the per-record
callback.

### `v7.handler.stdio_multiplex_scope`

```
# name  = v7.handler.stdio_multiplex_scope
# param = $record  [ META subtype = scope-enter / scope-leave ]
# descr = maintain the per-zenka scope tree used for provenance
#         routing of inbound typed runs
```

scope tree is a per-connection stack rooted at the inbound zenka.
`scope-enter` pushes a node carrying `origin` + `slot_addr` +
`hop_id`; `scope-leave` pops. typed-run routing inspects the
current TOS for provenance metadata.

## acceptance

- a test zenka emitting the worked example from the design doc
  [ EOUT + SIN + TOUT + NUM + ERR over one multiplex socket ]
  results in five distinct slot updates at the v7 console with
  correct provenance.
- existing zenki [ not opted into multiplex ] see no behavioural
  change — the legacy line-relay path is untouched.
- SIN payload is **never** echoed onto EOUT — verified by emitting a
  SIN run with a known secret and grepping the v7 console buffer
  for the secret string [ must not match ].
- detach: unbinding the EOUT slot while typed runs continue arriving
  causes the slot to stop painting; the store layer keeps the runs;
  re-binding the slot replays the most recent state per the fold/
  render-tree refresh rules.
- nested scope: a zenka A whose output is relayed through a zenka B
  on its way to v7 results in two scope-enter/leave pairs in v7's
  scope tree, with A as the inner origin and B as the outer.

## non-goals

- no zenka-side adoption — opt-in is by start-config flag; this
  task only ships v7's listener side.
- no UI primitives beyond what the existing slot/fold/render
  tasks ship.
- no new access-control surface — `cube/access.zenki` is the gate,
  per [[feedback-buffer-access-control]].
- no migration of existing zenki off the legacy line-relay; this
  is purely an additive transport.

## signatures note

no `#,,..` stubs. do NOT run update-signatures. do NOT modify
subroutine whitelists. lowercase comments, `[ word ]` annotations,
`$ARG` not `$_`.

## harmony checks

```
harmony v7.handler.stdio_multiplex_demux
harmony v7.handler.stdio_multiplex_listen
harmony v7.handler.stdio_multiplex_scope
```

#,,,.,...,.,.,..,,,.,,.,,,,,,,...,.,.,,.,,.,.,..,,...,..,,..,,,..,.,.,.,,,..,,
#CLCNTQ6V4DWGYZRM6X5CAOBZORTAHXVEWJXPAVJMIMN2WVTY6EVXWOLSUWD7UGJXU5OBR63UTMPCQ
#\\\|JEZYTRI6DWWF73MZMOZ3UQDU2HSH54X6QEEMFCCPMTK76FFTOX2 \ / AMOS7 \ YOURUM ::
#\[7]YMCL762W77X64AIGFGHDWD4VJIOX4BQ7DZJZKMQ7WLJDISUFFGAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
