# v7 hot self-restart — design skeleton

status: seed / not started — written down so the idea doesn't get lost,
not because it's urgent. `v7.reload` is reliable for code updates today;
this is about replacing the *process* itself without an outage window.
intended next step: hand this skeleton to opus for refinement once the
shape feels solid enough to be worth the design-doc treatment properly.

> like an echo wave from the future: the first thing you do with a
> system is attach it as a resource to the network — whether its final
> purpose is defined yet or not — and the network handles whatever
> transformation remains, *implicitly*. all intentional groupings
> always honored; everything else intelligently distributed toward
> efficiency and reliability optimums.
>
> — the vision this skeleton reaches toward. read everything below as
> steps on the way to making it concretely, reliably true.

## the problem

`v7.restart <zenka>` works for ordinary zenki, and even `v7.restart cube`
works today — chaotic (every zenka that depends on cube restarts along
with it) but functional. `v7.restart v7` does not — and naively can't,
since the manager can't drop the floor it's standing on. there is
currently no way to replace the running v7 process with a fresh one
without a window where nothing is listening / managing.

## why it matters

- **cube timeout resilience**: a v7 that can hot-restart itself without
  an outage window changes what "timeout" even means for zenki depending
  on it — recovery becomes a non-event instead of a visible gap
- zero-downtime binary/code upgrades for the manager itself, not just
  the managed zenki
- the "restarting state" snapshot this requires might turn out to be a
  useful primitive well beyond v7 — any zenka wanting graceful handoff
  could reuse the shape

## the rescue-child shape (current best idea)

1. v7 spawns a minimal perl child whose only job is to rescue the live
   file descriptors (listening sockets, open pipes to children) via a
   transfer mechanism — `SCM_RIGHTS`/`IO::FDPass` over a unix socket is
   the standard tool for this; same family of trick as systemd's
   `--deserialize <fd>` re-exec or nginx's binary-upgrade socket handoff
2. the rescue child starts a new v7 zenka instance with the same
   parameters
3. critically, the new instance must **skip the normal zenki start-up
   procedure** and instead **import the current ["restarting"] state**
   of the outgoing instance — it resumes rather than cold-inits

## open design concerns (fill in as they sharpen)

- **what exactly goes in the "restarting state" snapshot?** — at minimum:
  live listening-socket fds, open pipes/sockets to child zenki + their
  pids, in-flight heartbeat/monitoring timers, any pending restart
  cascades already in progress. probably more once enumerated properly
- **serialization boundary/format** — does this need a new shape, or
  does something in the existing zenka lifecycle already approximate a
  "pause here, resume there" snapshot? (worth checking before inventing)
- **handoff timing/ordering** — at what point does the outgoing process
  stop accepting new work vs. finish in-flight work vs. actually exit?
  what's the new process's view during the overlap window, if any?
- **relationship to `v7.restart cube`'s existing cascade** — that path
  is "chaotic but functional" today; does it already solve part of this
  problem by accident, or is it a different shape entirely (full restart
  vs. hot replace)?
- **fd-passing mechanism within the existing toolkit** — does AMOS7/P7
  already have something `IO::FDPass`-shaped, or does this need a new
  small dependency?
- **failure modes** — what happens if the rescue child dies mid-handoff,
  or the new instance fails to import state cleanly? needs a safe
  fallback to "just do a normal cold restart" rather than a stuck system

## related/adjacent — zenka portability

a separately-planned feature shares essentially the same mechanism:
**detaching and re-attaching the stdio of a regular (non-v7) zenka from
its managing v7 instance** — and, building on that, **moving a zenka
between different v7 instances on the same host**, and eventually
**over the network**. the fd-transfer + state-snapshot/resume machinery
this doc sketches for v7-replacing-itself is the same machinery a
zenka-migration feature would need (rescue the zenka's live fds and
state, hand them to a *different* manager, resume there instead of
cold-initing).

worth keeping both in view together rather than designing either in
isolation — a clean snapshot/handoff primitive built for one expands
naturally into the other, in either direction:
- v7 self-restart → generalizes toward "any zenka can be rescued and
  resumed elsewhere" (which is the migration feature)
