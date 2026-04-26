# task: web.space context → template layer selection

## context

the template resolver (`plugin.web.space.template-resolver.json`) reads
`web.space.templates.context` which now has zoom + intent from POST /context.
but the template layer selection logic isn't actually using this to change
what gets rendered — it reads the context but the `active_layers` field is
always empty.

## what to wire

1. read `modules/plugin.web.space.template-resolver.available_data` —
   what data sources does it enumerate?

2. read `modules/plugin.web.space.state` (section=template-json handler) —
   how is the template state assembled?

3. the intent field ("explore"/"navigate"/"focus") should influence which
   visualization layers are active. current intent→layer mapping design:
   - explore: show all nodes + full trail history + glow
   - navigate: default view (current)
   - focus: zoom in on self node, suppress distant nodes, emphasize glow

4. zoom level should influence grid layer density (already partially implemented
   via the grid-v13 calcRangeAlpha in the visualization)

## goal

after zooming in (focus intent) vs zooming out (explore intent):
- `/templates.json` should return different `active_layers` values
- the visualization should smoothly lerp toward the target layer weights
  (the lerp system is already in the visualization HTML — just needs non-empty targets)

## signatures note

do NOT add stub signature line to modified files.

#,,..,.,,,,..,,,.,.,,,,..,.,.,..,,,,.,.,.,..,,..,,...,...,,,,,...,,,,,..,,.,,,
#2TQDJSXXEU6IJJJ3TLHA2UG5U7CV2YJ4R6U5TBNDRBH7UMIGOJHDR6DNCCZ5U6FKKCW45WUOAM64W
#\\\|4MBFPXIRVQNAEH6CBMW4AKFKJJDPRNXWSJ5VL3GDN4WXFJAN6ZV \ / AMOS7 \ YOURUM ::
#\[7]HKR43ABHF6Y4RDV2NIC37BQYPHUSDU5YX7DFHTGB5E2FNLE3PGCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
