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

### re-confirmed 2026-07-18, reply-leg theory now doubted

Reconfirmed live after a **fresh zenki restart** (ruling out any stale-log
explanation): `cube` still logs
`no perm. [ src 'cred-mesh' cmd|usr 'cred-mesh.subscribe_rotation' ]`.
`bin/dev/cred-mesh-test` still shows the same 2 scenario-4 failures
(`transport cache flush log`, `after-rotation header value`) — unchanged
by the unrelated bug-5 base32-prefix fix below, confirming this permission
issue is the actual remaining blocker for those two assertions.

`grep -rn subscribe_rotation modules/` shows **no code anywhere** that has
`cred-mesh` call `cred-mesh.subscribe_rotation` (or
`cred-mesh.cmd.subscribe_rotation`) on itself — the only callers are
`proxy.handler.subscribe_rotation_deferred` and
`transport.handler.subscribe_rotation_deferred`, both going through
`<[protocol-7.route-send]>` → `base.protocol-7.route-send` →
`base.protocol-7.command.send.local`. So the call-site search is a dead
end — **the bug is not at the call site, it's in a loaded module along the
routing/permission-check path** (current working suspicion, unconfirmed).

Traced one layer further into `base.protocol-7.command.send.local`
(`modules/base.protocol-7.command.send.local:23`): the regex
`s|^([^\.]+)\.((([^\.]+)\.)*\w[\w\d\_\-\.]*)$|$2|` strips the first dotted
segment off `cred-mesh.subscribe_rotation` as the routing `target_name`
(`cred-mesh`), leaving the remainder `subscribe_rotation` as the wire
command — but the actual receiving-end command is registered as
`cred-mesh.cmd.subscribe_rotation` (see `modules/cred-mesh.cmd.subscribe_rotation`),
not bare `subscribe_rotation`. Whether this mismatch is *the* bug or a
red herring wasn't established — didn't get far enough to confirm what
`base.handler.command` (where the `no perm.` log line at line 1042 actually
fires, using `$user`/`$cmd` — see `protocol.protocol-7.message-templates`
key `VSY5TBA`) resolves `$user` to for this session, i.e. why cube would
see the session's `$user` as `cred-mesh` for a command that proxy/transport
sent. `$user` here is presumably tied to whichever zenka's authenticated
session the command arrived on — needs tracing from `base.handler.command`
backward to confirm whose session this actually is, rather than assuming.

**Do not re-trace the reply-leg / dev.null-default-handler theory from the
paragraph above as the primary lead — treat it as one candidate among
several.** Prioritize: (1) confirm what session/user cube actually sees
this command arrive on, (2) check the `.cmd.` vs bare command-name mismatch
in `send.local`'s target stripping, (3) only then return to the reply-leg
theory if 1-2 don't explain it.

### RETRACTED — the "stray manual test data" theory below was wrong

The paragraph originally here claimed this was explained by a stray
`handler => 'cred-mesh.subscribe_rotation'` value from earlier manual
testing, with "no fix needed beyond the general reflection task." **That
theory is contradicted by a fresh, cleaner reproduction on
2026-07-18, after a full clean restart, with the new logging from bug 5's
fix in place**:

```
cube    : [3007049] zenka 'cred-mesh' [initialized]
proxy   : proxy: deferred rotation-subscribe timer fired, subscribing to cred-mesh
cr.,.sh : cred-mesh.cmd.subscribe_rotation: received slot=* handler=proxy.cred-rotated
proxy   : proxy: rotation-subscribe route-send result : 1
cr.,.sh : cred-mesh.cmd.subscribe_rotation: result for handler proxy.cred-rotated : subscribed
cr.,.sh : proxy: deferred rotation-subscribe timer fired, subscribing to cred-mesh
cr.,.sh : proxy: rotation-subscribe route-send result : 1
cube    : [3007049] no perm. [ src 'cred-mesh' cmd|usr 'cred-mesh.subscribe_rotation' ]
```

