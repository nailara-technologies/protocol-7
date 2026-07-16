# task: cred-mesh rotation-subscription cross-zenka registration

## status (2026-07-16, second pass)

Three real, distinct bugs found and fixed, verified live. One new,
narrower puzzle discovered at the very end — a permission check that
looks self-referential (`src 'cred-mesh'` targeting
`cred-mesh.subscribe_rotation'`) — not yet root-caused. Stopped here
deliberately (context over 700k, fresh session will be sharper) rather
than push further into core routing/reply internals tonight.

## bug 1 — subscription registered into the wrong zenka's %data (FIXED)

`proxy.init_code`/`transport.init_code` originally subscribed to cred-mesh
rotation events via a **local** `<[cred-mesh.subscribe_rotation]>` call —
since proxy/transport co-load cred-mesh's module code into their own
process (same mechanism as the SO_REUSEPORT incident, commit `0b52338ad`),
this wrote the subscription into their own local `%data` copy, never the
real standalone cred-mesh zenka's. Confirmed live via
`$data{'cred-mesh'}{'rotation_subscribers'}` staying empty in the real
cred-mesh process no matter how many times proxy/transport "subscribed."

**Fix**: route through `<[protocol-7.route-send]>` to a real
`cred-mesh.cmd.subscribe_rotation` command instead of the local call.

## bug 2 — startup race (FIXED)

Calling `route-send` synchronously at the top of `init_code` fails
silently — the zenka's own session-to-cube handshake isn't established
yet that early. Confirmed via `$data{'session'}` being queried right after
restart vs a moment later.

**Fix**: deferred via a one-shot `event.add_timer` (`after => 0.5`) to a
small new handler module (`proxy.handler.subscribe_rotation_deferred`,
`transport.handler.subscribe_rotation_deferred`), matching the existing
async-init pattern already used in `coding.init_code`.

## bug 3 — `.handler.` used as a network-routable target (FIXED)

The subscriber name registered was `proxy.handler.cred_rotated` /
`transport.handler.cred_rotated` — using this project's `.handler.`
convention (meant for **local, same-process callbacks only**, e.g.
`coding.handler.spawn_servers_deferred`, never invoked over the wire) as if
it were network-routable. Routing correctly strips the first segment
(zenka name) to deliver the remainder as one flat local command — but the
remainder (`handler.cred_rotated`) still has a dot in it, and something
downstream re-applies the same "strip first segment, route further" logic
to it, treating `handler` as *another* hop instead of a plain local name.

Traced this back to `data/md/design/CREDENTIAL-FABRIC-INTEGRATION-AND-UI.md`
line 160 — every other cross-zenka target in that same design doc
correctly uses the `zenka.cmd.something` shape (`protocol-7-menu.cmd.
input-text`, etc, matching "cube strips the `.cmd.` segment") except this
one place, which used `.handler.` instead. Genuine oversight in the
original design, not something introduced later.

**Fix**: added `proxy.cmd.cred-rotated` / `transport.cmd.cred-rotated` thin
wrappers (same shape as the already-existing `cred-mesh.cmd.rotate`
wrapping `cred-mesh.rotate`) that delegate to the existing, already-correct
`proxy.handler.cred_rotated` / `transport.handler.cred_rotated` flush
logic. Subscribers now register `proxy.cred-rotated` /
`transport.cred-rotated` (single dot after the zenka name) instead of the
raw `.handler.` names. Regenerated whitelists via
`bin/dev/gen-sub-whitelist <zenka>` rather than hand-editing (per the
project's own house rule — do not hand-edit whitelists, and a
directly-relevant example: `ls modules/*cmd*update*` shows this
receive-a-push-via-`.cmd.` shape is already used by many zenki).

Also found and cleaned up a previous, undocumented workaround attempt in
`configuration/zenki/proxy/start`: an explicit
`access.cmd.usr.cube = ... handler.cred_rotated * # <-- !!!` grant with a
comment already describing this exact multi-dot problem — someone hit
this before and patched around it with a permission grant instead of
fixing the naming. Removed now that the single-dot name doesn't need a
special-case grant (already covered by the existing bare `*` wildcard,
which only matches single-segment commands).

**Access grants updated** (all needed a manual `access.zenki`/`start`
edit + reload/restart, not just a code fix):
- `configuration/zenki/cube/access.zenki`: `access.cmd.usr.cred-mesh` now
  lists `proxy.cred-rotated`/`transport.cred-rotated` instead of the old
  `.handler.` names.
- `configuration/zenki/transport/start`: `access.cmd.usr.cube` didn't have
  proxy's bare `*` wildcard — added `cred-rotated` explicitly.
- **Important operational note**: editing `configuration/zenki/cube/
  access.zenki` requires an explicit `reload` sent to cube afterward
  (config isn't hot — cube keeps running with the old rules in memory
  until told to reload). `v7.restart`ing the zenki that call cube is NOT
  enough; cube itself needs the reload. This cost real time to discover
  live — restarting cred-mesh/proxy/transport repeatedly looked like the
  fix wasn't working, when actually cube just hadn't picked up the new
  grant yet.

