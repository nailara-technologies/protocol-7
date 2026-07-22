## task: configurable routing-mode for bare-name zenka addressing

### origin

surfaced while chasing a jobsite/web sync corruption: `v7`'s `max_concurrency`
gate for the `web` zenka was silently inert (config value sat inside the
`: v7-init :` block of `zenka-startup.v7`, so it only ever became a variable
in each spawned instance's own init namespace, never reaching
`<v7.start_setup.zenki.config>`, the hash the gate actually reads — top-level
placement, matching `cube`'s file, is what makes it real. `v7.reload config`
also does *not* re-parse `zenka-startup.v7`; only `v7.reload all` / `init`
re-runs `v7.init_start_setup` and picks up an edit). that let `web` — meant
as a singleton — accumulate several live sessions under one name.

once that happened, bare-name routing (`base.handler.command.route_to_target`'s
group-mode branch, and the structurally-identical branch in
`base.protocol-7.command.send.local`) fanned every `web.jobs-data` request out
to *all* matching sessions. each fan-out target gets its own correctly-scoped
STRM route (`base.route.add` mints a fresh per-target `cmd_id`), so the reply
transport itself isn't broken — but every route created in one fan-out call
shares the *same source-side* `cmd_id` (the one waiting httpd consumer), so
two replies for one nominally-single-reply request collided into the one
registered STRM consumer, splicing both streams' bytes together.

### why this stayed latent so long