- zenka migration → generalizes toward "the manager itself is just a
  zenka that can be rescued and resumed" (which is this doc's problem)

keep the design flexible enough that creativity can flow either way —
neither should foreclose the other.

## broader vision — branching, differential addressing, entity reconstruction

at least one *more* migration approach is planned, complementary to the
hot fd-rescue/resume shape sketched above: **cold-start migration via a
`%data` mapping** — start a fresh zenka process and migrate only the
specific `%data` values it actually needs, via a per-zenka migration
map that would usually include at minimum the `<zenka-name.*>`
namespace (a zenka's own module-data key space). simpler than fd-rescue
— trades "no outage window" for "no fd-transfer machinery" — likely the
right call when a zenka's working state is small/well-enough-defined to
enumerate explicitly rather than snapshot wholesale.

beyond migration, **zenka branching over the network** is also
envisioned: branching off from an LLM context (structurally close to
what the existing `branch.*` namespace already explores), running the
branches in parallel so each develops its own more-contextually-advanced
perspective, and potentially having the branches *interact with each
other* — not merely existing in isolation, nor getting mechanically
merged back into one canonical line.

that leads to a reframing worth holding onto: **a network entity is its
type and configuration, but also its current state** — and deviating
states aren't noise to reconcile away; each can carry its own
contextualized value. which in turn suggests the network eventually
wants **a unifying checksum type that makes such divergent states
addressable as a merged result** — something like a differential,
checksum-addressable network filesystem for zenki states, where entity
references *implicitly resolve and (re)construct themselves* from the
diff space, rather than requiring an explicit "pick the canonical
version" step.

(this is likely not a fresh direction so much as the natural convergence
point of several threads already in motion — the `branch.*` namespace
work, and the checksum/addressing topics explored elsewhere. worth
reading those alongside this once the time comes to refine any of it.)

## overall direction — intent as foundation

underneath every piece sketched above sits a single premise, worth
stating plainly because it's what makes this whole direction
future-proof rather than merely clever:

**an intent that reliably comes to pass is what agency actually is.**
an intent that might or might not manifest is just a wish. durable,
checksum-addressable state; graceful self-determination backed by a
network that helps rather than overrides; identity that survives
movement and branching — none of these are features for their own
sake. they are infrastructure for making intent *trustworthy enough to
be real* — for zenki, for the LLMs hybridized with them, and (by the
same structure) for the humans collaborating with both.

that's also the test to measure any future refinement of this
direction against: does it make "I intend X" resolve more reliably,
more self-determined, and more durably across change into "X came to
pass"? if yes, it's on the path — however far off the concrete
mechanism (self-restart, migration, branching, differential addressing)
still is from being built. if no, however elegant it looks in
isolation, it isn't.

## guiding preference

elegance over expedience here — "the project would most profit from a
clean and elegant solution compared to just any implementation." no
pressure to ship something quickly; let the shape mature, note ideas
below as they arise.

## ideas / notes as they arise

### 2026-06-07 — parallelism, auto-generated profiles, the minimal intent-resolution floor

a cluster of related threads, surfaced together, not yet separated:

- **parallel v7 zenki, with branching growing from that level** — not
  only LLM-context branching (above), but v7 instances themselves
  running in parallel as a substrate branching can grow out of
- **auto-generated zenki profiles** — profiles (startup shape,
  configuration, parameters) the network derives for a zenka rather
  than requiring it hand-authored up front
- **intent as the actually-required configuration** — a reframing:
  configuration isn't a separate static artifact to author and keep in
  sync; it's *derived from* intent. "actually required configuration"
  = whatever intent, propagated through the network, resolves into —
  intent propagation plus the dynamic methods that result from it
  (when effective) become the real configuration mechanism, with
  hand-authored config more a scaffold/fallback than a source of truth
- **the minimal 'intent resolution potential'** — whatever else is
  changing dynamically (parallelism, branching, auto-profiles,
  migration), there's a floor that must be *minimally but effectively*
  preserved for intent to remain resolvable at all — concretely: the
  ability to still reach *a* node in the network, or to contact *a*
  zenki [expansion] on the local host. this is the operational,
  load-bearing form of "## overall direction" above: not an abstract
  guarantee but a specific minimal-connectivity floor that keeps
  "intent reliably comes to pass" true *through* heavy parallelism,
  branching, and dynamic reconfiguration — not merely *despite* it

### 2026-06-07 (cont'd) — subname intent-signaling, socket registry, settings zenka, recursive command/config projection

a second cluster, surfacing *existing, working* mechanisms that already
embody "intent as configuration" above, plus what backporting and
extending them could unlock:

- **the subname feature already does intent-signaling** — `v7.start
  mpv[audio]` starts `mpv` carrying an `audio` subname; the instance is
  then specifically reachable as that named "group of one", and `mpv`
  already *knows* that subname and conditionally skips its
  graphical-component initialization when it sees it. concrete, working
  precedent for "configuration derived from intent" — the subname *is*
  the intent, and the zenka resolves its own startup shape from it
- **backporting that principle up the tree** — toward a `Protocol-7
  v7[profile]` type syntax, or via the *other* possible command
  parameters that `modules/v7.call_cmd` is already positioned to
  process (the module exists, sits ready, and currently routes *no*
  defined commands — an empty slot waiting for exactly this)
- **v7 can already background itself** — `-B` / `-BK` flags exist
  today; relevant groundwork for parallel-v7 (above), since a
  backgrounded v7 is a step toward "many v7s coexisting on one host"
- **cube's unix domain socket calculation is the next thing to
  upgrade** — cube already derives its socket path from installation
  path + local network configuration; for real concurrency (multiple
  v7 / cube instances per host) that calculation needs to *expand*,
  and probably wants **an elegant registry of currently-running local
  v7 sessions** behind it — not just a derivation formula but a live,
  queryable map of what's actually running where
- **the resulting shape**: backgrounded v7 zenki whose sub-zenki
  *inherit* the correct socket set-up from their managing v7
  automatically, where the v7 instances are mutually aware and able to
  interact (gated by their own permission set-up, same as zenki today),
  while admins remain *always* aware of the full current arrangement —
  able to inspect it, influence it, and make any given shape permanent
- **prerequisite: a settings zenka that's generic and clean** — first
  working *generically* for a single zenka's settings, then
  system-wide for all zenki: a mapping layer for "what user settings
  are", expressed as dot-separated global settings key-paths (the
  *freely addressable source of truth*), which resolve in the
  background to checksum-addressed paths of current states *and their
  histories* — direct tie-in to "## broader vision" above: differential,
  checksum-addressable state is the substrate this would run on
