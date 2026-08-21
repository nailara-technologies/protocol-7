# task: complete the `external` zenka wiring (orbital connect stack)

## context

`external` has a full orbital-connect code stack already written
(`external.cmd.connect-orbital`, `external.handler.orbital_connect_reply`,
`external.cmd.list-connections`, `external.cmd.orbital-status`,
`external.orbital.sync_grid_fragment`, `external.init_code`) but it was never
actually wired into the rest of the system, so right now the feature is
inert. taeki: "the external zenka is still incomplete." This task is to
close the gaps found, not to redesign the feature.

There is a prior, narrower task file at `data/tasks/external-orbital-connect-test.md`
(end-to-end test once a second node is available) — that one already
flagged "does external have access to nodes.*/discover.* commands needed for
grid sync?" as an open question. The answer is no — see gap 1 below. This
task fixes that and the other wiring gaps; the other file's end-to-end test
still applies once a second node exists, separately.

## gaps to fix (each independently verifiable by reading the named file)

1. **No cube access grant for `external` as a caller, at all.**
   `cfg/zenki/cube/access.zenki` has an `access.cmd.usr.<name>`
   block for nearly every zenka that calls into another one, but there is
   no `access.cmd.usr.external` block anywhere in the file. That means
   every outbound `route-send` external makes — `nodes.cmd.add-tronk`
   (from `external.cmd.connect-orbital`), `discover.cmd.list-orbital`
   (from `external.orbital.sync_grid_fragment`), `nameserv.cmd.discover-nodes`
   (from `external.cmd.connect-orbital`'s fallback) — gets silently rejected
   by cube's access gate. This alone makes the whole connect flow
   non-functional even when invoked correctly. Add an
   `access.cmd.usr.external = nodes.add-tronk discover.list-orbital
   nameserv.discover-nodes` block, following the existing style of nearby
   blocks (e.g. look at `access.cmd.usr.weather` or `access.cmd.usr.proxy`
   for the exact `\` continuation / indentation convention used in this file).

2. **`external` is not started by anything.**
   `cfg/zenki/v7/start-set-up.base`'s `zenki.enabled` line does
   not include `external`, and `cfg/zenki/external/start.cfg`
   has no `start.on-demand = 1` line either (compare to `tile` or `web`'s
   `start.cfg`, which use on-demand). Decide and apply the on-demand
   pattern (mirroring `web`'s `start.cfg`: `start.on-demand = 1`, no
   `set_ondemand_timeout` call so it never idles out) — do NOT add it to
   `zenki.enabled` (always-on) unless you find a reason the others use
   on-demand that doesn't apply here.

3. **Missing `discover` dependency declaration.**
   `cfg/zenki/external/start.cfg` declares
   `dependencies = cube nodes` but `external.init_code`'s `auto_connect`
   block reads `$data{'discover'}{'orbital'}{'known'}` directly. If
   `discover` isn't up yet when `external.init_code` runs, that read
   silently returns `{}` (no error, just 0 scheduled connections) — masking
   a real dependency as a no-op. Add `discover` to the `dependencies` line.

4. **`connect-orbital` and `orbital-status` are not reachable by anyone.**
   Only `external.list-connections` is exposed (to `web`, in
   `cfg/zenki/cube/access.zenki` around line 322-326,
   `access.cmd.usr.web`). There is no grant anywhere for any zenka or user
   group to call `external.connect-orbital` or `external.orbital-status`.
   Decide what should be able to trigger a connection — at minimum `web`
   probably needs `external.orbital-status` for the orbital dashboard; do
   NOT expose `connect-orbital` broadly without checking with the user
   first (initiating a network connection is a meaningfully different
   trust level than reading status) — flag this specific point back instead
   of guessing if unsure who should get it.

5. **No disconnect/teardown path.**
   `<external.connections>` entries are created in
   `external.cmd.connect-orbital` and have their `status` field flipped by
   `external.handler.orbital_connect_reply`, but nothing ever removes an
   entry. A connection that fails (`status => 'failed'` or `'error'`) sits
   in the hash forever. Add an `external.cmd.disconnect-orbital <name>`
   command that removes the entry from `$data{'external'}{'connections'}`
   (mirror the existing `.cmd.` files in this zenka for return-shape
   conventions — `{ mode => 'true'|'false', data => STRING }`).

6. **No retry of any kind on failed connections.**
   Once a connection lands in `status => 'failed'` or `'error'`, nothing
   ever retries it — not even a fixed-interval retry, let alone backoff.
   Add a retry mechanism for failed/errored entries using exponential
   backoff with a cap and a reset-after-stable-success window — this
   project's existing canonical pattern for that shape is in
   `src/v7.handler.zenka_status` / `src/v7.init_restart_timer`
   (look at how `restart_delay` multiplies by 1.2 per failure, caps at
   `max_restart_delay`, and gets reset via a `reset_restart_delay` timer
   after a stable period) — copy that shape, scaled appropriately for a
   per-connection-name delay stored on the connection's hash entry (e.g.
   `$conn->{'retry_delay'}`), not a single global delay for all connections.
   Do NOT use a fixed-interval retry loop — this project has had real
   incidents from undef/fixed-interval timers tight-looping (see why this
   matters: a fixed timer that never backs off is exactly the kind of
   chatty unconditional-retry behavior that was just removed from the
   orbital data poller elsewhere in this codebase for the same reason).

7. **Devmod wildcard in `external/start`.**
   `cfg/zenki/external/zenka.v7` has:
   `access.cmd.usr.cube = ... * ## <-- devmod`
   — the trailing bare `*` grants cube blanket access to every command on
   `external`, including any future eval-code/exec-sub if those are ever
   added to this zenka's devmod config (they are not currently present —
   confirm that and leave them absent). Tighten this to the actual list of
   commands cube needs (compare to how `nodes` or `discover`'s `start` file
   scopes their `access.cmd.usr.cube` line, if those are narrower) instead
   of a wildcard, unless you find a concrete reason the wildcard is
   intentional here — if unsure, leave a comment explaining why and ask
   rather than guessing.

## what NOT to do

- Do not change `external.cmd.connect-orbital`'s actual connection logic
  (IP resolution, key encoding, route-send to `nodes.cmd.add-tronk`) — that
  part is believed correct, just unreachable (gap 1). The end-to-end
  behavioral test of that logic is a separate task
  (`data/tasks/external-orbital-connect-test.md`) that needs a second node
  to actually run.
- Do not add STRM/subscribe push support to `external.cmd.list-connections`
  in this task — that is being done separately as part of a broader
  orbital-data push redesign across `discover`/`external`/`nodes`/`web`;
  it will land in a follow-up task once `discover`'s version (the reference
  implementation) is done.
