---
name: topic-zenka-name-routing-modes
description: per-zenka routing_mode config (default contact-oldest, not group) + session-scoped admin override commands (group-next/oldest-next/idle-next/reset-next) to resolve bare-name routing ambiguity; idle-longest doubles as implicit worker-pool load balancing
metadata: 
  node_type: memory
  type: vision
  originSessionId: 441e75cb-3feb-4f58-b8c1-d172ab305359
  modified: 2026-07-22T13:31:14.778Z
---

Design proposal, written up as `data/tasks/zenka-name-routing-modes.md` in
the repo (read that file for full detail — this is just the pointer +
gist).

Bare-name (no subname) zenka routing currently has exactly one resolution
policy: fan out to every live session registered under that name
("group mode", in both `base.handler.command.route_to_target` and
`base.protocol-7.command.send.local`). That's correct for intentional
multi-instance broadcast (X-11 concurrent instances, web-browser multi-window
waypoint fan-out via subname groups), but there's no way for a zenka's setup
to declare a *different* policy when unqualified fan-out isn't wanted.

Surfaced via a real incident: `web` (meant as a singleton) ended up with
multiple live sessions because its `max_concurrency` gate was inert (see
[[feedback-v7-zenka-startup-config-placement]]) — bare-name routing then
fanned a request/reply STRM command out to all of them, and two replies
collided into the one waiting consumer, corrupting the response.

**Proposal**: new top-level `zenka-startup.v7` key `routing_mode`, same
reliability tier as `max_concurrency`/`max_subname_concurrency` (declared
once, enforced consistently):
- `group` (default, current behavior) — fan out to all.
- `oldest-first` / `newest-first` — deterministic single-instance pick.
- `idle-longest` — route to whichever live session was least recently
  contacted. This is the interesting one: start N interchangeable worker
  instances (e.g. a template-parser pool) under one bare name with no
  subname coordination, and bare-name routing alone becomes implicit
  round-robin load balancing across the pool for free.

**Scope is narrower than "any multi-instance name"**: deliberate temporary
twin instances (`v7.restart :twin: httpd`-style zero-downtime handover via
`v7.zenka.cmd.restart_concurrent` / `drain-instance`) already work correctly
today — the old instance gets `unset-initialized` on cube, and
`route_to_target`'s existing initialized-check already excludes it from
bare-name fan-out with no routing_mode involved. routing_mode is only needed
for *unplanned* multi-instance (a concurrency-gate hole letting a second one
through with no handover-pair relationship, as happened here). Any
`oldest-first`/`newest-first`/`idle-longest` resolver must compose with the
existing draining/initialized filter, not duplicate or bypass it.

**Default resolved to `contact-oldest`, not `group`**: verified
`resolve_group_sids`/`resolve_primary_sid` (every real multi-instance case —
X-11, web-browser waypoints) never use bare-name group-mode at all, they
resolve explicit subname-scoped sid lists themselves — so there's no known
legitimate consumer of unqualified group-mode fan-out today, and changing
the default has no known blast radius. `contact-oldest` over `idle-longest`/
`newest-first` as default because it fails *inertly* (spurious duplicate
sits unused, inspectable) rather than *actively* (routing live traffic to
the duplicate, masking it as "working").

**Admin override, not protocol syntax**: considered inline call-site syntax
(`web:.subname` etc.) to force a mode per-call; declined — no real caller
needs it (see above) and it'd be a permanent, universal wire-grammar
addition. Instead: session-scoped `cube.cmd.*`-style commands, individually
permissioned via `access.cmd.usr.*` — `group-next`/`oldest-next`/`idle-next
<name>[[subname]]` arm a one-shot override, `reset-next` cancels it. A
`:single:`/`:next:`/`:keep:` prefix switch controls consumption (match-gated
single-use / literal-next-regardless / sticky-until-reset), plus a short
auto-expiry independent of that so a forgotten `:keep:` can't silently apply
to an unrelated later command.

**Client self-service routing preference: declined entirely**, even as
config opt-in. Unlike `cube.cmd.select-strm-mode` (self-preference, blast
radius = caller only), a client choosing routing mode for *another* zenka's
name is routing authority over a third party — an ordinary caller could
otherwise force this exact incident's collision on purpose. Skip the
trust-boundary rather than gate it: target's declared `routing_mode` is
authoritative, only the permissioned admin family above can override it.

**Independent complementary fix**: `base.strm.local.register` unconditionally
clobbers `<base.strm.local>->{$cmd_id}` with no check for an already-active
unclosed stream — add a guard there (loud log + refuse second registration).
This is the only correct detection point (upstream, the fan-out split
already happened and each route is individually valid) and would have made
this incident one log line instead of silent corruption. Closes the
symptom; routing_mode closes the cause.

Open questions (see task file): where "last contacted" time lives per
session; whether routing_mode/admin-override should be settable *within* a
subname group too; `group-next` etc. naming vs. `next.group` dot-namespaced
alternative (bikeshed only).

#,,,.,,,.,,,.,.,.,...,,.,,,,,,,,.,...,...,,..,..,,...,...,..,,,.,,,,.,.,.,,..,
#KNVHI5LGWOA75ODD3WS3MHN62V4GFE63AKLCSPZEZJIYA4A4MT6ON3KKKCB6LMCY6MPJ36P4QEQFC
#\\\|2LLZMEGJKYT6USY6LFW6SCKAAWVTCFBR7OMB26VMMUVZDSZCLR4 \ / AMOS7 \ YOURUM ::
#\[7]DCVLENG642UNCCHAEHAIV7DL7DS4M2T7WJEJC3ETLY3JQAAIC2BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