## bug 4 — multi-line YAML payload over a line-based wire protocol (FIXED)

`cred-mesh.handler.rotation_strm` sent `YAML::XS::Dump({event=>...,
slot=>..., reason=>...})` (block-style YAML, always multi-line) directly
as a command's `args` string. The delivery wire protocol here
(`base.protocol-7.command.send.local`) is line-based — one command per
`\n` — so the payload was silently truncated to just its first line
(`"---"`, the YAML document marker) on arrival. Confirmed live: proxy's
`cred-rotated` handler received literally `'---'` as its args, YAML-loaded
it to an empty structure, found no `slot`, and returned `undef`.

**Fix**: base32-encode the YAML dump before sending
(`<[base.base32.encode]>`, the in-framework wrapper around
`Crypt::Misc::encode_b32r` — same established pattern `bin/coding-task`
uses "to avoid protocol framing issues"), decode it back
(`<[base.base32.decode]>`) in the two new `.cmd.` wrappers before handing
the YAML text to the existing flush-handler logic.

Also fixed both new `.cmd.` wrappers to return a proper
`{'mode'=>'true'/'false', 'data'=>STRING}` reply (the `.cmd.` contract) —
they were originally just passing through the underlying handler's return
value directly, which uses different keys (`flushed`, `profiles_flushed`,
`active_cleared`) with no `data` key at all, tripping
`base.handler.command`'s "did not return hash ref" check.

**Verified live end-to-end after all four fixes**: subscriber list
correctly populated in the *real* cred-mesh zenka
(`rotation_subscribers->{'*'} = ['proxy.cred-rotated',
'transport.cred-rotated']`), triggering an actual rotation produced:
```
proxy.handler.cred_rotated: flushed 0 cache entries for slot live-verify-test3
```
(0 flushed is correct/expected — no active auth-cache entry existed yet
for that specific test slot; the mechanism fired and completed correctly).

## open thread — apparent self-referential permission check (NOT FIXED)

After transport's access grant was added and it restarted, cube logged:

```
no perm. [ src 'cred-mesh' cmd|usr 'cred-mesh.subscribe_rotation' ]
```

Both `src` and the target resolve to `cred-mesh` — i.e. cred-mesh appears
to be denied permission to call its own command on itself. Confirmed via
`ncode s src cred-mesh.subscribe_rotation` that this string is **only**
ever used as a target by `proxy.handler.subscribe_rotation_deferred` and
`transport.handler.subscribe_rotation_deferred` — nothing in
`cred-mesh.*` calls it on itself. Confirmed the log entry is current (not
a stale pre-reload artifact, unlike an earlier red herring that turned
out to be exactly that — always check `:: localtime <id>` against the
most recent known-good reload/restart time before trusting a log line).

Working theory, unconfirmed: an artifact of the **reply leg** of the
route, not a fresh initiation. Neither deferred-subscribe handler sets an
explicit `'reply'` key on its `route-send` call, so
`base.protocol-7.command.send.local` defaults `reply.handler` to
`dev.null`. Something in how cred-mesh's `cmd.subscribe_rotation`
delivers its return value back through the established route may be
re-running a permission check using the *original* command string for
logging purposes, mislabeling the reply-completion as cred-mesh
initiating a fresh call to itself. This is speculative — needs a clean
trace through `base.route.add` / `base.handler.command`'s reply-dispatch
path (see `modules/base.handler.command.route_to_target`,
`modules/base.protocol-7.command.send.local` lines ~56-65 where the route
+ reply handler get set up) with a fresh, focused session rather than
more live poking at this hour.

If this turns out to affect the reply leg of *any* fire-and-forget
cross-zenka push (not just this one), it's a more fundamental thing worth
its own investigation — worth checking whether other existing
`route-send` callers that don't set an explicit `reply` key show the same
symptom, or whether something specific to this call path triggers it.

## verification

`bin/dev/cred-mesh-test` scenario 4 not yet re-run end-to-end since the
self-referential-permission thread above needs resolving first (it may or
may not affect the test harness's specific assertions — worth checking
once resolved, rather than assuming). Prior run (before all fixes above)
showed:
```
[ OK ] scenario 4 : proxy cache flush log
[ OK ] scenario 4 : transport cache flush log
[ OK ] scenario 4 : after-rotation header value
```
as the target state once fully closed.

## signatures note

do NOT manually write or edit signature lines. do not add stub
signatures to new files.

#,,.,,.,,,...,,.,,.,.,.,.,...,..,,,,,,.,.,,..,..,,...,..,,...,.,,,.,.,,,,,,,,,
#C2F6VI7V7IK3ZN7CR2T56ZB42P2U2MVJQ7AEELQQSMSROH7AUT6C4QA7P3DREWKYMHVVYFZ6WKQOG
#\\\|6NMT6IVCFVIT6AN4B5SBCC2LS5PGYEL7IEGASMDN2FPKXP3APFY \ / AMOS7 \ YOURUM ::
#\[7]BGMDIUHNYG7RSWBMGPBQOVF2G73CG72TIQW5OMPZMJZQYADSMAAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