- Do not touch `graphics-matrix` — it is intentionally disabled right now,
  unrelated to this task.

## signatures note

Module files end with a 4-line AMOS7 signature footer starting with `#,,,`.
IGNORE these lines completely — they are auto-generated by the signing
system and must not be modified or investigated. Focus only on the code
above them. Do NOT add a placeholder/stub signature block to any file you
create or edit — leave files clean, the user signs them afterward with
their own passphrase.

## P7 conventions to follow (read CLAUDE.md if unfamiliar)

- lowercase comments, `[ word ]` bracket annotations not `( word )`
- `base.logs` (with numeric log-level first arg), not `base.log` for
  anything beyond a single fixed message
- booleans are `TRUE`/`FALSE` constants, never bare `0`/`1`
- after editing a zenka's `start`/`subroutine.white-list`, make sure any
  newly-referenced command is actually present in that zenka's white-list
  if you add one
- do not use `SUPER::` — P7 modules compile in the main/P7 namespace, not a
  class namespace
- `base.event.*` swaps to `event.*` after pre_init — use `<[event.add_timer]>`
  not `<[base.event.add_timer]>` in runtime code (compare existing callers
  if unsure)

## how to report back

For each of the 7 gaps: state what file(s) you changed and why, or — if you
decided NOT to fix a gap as written (e.g. gap 4's access decision) — say so
explicitly and explain what you flagged back instead of guessing.

#,,,.,...,.,,,,.,,,..,...,..,,,.,,.,.,,..,,,.,..,,...,..,,,..,.,.,.,,,.,.,,,.,
#LHWPLBVYOETWHBKWZ3FJPFVR2H4WWL64EG3XZBIFBBH7GIGXMWZZLXGKYKH5NRX532RMNQSY3WYAM
#\\\|TZAJ3ERWME75DUBHX4HCL6LJGZY7QWJDHAXOO5VIRKYWRE3I2BZ \ / AMOS7 \ YOURUM ::
#\[7]IMRQTI5CMSZMA6VFD5KM32R2AJGUBWVO5JNXXOBO2OMJ6HVFICDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
