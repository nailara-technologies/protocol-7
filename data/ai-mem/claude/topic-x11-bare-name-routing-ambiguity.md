---
name: topic-x11-bare-name-routing-ambiguity
description: "LANDED 770553ad2+505f5505b: concurrent X-11 instances (host+xvfb-000N) — generic sid resolver, display-range calc, per-instance display tracking in v7"
metadata: 
  node_type: memory
  type: project
  originSessionId: f4339d87-d62c-4af2-bd7a-8532f2169b22
---

## what this covers (resolved 2026-07-14, two commits)

Started as a single diagnosis (bare `X-11.foo` fanning out to every X-11
session once a second one exists) and grew into full concurrent-instance
support after live testing kept surfacing more breakage. Both commits
verified live: three concurrent instances (host `:0`, `xvfb-0000` `:7`,
`xvfb-0001` `:8`) each resolve and report their own correct display, and
`screen-setup`'s display-layout snapshot renders correctly afterward.

### commit `770553ad2` — routing

- **`base.zenki.resolve_primary_sid`(`.pick`/`.reply`)** — new generic
  (not X-11-specific) async resolver in `src/`. Any zenka calls
  `<[base.zenki.resolve_primary_sid]>->( $user_name, $callback, $caller_subname )`
  to get a target's routable sid instead of addressing by bare name.
  **Design principle: subname is a group tag, not a tie-breaker** — a
  caller's own subname (defaults to `<system.zenka.subname>`) is matched
  against candidate rows first (`tile[xvfb-0000]` finds `X-11[xvfb-0000]`
  automatically), falling back to a configurable `<zenki.$name.preferred_subname>`
  then lowest-sid if no exact group match exists.
  - non-v7 callers: cross-zenka `list subnames $user_name` sent to cube
    (undotted commands execute wherever received — lands on cube via the
    caller's default upstream), parses the returned table.
  - **v7 callers use a local fast path** — v7 already has `root_sid`/
    `cube_sid`/`subname`/`status` synced per managed instance in
    `<v7.zenka.instance>` (via `v7.zenka-instances.get-ids`), no network
    round-trip needed. Caught and fixed two wrong turns here: (1) first
    used `root_sid` — wrong, that's set only by `v7.callback.connect_to_cube`
    for v7's *own* cube connection, not the managed instance's session;
    the actual per-instance sid is `cube_sid`. (2) briefly built
    `"$root_sid.$cube_sid"` mirroring `v7.handler.heartbeat_timer` — also
    wrong, that manual nesting is only needed because heartbeat_timer
    calls `command.send.local` directly; every resolver caller goes
    through `protocol-7.route-send`, which already auto-prepends the
    equivalent hop via `<protocol-7.network.parent_route>` — double-
    prefixing otherwise. Final: bare `cube_sid`.
- All known bare-name `X-11.*` cross-zenka callers converted (24 files) —
  resolve first, then address `"$sid.command"`. The zenka-name segment
  (`"$sid.X-11.foo"`) is **redundant once sid-addressed and was wrong** —
  sid alone determines the target; fixed to `"$sid.foo"` across all 27
  call sites (confirmed live: `<sid>.name`/`<sid>.subname` work with no
  zenka-name segment at all).
- New `<list.subnames>` list definition in `base.init_code` (shared, every
  zenka gets it except v7 which already defines its own from a different
  data domain), sourced from `session` — column renamed `session` not
  `instance` (taeki's fix — v7's own `list subnames` uses "instance" for
  its *different* concept, v7-internal object ids, not cube session ids;
  reusing that name here would have been confusing).
- `access.zenki`: `list` granted globally (`access.cmd.usr.*`) so any
  zenka can query `<list.subnames>` on cube. **Known gap, deferred by
  design**: no parameter-level restriction yet (`list:subnames` vs
  `list:sessions` etc.) — would need `base.parser.access_conf`/
  `base.has_access` expansion; taeki added an inline comment
  (`# <-- restrict later [param based]`) rather than block on it.
- `X-11.init_code`/`post_init`: mode-subname parsing now captures the
  instance index (`xvfb-0000` → mode `xvfb` + index `0`, previously
  discarded via non-capturing group) into `<X-11.mode_index>`. Display is
  now base (still user-configured per-mode in `zenki/X-11/zenka.v7`, e.g.
  `X-11.display.xvfb = :7`) + index, **overwritten in place** in
  `<X-11.display>->{$mode}` — first attempt wrongly tried to "protect" this
  as a shared base and computed a separate `<X-11.primary_display>`, which
  broke `connect_X11`/`reconnect`/`pool.dial_standby`/`cmd.get_display` (all
  read `<X-11.display>->{$mode}` directly as *the* live display). No
  cross-instance collision risk from overwriting: each `X-11[xvfb-000N]` is
  its own OS process with private `%data`.
- `X-11` zenka-startup: `max_concurrency` 1→8, added
  `max_subname_concurrency = 1` (caps each individual subname to one
  instance, e.g. only one `xvfb-0000` at a time).

### commit `505f5505b` — v7's own per-instance display tracking

`v7.zenka.start` read `<x11.display>` as one flat scalar for every zenka
it spawns — even with routing fixed, whichever X-11 instance's reply
landed last would silently override the DISPLAY env var for every
subsequently-spawned zenka, host or virtual alike.

- `v7.callback.get_x11_display` now runs **per-instance**: `start.cfg`'s
  `v7-post-init` passes `<instance_id>` explicitly
  (`[v7.callback.get_x11_display:<instance_id>]`), and the callback reads
  that specific instance's `cube_sid` directly from `<v7.zenka.instance>` —
  no subname-group resolution here, since v7 itself has no subname and
  would otherwise always match the host instance regardless of which one
  just started.
- `v7.handler.get_display_reply` stores under `<x11.display>->{$cube_sid}`.
- `v7.zenka.start` resolves the display for *the zenka being spawned* via
  `resolve_primary_sid('X-11', ..., $zenka_subname)` — resolves
  synchronously since v7's own process always takes the local fast path
  (no real round-trip), so the existing spawn flow's control flow didn't
  need restructuring.
- Defensive coercion at both sites (`<x11.display> = {} if ref(...) ne
  'HASH'`) since a v7 process already running before this landed may still
  hold the old flat-scalar value in memory.

## known follow-ups (not yet done)

- Parameter-level access restriction for `list` (see above) — deferred,
  commented inline in `access.zenki`.
- `resolve_primary_sid`'s cross-zenka (non-v7) table-parsing path was
  built but never exercised live in this session (only the v7-local fast
  path was actually triggered by testing) — worth verifying once a
  non-v7 zenka's bare-name X-11 call actually needs to resolve through
  cube for real.

## related

[[topic-x11-multi-server]] · [[topic-x11-resolution-profiles]] (screen
*size* per instance — separate axis from this file's display *number*
range, both use subname suffixes but different separators, `:WxH` vs
`-\d+` — will need reconciling if/when resolution profiles land) ·
[[topic-x11-protocol-hardening]] · [[topic-window-canvas-addressing]]
(unrelated identity question, already solved differently)

#,,.,,,,.,.,.,,,,,.,,,,,,,,,,,,,.,...,.,.,,,,,..,,...,..,,..,,.,.,,.,,,..,,,.,
#OBWOG3A3G27SBFIL4XRHBHJVQTBT5L7XN4O77C4TK53JHZFNEUF45DGT6C3ZYVFLWBD2JZHW6T2RS
#\\\|ZG2VHI6FEUDAAGZLXBPUBYLF64P2F5TEV6G5JZVFPXYOPY3OYIW \ / AMOS7 \ YOURUM ::
#\[7]LKHZNRDR7NZVSYSISMPVUD4G22FFFWB3RILQFKKHCC6UDGVSL4DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