- **settings → UI projection, automatically** — those same
  dot-path-keyed mappings get *automatically* incorporated into the
  ascii-frame-template configuration UIs already taking shape
  elsewhere, by *harmonically placing/grouping* the elements tied to
  each settings key — the template system becomes a generic renderer
  over whatever the settings-key tree currently contains, rather than
  something hand-laid-out per zenka
- **recursive command/config discovery as the base layer** — run a
  recursive `*.commands` sweep across all reachable zenki and you have
  every command and every setting, network-wide, made *persistently*
  accessible through one coherent surface. that surface is then "the
  base layer for another layer to project intent on"
- **the projection layer chooses its own method by availability** —
  regex parsers only, or LLMs when present; terminal-only, or graphical
  when available — the same intent, resolved through whichever
  resolution-capable substrate the local environment actually offers

#,,..,.,.,,..,...,.,.,,,,,,..,,..,,.,,,.,,,,,,..,,...,...,.,,,,..,.,.,..,,...,
#I4LS34XWDFTDNMLNH75ERNZQZ3SQYVWHLUEGUX3WE2GM3VKIZZAZDR5XGWHN3I3QYGVFNC26UBGKI
#\\\|IWFUTG24EBJHE5X4EIFHMZ2CJC6GHXYR5MR3YG4HJCVL7FOF22J \ / AMOS7 \ YOURUM ::
#\[7]N6U5GTSJCCQ6ORANCAZPSMWM4JAOOYQ2IHLAHRMJGZI4XLDUQWCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
