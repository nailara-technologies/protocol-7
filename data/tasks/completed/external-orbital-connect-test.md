# task: external zenka orbital connect — end-to-end test

## context

`external` zenka has a full orbital connect stack (commit `460f895a6`):
- external.cmd.connect-orbital: resolves orbital addr → IP+pkey → add-trunc → async
- external.handler.orbital_connect_reply: updates connection status, triggers sync
- external.cmd.list-connections: tabular view of active connections
- external.cmd.orbital-status: health snapshot
- external.orbital.sync_grid_fragment: merges remote orbital map into discover.known
- external.init_code: auto_connect one-shot timer (after=13)

this has never been tested end-to-end — no second node was available.

## what to test

once a second node is available (see nodes-orbital-second-node-setup.md):

1. `p7c external.orbital-status` — should show P7REF + known nodes count
2. `p7c external.list-connections` — should be empty initially
3. `p7c external.connect-orbital <p7ref-of-second-node>` — initiate connection
4. `p7c external.list-connections` — should show the connection with status
5. `p7c discover.list-orbital` — should show second node's grid fragment merged in
6. orbital.json `connections[]` should be populated
7. visualization should show tentacle line between self and connected node

## what to verify in the code

- `external.cmd.connect-orbital`: does it correctly parse the ADDR_B32 to derive IP?
  the current nodes.orbital.addr_b32 packs θ/φ/ψ/ω — verify the decode path
- `external.init_code`: `auto_connect` timer fires 13s after init — does it have
  anything to connect to yet at that point? probably harmless no-op initially.
- access permissions: does external have access to nodes.* and discover.* commands
  needed for grid sync?

## signatures note

do NOT add stub signature line to modified files.

#,,.,,.,,,...,.,.,.,,,.,,,...,,.,,.,,,,,,,..,,..,,...,..,,,,.,,,,,,,.,...,,,.,
#7GATV4SYDEZUWVBCFEO5EK2ENNVRAF4TOQVFAFA7OFC5WGGXSY6IQVCAI76MIFOVAYFMOJG6XDUX4
#\\\|I3W3P6DK6RVSL6UUPE4Z2STU3LRNF4KWED5ZZ7YLG77R6NZ6DNI \ / AMOS7 \ YOURUM ::
#\[7]YX6J7WJ6FRNTNWUXWNR5PKVJQ7XC4DRI6V75EYPQFCYLAKLAEOAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