the historically usual case of unplanned concurrent zenki sharing a name was
a human at an interactive session issuing a bare-name command and simply
*seeing* multiple replies land at once — unambiguous, self-diagnosing, and
already a standing reminder that direct numerical sid addressing was the
only real disambiguation option for a name (or subname) with more than one
live session. that friction already made the missing "contact whichever is
oldest" convenience apparent well before this incident. what was new here:
a machine consumer (httpd's STRM relay) sitting on the other end with a
hard single-reply assumption and nobody watching the raw stream — the same
ambiguity that a human would immediately notice and route around manually
instead surfaced as silent byte-level corruption in `jobs.json`.

### this is not a defect in group-mode itself

subname already gives explicit, deliberate disambiguation (`web[eth0]` vs
`web[eth1]`), and unqualified fan-out is the *correct* behavior for cases
like the multi-window waypoint broadcast (`5de162b6e`,
`base.zenki.resolve_group_sids`) — fire-and-forget, no reply aggregation,
intentionally hitting every instance sharing a subname group.

the actual gap: bare-name (no subname) routing has exactly **one** resolution
policy — fan out to everyone currently registered under that name — with no
way for a zenka's own setup to declare a different one. there's no equivalent
of `max_concurrency` / `max_subname_concurrency` for *routing disambiguation*,
even though those two prove the pattern works: a value declared once in
top-level zenka-startup config, read reliably regardless of timing or how
many instances happen to be live.

### proposal

new top-level `zenka-startup.v7` key, e.g.:

```
routing_mode = group             ## current behavior : fan out to all [ no longer the default -- see below ] ##
routing_mode = contact-oldest    ## deterministic single pick, earliest instance [ the default when absent ] ##
routing_mode = newest-first      ## deterministic single pick, most recent instance ##
routing_mode = idle-longest      ## route to whichever instance was LEAST recently
                                 ## contacted -- implicit round-robin load balancing
```

`idle-longest` is the interesting one: start N identical instances of a
worker zenka (e.g. a template-parser pool) with no subname coordination
needed between them at all — as long as they're safe to contact in any
order, bare-name routing alone turns them into a load-balanced worker group
for free. requires tracking last-contacted time per session for a given
zenka name (comparable bookkeeping to existing heartbeat/status tracking,
just keyed for this purpose).

### where it plugs in

both fan-out sites resolve `@send_sids` from `$data{'user'}{$target_name}`
before their `##[ PROCESS \ GROUP MODE ]` loops:

- `modules/base.handler.command.route_to_target`
- `modules/base.protocol-7.command.send.local`

a shared resolver reading `routing_mode` from
`<v7.start_setup.zenki.config>->{$target_name}` (default `group` if absent,
for backward compat with every zenka that doesn't opt in) would collapse
`@send_sids` down to one entry for `oldest-first` / `newest-first` /
`idle-longest`, leaving `group` untouched. **must land at the top level of
zenka-startup.v7, not inside any `:`-headed section** — the config-placement
gotcha above is exactly the trap to avoid re-introducing here.

**Live-verified 2026-07-22, `idle-longest` case**: same two `mod-test`
instances (PIDs 19511/19560), config flipped to `routing_mode =
idle-longest` (top level), `v7.reload all` (re-parses config *and*
re-pushes to cube's mirror via `push_routing_mode` in one step — no
separate push needed). Four successive `mod-test.cur-pid` calls returned
`19511, 19560, 19511, 19560` — clean alternation between the two live
instances on every call, confirming least-recently-contacted resolution
and the "free worker-pool load balancing" design goal both work as
intended. Both non-`group` default paths (`contact-oldest` and
`idle-longest`) are now live-confirmed end to end.

### scope narrower than it first looks: compose with the existing drain/twin mechanism, don't duplicate it

deliberate temporary multi-instance ("twin") already exists and already
works: `v7.zenka.cmd.restart_concurrent` opens a tracked handover pair
(`<v7.handover.pairs>`), grants the new instance a `concurrent-handover`
expansion slot past `max_concurrency` (see the `is_handover` branch in
`v7.zenka.cmd.start`), and `v7.zenka.cmd.drain-instance` marks the old
instance `draining` + sends `unset-initialized` to cube for its `cube_sid`.
`route_to_target`'s existing `##[ CHECK INITIALIZED ]#` section already
filters `@send_sids` down to only initialized sessions for non-`v7` senders
— so during a zero-downtime `v7.restart :twin: httpd`-style handover,
bare-name group-mode fan-out *already* narrows to just the new instance
once the old one is marked uninitialized. no routing_mode change needed for
that case; it's a solved, deliberate, tracked exception to `max_concurrency`,
not an instance of the bug this task is about.

what routing_mode is actually for: **unplanned/accidental** multi-instance —
two (or more) sessions sharing a name with no handover-pair relationship
between them at all (the `web` incident: no `<v7.handover.pairs>` entry, no
`draining` flag, just a concurrency-gate hole letting a second one through).

implication for implementation: any `oldest-first` / `newest-first` /
`idle-longest` selection must compose with the existing initialized/draining
filter rather than duplicate or bypass it — skip `draining` sessions the same
way group-mode already implicitly does via the initialized check, don't
reinvent handover-awareness inside the new resolver.

### default mode: contact-oldest, not group

**Live-verified 2026-07-22** on `mod-test` (no `routing_mode` declared,
so running purely on the new default): started two bare-name instances
(`v7.start mod-test` twice, no subname), confirmed both `online` via
`v7.list zenki mod-test`. `mod-test.heart` produced exactly **one** reply
despite two live sessions; `mod-test.cur-pid` called twice returned the
*same* PID both times. Cross-checked via `v7.pid-instance <pid>` →
`v7.list zenki <instance>`: the answering PID belonged to the instance
from the *first* `v7.start mod-test` call — the second instance stayed
`online` but never answered a single request. Confirms `contact-oldest`
is actually live as the default and correctly resolves to the earliest
instance, not just "sticky to whichever" and not the old group fan-out.

verified `base.zenki.resolve_group_sids` / `resolve_primary_sid` (the
resolvers behind every current legitimate multi-instance case — X-11
concurrent instances, web-browser waypoint fan-out) never use cube's raw
bare-name group-mode at all: they resolve an explicit sid list scoped by
subname themselves and dispatch to each directly by sid. so plain,
unqualified, no-subname group-mode fan-out has **no known legitimate
consumer today** — every real multi-recipient case already goes through
explicit subname-based resolution instead. that means changing the
*default* (absent a `routing_mode` line) away from `group` has no known
blast radius on existing behavior.

recommendation: default to `contact-oldest`, not `group`, and not
`idle-longest`. reasoning:

- defaulting to `group` requires every zenka's setup to remember to opt in
  to get the safety — the exact same "forgot to add the line" shape as the
  `max_concurrency`-in-the-wrong-section bug this task originated from. a
  default should carry the safety itself, not depend on remembering to ask
  for it.
- between the two safe candidates, `contact-oldest` fails *inertly*: a
  spurious accidental duplicate just sits there unused and inspectable via
  `v7.list zenki <name>`. `idle-longest` (or `newest-first`) would instead
  actively route live traffic to the spurious instance — masking the
  duplication as "working fine" instead of surfacing it as dead weight,
  which is the same silent-until-it-corrupts-something failure mode this
  whole incident was. `idle-longest` is excellent as an explicit, deliberate
  opt-in for a real worker pool; it should never be what a zenka gets by
  silently doing nothing.

### explicitly declined: protocol-level address syntax for mode override

considered inline call-site syntax (e.g. `web:.subname`, `web[*]`) to force
group-mode (or another mode) for a specific call, overriding the target's
configured `routing_mode`. declined in favor of the admin command family
below, for two reasons: (1) every real multi-recipient use case already
goes through explicit subname resolution + per-sid dispatch
(`resolve_group_sids`), reusing the pattern that commit `5de162b6e`
deliberately chose over inventing a parallel discovery mechanism — there is
no current caller a new syntax would actually serve; (2) new wire-grammar
delimiters are permanent and universal (every future parser, logger, and
person reading raw traffic has to know about them), where a set of ordinary,
individually-permissioned commands is not.

### admin override: session-scoped one-shot mode commands

instead: a family of ordinary `cube.cmd.*`-style commands, permissioned like
any other command (`access.cmd.usr.*`) — so the capability to override
routing at all requires an explicit grant, not universal availability:

```
group-next <name>[[subname]]     ## arm: next matching command uses group-mode ##
oldest-next <name>[[subname]]    ## arm: next matching command uses contact-oldest ##
idle-next <name>[[subname]]      ## arm: next matching command uses idle-longest ##
reset-next                       ## cancel any currently-armed override, unused ##
```

usage example: `group-next mpv` then `mpv.get-pid` returns every player's
pid instead of just one, for that one call.

**consumption switch**, given as a prefix param so the arming command itself
declares how it un-arms (resolves the "match the target, or not? auto-expire,
or not?" question as a caller-chosen parameter instead of one hardcoded
policy):

- `:single:` (default if omitted) — consumed by the first subsequent command
  whose target actually matches `<name>` (and subname, if given); anything
  else sent first leaves it armed and unconsumed.
- `:next:` — consumed by the literal next command sent, regardless of its
  target — for when the admin already knows exactly what's coming.
- `:keep:` — stays armed across multiple commands until an explicit
  `reset-next`; for an extended debugging session issuing several related
  calls to the same name in a row.

all three (plus `reset-next`) are one underlying session-state slot —
`$session->{'pending_routing_override'} = { mode, name, subname, consume }`
— set/cleared at the fan-out resolution point in `route_to_target` /
`send.local`, not three separate mechanisms. should also carry a short
auto-expiry (a few seconds; same session-timer pattern as drain timeouts)
independent of the consume policy, so a `:keep:`-armed override from a
distracted admin session can't silently apply to an unrelated command typed
much later — `reset-next` covers the deliberate cancel, the timeout covers
the forgotten one.

**Live-verified 2026-07-22**: `group-next mod-test` (persistent config set
to `newest-first` as baseline) armed correctly
(`armed : group ..:. mod-test [:single:, expires in 13 seconds]`), and the
very next `mod-test.heart` in the *same* `nshell` session produced two
replies — confirmed via the zenka log too (`routing_mode 'newest-first' :
'mod-test' : 2 sids ..:. resolved to <sid>` on every call *except* the one
right after arming, which correctly skipped the log line and fanned out
instead). The following `mod-test.cur-pid` in the same session correctly
reverted to a single PID, confirming one-shot consumption and clean
revert to the persistent config.

**Testing gotcha worth recording**: the override is session-scoped by
design, which means arming via one `p7c` invocation and testing via a
*separate* `p7c`/`nshell` invocation can never work — each one-shot `p7c`
call is its own distinct connection that disconnects immediately after its
reply, so the armed session is already gone before the next command (a
different session) ever arrives. Testing this family requires a single
continuous session (`nshell`) issuing the arm command and the consuming
command back to back, not two separate client invocations. Initially
misread as a bug for exactly this reason before re-testing correctly.

### explicitly declined: client self-service routing-mode preference

considered letting an ordinary calling zenka set its own persistent
preferred resolution mode for names it calls (paralleling
`cube.cmd.select-strm-mode`, which lets any session toggle its *own*
reply-transport behavior at runtime with no special gating). declined,
even as a config opt-in: `select-strm-mode` only affects the caller's own
outgoing traffic — blast radius is the caller itself. a client-side routing
preference would instead affect how some *other* zenka's name resolves,
which is routing authority over a third party, not self-preference — an
ordinary or semi-trusted caller could otherwise force exactly this
incident's collision on purpose (or accidentally probe how many live
instances some other name has). rather than carefully gate that surface,
skip it entirely: the target zenka's own declared `routing_mode` is
authoritative by default (it's the party that knows its own safety model),
and the only override path is the explicitly-permissioned, temporary,
session-scoped admin family above — never a standing client preference that
could silently conflict with what the target declared safe for itself.

### subname is addressing only, never a trust domain — a caution for the admin-override permission model

subname is a pure routing/grouping convenience layered on top of a shared
zenka name; it carries **no implied trust equivalence** between the
instances sharing that name. a zenka literally named `user` with instances
addressed as `user[taeki]`, `user[claude]`, `user[root]` must be reasoned
about with exactly the same severity as if those were three entirely
distinct top-level zenka names (`taeki`, `claude`, `unix-root`) — the shared
bare name is an artifact of addressing convenience, not evidence they're the
same trust principal.

this bites directly on the `-next` admin family above: a permission grant
phrased against the bare name (`group-next user`, no subname) implicitly
reaches *every* subname underneath it in one grant — simultaneously handing
override power over however many unrelated trust principals happen to share
that name, in a way that's easy to mis-reason-about as "just the user zenka"
rather than "this grant spans N distinct identities." the access-control
model must force grants and severity judgment to be evaluated per resolved
`name[subname]` pair wherever subnames can represent meaningfully distinct
principals, never discounted just because the bare name is shared — this
applies generally to `access.cmd.usr.*` wherever subnames appear, not only
to this admin-override family, but it's especially sharp here since the
whole point of these commands is granting *override power*, not just
read/reply access.

### open questions

- where "last contacted" time lives for `idle-longest` — per-session field
  on the cube-side session table (`$data{'session'}{$sid}`), updated at each
  fan-out resolution point, is the natural place; needs to survive session
  reconnects the same way other session state does.
- whether `routing_mode` (and the admin override family) should be settable
  per-subname-group too (a worker pool that itself uses subnames for
  something else, e.g. sharded by input type, might want `idle-longest`
  *within* each subname group rather than globally per bare name).
- naming bikeshed only: `group-next` / `oldest-next` / `idle-next` /
  `reset-next` as flat top-level commands vs. a dot-namespaced family
  (`next.group` / `next.oldest` / `next.idle` / `next.reset`) — no
  functional difference, whichever reads more consistently with existing
  `cube.cmd.*` naming conventions.

### complementary, independent fix: duplicate-slot guard in base.strm.local.register

separate from all of the above (this closes the *symptom* silently, the
routing_mode work prevents the *cause*): `modules/base.strm.local.register`
unconditionally overwrites `<base.strm.local>->{$cmd_id}` with no check for
whether that slot already holds an active, unclosed stream. add a guard —
if `exists <base.strm.local>->{$cmd_id}` and that entry hasn't reached
`on_eof`/cleanup yet, log it loudly (this is the anomaly, not routine
traffic) and refuse the second registration rather than silently clobbering
the first watcher. this is the *only* correct place to detect the
collision: by the time `base.handler.command`/`process_reply` is dispatching
STRM packets, the fan-out split already happened upstream and each route is
individually valid — `base.strm.local.register` is the one place a
receiving zenka has a single per-`cmd_id` terminal slot representing "the
one reply I'm expecting," so a second claimant on an already-occupied slot
is unambiguous evidence of this failure mode regardless of what upstream
cause produced it (this bug, or anything else, ever). would have turned
this entire incident into one loud log line instead of a silent
byte-corruption mystery.

#,,.,,,,.,.,,,,,.,,,,,,..,,,.,,.,,.,.,..,,,,,,..,,...,...,,.,,,,.,,,.,.,.,,.,,
#JIOFRYHLAXRDC2PVJD7MINBMXDJL7WSS3B3HW5PGTACQS5RW7W23PJPO4FHH7WMR6D56ENZZZ7YLC
#\\\|VX7AEGXZTC4HEOHF6JHBMO5MGPUE6GTXEUJZURK2U3FBKDQ4DKX \ / AMOS7 \ YOURUM ::
#\[7]NUCNAFNNASK4SYXLV26ESR4JHBCTRJPCDXLJTMCWTTTMHG2SYABQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