Look at line 6: the log **channel prefix is `cr.,.sh` (cred-mesh's own
log)**, but the **message text is `proxy.handler.subscribe_rotation_deferred`'s
own log line** (`"proxy: deferred rotation-subscribe timer fired..."`,
added in this same session). That is direct evidence that **cred-mesh's
own process executed proxy's deferred-subscribe handler code** — not a
leftover data value from old manual testing. This is the same *class* of
bug as bug 1 (co-loaded module code / inherited state executing in the
wrong zenka's process — see the SO_REUSEPORT incident, commit `0b52338ad`,
and CLAUDE.md's own note that "zenki forked from partially initialized
parents can inherit data structures"), but manifesting as an **inherited
timer/event-loop callback surviving a fork** rather than a shared `%data`
write. Working theory, not yet confirmed: proxy's 0.5s
`event.add_timer` for `proxy.handler.subscribe_rotation_deferred` gets
scheduled before cred-mesh forks off from whatever shared parent process
image spawns these zenki, and the timer watcher itself (not just compiled
code) is inherited into the child (cred-mesh), firing there post-fork —
which would explain both why `<system.zenka.name>` reads `cred-mesh`
inside that fired callback (producing `src='cred-mesh'` in the permission
check) and why the reflection-vulnerability theory
(`cred-mesh-subscribe-handler-reflection.md`, still valid as its own
finding) isn't the root cause of *this specific* symptom.

**Root-caused, confirmed live 2026-07-18** (not a fork-inheritance issue,
simpler than that):

1. `p7c cred-mesh.eval-code 'return exists $code{"proxy.handler.subscribe_rotation_deferred"} ? "yes":"no"'`
   → `yes`. `p7c cred-mesh.eval-code 'return join(",", grep {/^proxy\./} keys %code)'`
   → the **entire** `proxy.*` namespace is compiled into cred-mesh's own
   `%code`, including `proxy.init_code` and
   `proxy.handler.subscribe_rotation_deferred`.
2. `configuration/zenki/cred-mesh/start:29` — cred-mesh's own
   `modules.load` explicitly includes `proxy` as a full namespace token:
   `modules.load = auth net protocol io.unix ui cred-mesh credential proxy \
   ascii.frame format.yaml httpd.status_codes devmod`.
3. `configuration/zenki/cred-mesh/start:35` calls `[init_modules]` with
   **no arguments**. `modules/base.init_modules` lines 22-23, when called
   unscoped, does `<[base.sort]>->( \%code )` over **every** compiled sub
   in `%code` regardless of zenka-namespace origin, and executes (line 68:
   `$code{$sub_name}->(...)`) any `.pre_init`/`.init_code`/`.post_init` it
   finds. Because `proxy` is in cred-mesh's own `modules.load`, this runs
   `proxy.init_code` — **inside cred-mesh's own process** — which is what
   registers proxy's 0.5s `subscribe_rotation_deferred` timer. When that
   timer fires, `<system.zenka.name>` genuinely reads `cred-mesh` (it truly
   is running there), so the resulting `route-send` genuinely originates
   from cred-mesh, targeting itself. Exact match for the observed log.

Confirmed this is **one-directional**: `configuration/zenki/proxy/start`
and `configuration/zenki/transport/start` do not list `cred-mesh` in their
own `modules.load`, so they don't run cred-mesh's `init_code` in reverse.
Scope of the fix is cred-mesh's own `start` file only.

**Corrected per the user**: `base.init_modules` running every co-loaded
module's `init_code` unscoped is not a bug at all — it's the established
project convention (`base.init_code`, `httpsd.init_code`, `keys.init_code`,
`ncode.init_code`, `work.init_code` all self-guard with
`<system.zenka.name> eq qw| X |`, confirmed via
`ncode s src:.init_code system.zenka.name. eq`). `proxy.init_code` already
had exactly this guard (`$is_proxy_zenka`), correctly applied to its
listener-binding and stale-socket-cleanup blocks, with a comment that
literally anticipates cred-mesh co-loading this module ("other zenki that
load the proxy module namespace [ e.g. cred-mesh, for subscribe_rotation
side effect ] must not bind a duplicate SO_REUSEPORT listener"). **The
actual bug: one block — the `event.add_timer` registration for the
rotation-subscribe timer, the very last thing in the file — was left
unguarded**, the one spot the original author missed.

**FIXED**: added `if $is_proxy_zenka` to that one `event.add_timer` call
in `modules/proxy.init_code`. `configuration/zenki/cred-mesh/start` itself
does not need changing — keeping `proxy` in cred-mesh's `modules.load` is
fine now that the guard is complete; cred-mesh may still reference plain
`proxy.*` helper subs directly, just never runs proxy's own init side
effects.

**Not fixed, flagged only**: `transport.init_code` has **no zenka-name
guard at all** (confirmed: no other zenka's `start` currently lists
`transport` in `modules.load`, so this isn't an active bug today) — same
latent landmine as `proxy.init_code` had, just not triggered yet. Left
untouched since it's not currently broken and wasn't asked for, but worth
a proactive guard the next time this file is touched, matching the
project's own established convention.

**Verified live 2026-07-18 after the fix**: restarted `proxy`/`transport`/
`cred-mesh` via `v7.restart`. Fresh cred-mesh sessions (`5795270`,
`7771203`) show `proxy.selector.load: 4 rules loaded` (harmless,
unconditional but idempotent, unrelated to this bug) but **zero**
occurrences of `deferred rotation-subscribe timer fired` or
`rotation-subscribe route-send result` — the leaked timer no longer fires
in cred-mesh's process. `tail -100` of cube's log shows no
`cred-mesh.subscribe_rotation` `no perm.` entries at all. Confirmed
closed.

`bin/dev/cred-mesh-test` remains at 20/23 with scenario 4's two failures
(`transport cache flush log`, `after-rotation header value`) still
unexplained — confirmed transport's `route-send` to
`cred-mesh.subscribe_rotation` reports success (`count : 1`) after adding
logging to `proxy.handler.subscribe_rotation_deferred`,
`transport.handler.subscribe_rotation_deferred`,
`cred-mesh.cmd.subscribe_rotation`, and the two silent early-return paths
in `base.protocol-7.command.send.local` (the `[LLL]`-marked "unknown
target" gap now logs instead of silently returning 0) — but cred-mesh's
log shows **zero** mentions of transport ever arriving, while proxy's
identical call succeeds end-to-end every time. The vanishing point is
somewhere past `send.local`'s successful queue and before cred-mesh's
`.cmd.` wrapper — `base.handler.command.route_to_target` (the actual
receiving-side dispatch, already a proven trouble spot from bug 3) is the
next place to instrument, not yet done.

## verification

re-run 2026-07-18: `bin/dev/cred-mesh-test` — 20/23 assertions pass, 3 fail:

```
[ OK ]   scenario 4 : proxy cache flush log
[ FAIL ] scenario 4 : transport cache flush log
[ FAIL ] scenario 4 : after-rotation header value : expected 'new-key-bbbb', got ''
[ FAIL ] scenario 5 : relay pending file has entry : expected 1 pending entry, got 0
```

the two scenario-4 failures confirm the open thread above is not just
theoretical: proxy's flush log line appears (its subscription got through),
transport's does not (its subscription is the one hitting the
self-referential permission denial), and the header staying empty is the
downstream consequence — transport never flushed, so it kept serving the
old key. **acceptance criteria for this task**:

1. root-cause the self-referential permission check (`src 'cred-mesh' cmd|usr
   'cred-mesh.subscribe_rotation'`) using the reply-leg theory above as the
   starting point (`base.route.add` / `base.handler.command`'s reply-dispatch
   path, `base.protocol-7.command.send.local` lines ~56-65)
2. fix it so transport's subscription actually registers
3. re-run `bin/dev/cred-mesh-test` and confirm scenario 4's `transport cache
   flush log` and `after-rotation header value` both pass
4. if any other existing `route-send` caller omits an explicit `reply` key
   the same way, note whether this is a narrower one-off or a systemic issue
   — do not fix unrelated callers speculatively, just report the finding

the scenario-5 failure (`relay pending file has entry`) is **not** part of
this task's scope — nothing in this file's bugs 1-4 touches the auth-relay
console path. leave it alone; do not attempt to fix it here. it will be
filed as a separate task.

## bug 5 (new, 2026-07-18, undiagnosed) — base32 decode undef in transport only

live log during a fixture re-run (transport PID freshly spawned, same
`cred-mesh-test` invocation, scenario-2 bearer-slot rotation):

```
tr.,.rt : [3293477] <<< undefined value as subroutine reference >>> [transport.cmd.cred-rotated:8]
```

line 8 is `<[base.base32.decode]>->( \$args_b32 )` — `$code{'base.base32.decode'}`
resolved to `undef` in **transport**, while the byte-identical call in
`proxy.cmd.cred-rotated` (same shape, same line) works fine in **proxy**
(confirmed: scenario 4's "proxy cache flush log" passes, and scenario 1/2
which route through proxy never hit this).

ruled out already:
- not a whitelist gap — `configuration/zenki/proxy/subroutine.white-list`
  and `configuration/zenki/transport/subroutine.white-list` both list
  `base.base32.decode` (confirmed identical lines, both present)
- not a stale process — transport was freshly spawned by the same test run
  that hit this

user's working theory (untested): likely a redundant `base.` prefix
somewhere, or a not-yet-implemented subroutine — i.e. this may be a naming/
registration bug of the same *class* as bugs 1-3 above (module compiles and
whitelists fine, but the code path that actually populates `%code` for this
zenka's `modules.load` token set doesn't include it, even though the
whitelist generator thinks it should). Worth checking whether `transport`'s
`modules.load` token expansion (`auth net protocol io.unix io.ip ui
format.yaml transport devmod`) actually pulls in `base.base32.*` the same
way `proxy`'s token set does, rather than assuming whitelist presence implies
loaded — those are two different mechanisms (`base.load_modules` /
`base.load_code` vs whitelist regen via `bin/dev/dep-graph`).

add this to the acceptance criteria: (5) root-cause and fix why
`base.base32.decode` is unavailable in transport's `%code` at call time,
confirm via a fresh live rotation that `transport.cmd.cred-rotated` no
longer throws `undefined value as subroutine reference`.

## signatures note

do NOT manually write or edit signature lines. do not add stub
signatures to new files.

#,,.,,..,,..,,,..,...,,,.,,,,,...,,,.,...,.,,,..,,...,...,...,.,.,.,.,,..,...,
#JGZOCWOS4GQKSKKBLC34FUTLMSMG3BMFVBNRUZ7MIUO6AM4HNNUP63LCPVHPA4NWBRQZZJ3UBV4ZS
#\\\|AJKW7HUM3E7WQYWDPE3TWN67PV6TKBYU3I42RIL4VBKL7DM2QVW \ / AMOS7 \ YOURUM ::
#\[7]6LQ6IP7ROTHMN5WNUN6BUOVSBJOXUFUXYQFRDODWYBZHFLTQ7MCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
