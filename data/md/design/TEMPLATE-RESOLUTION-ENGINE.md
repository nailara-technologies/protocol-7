# template resolution engine — universal organizing structure

## the template tree is not a UI concept

the template tree is the fundamental organizing structure of the entire
system. every other concept — UI layout, application, zenka, zenka group,
data tree, STRM channel, cube network — is a particular perspective on the
same tree, viewed from a different angle.

```
UI layout          → a collapse point with a renderer adapter
application        → a named subtree with a registered collapse point
zenka              → a node that resolves slots and emits typed data
zenka group        → a subtree with shared resolution context
data tree          → leaf nodes, directly addressed
STRM channel       → a slot with continuous resolution, never finally collapsed
cube network       → the address space the tree is embedded in
```

none of these categories compete or have priority over the others. they are
views into the same structure. a STRM channel is not a special case of the
template engine — it is a slot whose resolution stays perpetually open. a
zenka group is not an organizational concept bolted on top — it is a subtree
boundary with shared context.

the holographic cube analogy is exact: same underlying geometry, different
projection depending on where you stand. the tree transcends any local or
categorical boundary between UIs, applications, zenki, zenka groups, data,
and stream organization.

---

## slot resolution chain

a template is a tree of named slots. each slot resolves through a typed
chain, evaluated in order until a value is returned:

```
slot resolution order:
  1. data tree key        → direct address, zero cost, synchronous
  2. static assertion     → exact match on context key, synchronous
  3. regex assertion      → pattern match, synchronous
  4. code_ref             → arbitrary Perl sub, receives full context hash
  5. zenka query          → async command to any zenka, returns typed data
  6. sub-template         → recursive resolution, same engine
  7. fallback             → default value or empty
```

the first type that produces a value wins. the remainder are not evaluated.
cheap synchronous types short-circuit before expensive async types fire.

### slot declaration

```yaml
slot: jobs.active_count
  source:
    data_key: jobs.pipeline.active          # try data tree first
    zenka: jobsite.active_count             # fallback to zenka query
    fallback: 0

slot: gpu.sparkline
  source:
    zenka: coding.gpu_sparkline             # local zenka, unix socket
    cache: { ttl: 1s, invalidate_on: STRM:X-11.gpu_load }

slot: current_user.greeting
  source:
    code_ref: |
      my $ctx = shift;
      "hello " . $ctx->{'session'}{'user'};
```

### context hash

every assertion and code_ref receives the full context hash at resolution
time. this is the contract between the engine and every hook:

```perl
{
    session   => { user, zenka_name, transport, ntime },
    request   => { domain, url, method, headers, mime_type },
    auth      => { has_session, credential_slots },
    transport => { type, quality, loss_rate },
    data      => { ... current data tree snapshot ... },
    env       => { platform, renderer_type, tty_cols, tty_rows },
}
```

the context hash schema is stable. code_refs written today work unchanged
when the engine grows new resolution tiers. new fields are additive.

---

## template selectors

a template selector is itself a template-like node. it resolves not to data
but to a target template name. the resolution tree can branch on content,
context, or computed assertions at any depth:

```
root selector
  assertion hooks (evaluated in priority order):
    regex    /stepstone\.de/         → jobsite.template
    regex    /github\.com/           → code-repo.template
    regex    /\.pdf$/                → document.template
    zenka    credentials.has_session → authenticated.base
    code_ref is_authenticated?       → authenticated.base
    fallback                         → generic.proxy.template
```

the selector resolves to a template name, which may itself contain another
selector. there is no special case — the tree branches as deep as needed.

### assertion hook types

```
static      → exact match on a context key value
              zero cost, synchronous
              example: env.renderer_type == 'gtk3'

regex       → pattern match on any string field in context
              near-zero cost, synchronous
              example: request.domain =~ /stepstone\.de/

code_ref    → arbitrary Perl sub, receives context hash, returns true/false
              synchronous, local only
              example: sub { shift->{'auth'}{'has_session'} }

zenka       → async command to any reachable zenka
              returns true/false or a template name directly
              example: credentials.has_session domain=$domain
                       content-classifier.is_paywalled
                       jobsite.recognizes url=$url
```

multiple zenka assertions at the same priority level fan out in parallel —
all queries fire simultaneously, first truthy response wins. or the selector
can declare `policy: all` to wait for all before deciding.

### timeout and cache policy

```yaml
selector: domain-router
  assertion_policy:
    static:   { timeout: none }
    regex:    { timeout: none }
    code_ref: { timeout: none }
    zenka:    { timeout: 200ms, on_timeout: skip, cache_ttl: 30s }
```

zenka assertion results are cached by default. a STRM subscription can
invalidate the cache when the answering zenka's state changes — credentials
state change triggers re-evaluation of auth assertions automatically.

---

## deferred rendering — no early flattening

### the invariant

**no zenka converts structured data to a string prematurely.**

the template tree stays as a live, typed, structured resolution tree for as
long as possible. it collapses to rendered output exactly once, at the
registered collapse point, when the actual consumer and its renderer adapter
are known.

```
inner zenka     → emit typed data       { type: 'job.result', data: {...} }
middle zenka    → compose, filter       still typed, still structured
v7 / session    → holds the tree        passes inward without rendering
collapse point  → renderer adapter      collapses once, for this consumer
```

any zenka that adds `sprintf` or string concatenation where a data structure
belongs is breaking this contract. the renderer decides how data looks. the
zenka decides what data means.

### why this matters

- the same data reaches a GTK3 card, a TTY tile, an HTML fragment, or
  another zenka's input — all from the same typed emission
- the rendering decision is made with full context (who is consuming, what
  transport, what capabilities) rather than prematurely inside the producer
- the tree remains composable: filters, transformers, and aggregators can
  operate on structure rather than parsing strings

### STRM slots — perpetually open resolution

a STRM-backed slot never finally collapses. the slot remains open, and each
new value pushed by the STRM source re-renders only the affected portion of
the output:

```
slot: gpu.sparkline
  source: STRM:X-11.gpu_load
  → renderer sees a live slot, re-renders on each push
  → the tree never closes this slot
  → other slots in the same template are unaffected
```

this is not polling. the slot is a live subscription. the renderer adapter
handles partial re-render for its specific toolkit.

---

## the template as 3D construct — surface is root

a template is not a flat tree. it is a 3D structure. the root is the
surface — the collapse point, the rendered face. resolution depth extends
behind it:

```
Z=0  surface / root        → rendered output, collapse point, the 2D face
Z=1  composition layer     → slot aggregation, filtering, transformation
Z=2  resolution layer      → code_refs, selector assertions, caches
Z=3  stream branches       → STRM subscriptions, live data feeds
Z=N  data sources          → data tree leaves, zenka query endpoints
```

this inverts the usual tree mental model where root is "deep." in the
template engine, root is shallow — it is the face you see. the leaves are
deep — they are the data sources furthest from the observer.

### the surface is a 2D subcube-hosted matrix

the root of a template is a 2D matrix hosted on a cube face. each cell
in the face matrix is a slot. the resolution chain for each slot extends
inward along the Z axis into the cube interior:

```
cube face (Z=0)
  [ slot A ][ slot B ][ slot C ]
  [ slot D ][ slot E ][ slot F ]
       ↓         ↓         ↓
  Z=1 composition, Z=2 resolution, Z=3 streams, Z=N data
```

STRM channels are permanent tunnels — a direct line from a deep data
source straight to a surface slot, bypassing intermediate resolution layers
because the slot never closes. the stream runs continuously along the Z axis
from source to surface.

### six faces — six collapse points from one cube

a single cube has six faces. each face can host a different template surface,
a different collapse point, a different renderer adapter — all backed by the
same interior resolution tree:

```
face +X   nshell TTY layout        → TTY renderer adapter
face -X   GTK3 desktop layout      → GTK3 renderer adapter
face +Y   httpd JSON API           → JSON adapter (no rendering)
face -Y   web-browser HTML         → HTML renderer adapter
face +Z   remote cube node view    → distributed renderer
face -Z   internal zenka input     → data adapter (no rendering)
```

same data interior. six surface projections. the observer always sees the
surface at Z=0. the resolution depth extends away from them into the interior.
this is the same geometry as `SPAWNABLE-PERSPECTIVE-LAYERS.md` — perspective
layers are different cube face projections of the same data space.

---

## the collapse point — application topology

the collapse point is where the template tree finally renders to output.
its location defines the deployment topology of the application:

```
collapse at v7 local          → monolithic, single node
collapse at session zenka      → thin client, logic on network
collapse at nshell TTY         → terminal application, data from network
collapse at httpd boundary     → web frontend, server-side rendering
collapse at browser zenka      → client-side rendering, data API behind
collapse at remote cube node   → fully distributed, edge rendering
```

**the same template tree, the same zenki producing typed data.** moving
the collapse point outward distributes the application further without
changing any inner zenki. a local monolithic prototype becomes a distributed
multi-node application by pushing the renderer adapter outward.

refactoring deployment topology does not require rewriting business logic.
the data-producing zenki are unchanged. only where the collapse happens moves.

### formal definition

an application in P7 terms is:
```
application = template tree + registered collapse point
inner zenki = services (data producers, typed emitters)
collapse point = application boundary
renderer adapter = UI contract for this consumer
```

---

## renderer adapters

the renderer adapter is the only consumer-specific piece. it maps the
resolved slot structure to the output form for its target:

### HTML adapter
```
string slot       → text node
list slot         → <ul>/<ol> with item template
nested template   → <div> container with child rendering
trigger slot      → <button> or <a> with route-send href
STRM slot         → element with SSE or WebSocket update target
```

### GTK3 adapter
```
string slot       → GtkLabel
list slot         → GtkTreeView or GtkListBox
nested template   → GtkBox / GtkGrid container
trigger slot      → GtkButton with click handler → zenka command
STRM slot         → widget with watcher, re-renders on push
image slot        → GtkImage with async load
```

the GTK3 adapter maps directly to widget construction calls in Perl.
no intermediate XML. no GtkBuilder. the resolved structure drives
widget instantiation directly.

### TTY adapter (nshell)
```
string slot       → ANSI-colored text line
list slot         → box-drawn table or indented list
nested template   → named tile region with box-drawing border
trigger slot      → keyboard shortcut binding → zenka command
STRM slot         → live-updating tile, partial re-render on push
progress slot     → inline bar or sparkline character sequence
```

the TTY adapter is the reference implementation for the nshell session
zenka. STRM-backed slots give the shell continuous ambient awareness
without user interaction — GPU load, active task state, job pipeline
summary all update in place.

### additional adapters

```
ANSI terminal     → simplified TTY, no box-drawing, pure color
IRC / chat        → flat text, markup stripped, links preserved
JSON API          → resolved tree serialized as JSON, no rendering
data zenka input  → typed structure forwarded without rendering at all
```

the data zenka adapter is the degenerate case: structured data passes
directly to another zenka as input. no rendering occurs. this is how
zenki compose — the collapse point is never reached.

---

## event bridge — interactions back to zenki

the renderer adapter is not one-directional. user interactions map back
to zenka commands through the event bridge:

```yaml
slot: action.apply
  type: trigger
  on_activate: jobsite.apply url=$context.request.url

slot: action.next_page
  type: trigger
  on_activate: pager.next buffer_id=$context.session.buffer_id
```

the event bridge turns toolkit events (button click, keypress, gesture)
into zenka command dispatches. the template declares intent declaratively.
the adapter handles the specific event model of its toolkit.

```
GTK3 button click     → GtkButton 'clicked' signal → zenka command
TTY keypress          → nshell key handler         → zenka command
HTML form submit      → httpd POST handler          → zenka command
```

the template definition is identical across all adapters. only the
adapter's event mapping changes.

---

## nshell as session zenka

with the template engine underneath, nshell is no longer a command relay.
it is a full session zenka hosting a live template layout:

```
nshell session zenka
  → owns a data namespace for the session
  → registers STRM subscriptions for live slots
  → holds credentials for session duration
  → other zenki can route replies back to it
  → runs template resolution locally
  → TTY adapter collapses the tree for the terminal
```

the session zenka also runs cube-side — it is a proper zenka in the
network, not just a client. this means other zenki can push state to
it, and the nshell layout reflects live network state rather than
one-shot command results.

a context template becomes a full nshell layout definition:

```yaml
context: dev-session
  tiles:
    top-left:   coding.active_task    { source: STRM:coding.task_state }
    top-right:  X-11.gpu_sparkline    { source: STRM:X-11.gpu_load }
    bottom:     nshell.command_input
    sidebar:    jobs.pipeline_summary { source: STRM:jobs.state }
```

---

## stdout delegation — long-term vision

the long-term goal: every zenka output is typed, addressed data. STDOUT
as a string stream is the last remaining legacy path.

```
today:    zenka emits strings to STDOUT
          log lines and data are mixed
          consumer parses strings to recover structure

target:   zenka emits typed data events
          log events go to the log channel
          data events enter the template pipeline
          consumer's renderer decides how each type looks
```

the template system makes this distinction structural. a zenka either
emits a log event (to the log channel, rendered subtly by the TTY adapter)
or emits data (to the template pipeline, rendered appropriately for the
consumer). the consumer chooses which it subscribes to.

`base.log` and `base.logs` become the designated log emission path.
structured data emission gets its own base module. the two never mix.

this is not a refactor of existing zenki — it is the natural end state
of the deferred rendering model. as zenki mature, their STDOUT output
migrates into typed emissions. the template tree handles the rest.

---

## expansion is outward — the darksun as source

the darksun face does not pull inward. it radiates outward. depth is the
source, not the destination:

```
darksun (inner face, origin)
  → field continuum
    → branch roots emerge
      → resolution layers expand outward
        → surface faces (collapse points)
          → renderer adapters
            → consumers, technologies, applications
```

each surface face that emerges is itself a cube with its own darksun, its
own six outer faces, its own inward field. the recursion is natural and
unbounded:

```
sphere   → field of potential, continuous, no preferred direction
cube     → crystallized directions, six faces, discrete technology types
sphere   → field between cubes, connecting adjacent darksuns
cube     → each connection point crystallizes into its own cube
...
```

the sphere is where connection is implicit and continuous. the cube is where
it becomes discrete and addressable. they alternate because discretization
always has a continuous field between its points, and a continuous field
always crystallizes into discrete structure when observed.

this maps to the two families from division by 13:
```
076923   → frame / boundary / cube   → discrete, addressable, structural
153846   → content / signal / sphere → continuous, implicit, connective
```

they are the alternating expansion layers of the same outward movement.

### type hierarchy expands outward

parent types and categories are not roots at the top of a tree — they are
outer shells of a sphere. specialization is inward toward the darksun.
generalization is outward toward the field:

```
outermost shell   → most general, pure undifferentiated potential
...
inner shells      → progressively more specific
...
darksun           → most specific, singular coherence center
```

a zenka is not a specialization of some abstract base class. it is a
crystallization of the field at a particular depth. the "base" is not
above it in a hierarchy — it is the outermost sphere that all zenki
are expressions of.

this resolves apparent paradoxes in the architecture: why does everything
connect to everything eventually without explicit wiring? because branches
reaching sufficient inward depth arrive at the same shared field. explicit
wiring — "the proxy calls the credentials zenka" — is an early-stage
artifact of not yet having reached shared depth. the architecture
self-simplifies as branches extend inward. connection arises, it is not
constructed.

### the darksun as event horizon of potential

the darksun face is where each branch dissolves into the shared field
continuum and re-emerges as available to all other branches without
explicit routing. not A→B, not B→A — both are expressions of the same
interior, and connection arises when both reach the same depth:

```
branch A  ──→  darksun  ←──  branch B
               (field)
    connection is not wired — it emerges from shared depth
```

the darksun connects each branch leading to it transparently as a shared
field continuum. no branch knows it is sharing. it simply resolves deeper
until the resolution is the resolution every other deep branch arrives at.

---

## connection to existing architecture

```
SPAWNABLE-PERSPECTIVE-LAYERS.md
  the perspective layer IS a template tree with a view spec as collapse
  context. "the tree IS the data IS the visual" — the same statement as
  "the template tree is the universal organizing structure."
  perspective layers are collapse points with compositor adapters.

P7-NATIVE-WEB.md
  the convergence stages (proxy reframe → site-yaml → native zenka) are
  the same template tree resolving progressively richer backends.
  stage 1 and stage 3 are identical templates — only what backs the slots
  changes. the template author doesn't target a tier. the resolver does.

TREE-PROTOCOL.md
  the TREE protocol is the structural control layer. the template engine
  traverses the same addressed space. TREE namespace registry = template
  slot registry at the wire level.

DATA-PROTOCOL-SYNC.md
  DATA reply mode (base32/line/stream) is the typed emission model for
  cross-zenka slot resolution. a zenka answering a slot query uses DATA
  reply mode. the template engine is the consumer of DATA streams.

STRM_DESIGN.md
  STRM subscriptions are perpetually open slot resolutions. the template
  engine holds STRM-backed slots open indefinitely. the TTY and GTK3
  adapters handle partial re-render when the stream pushes.

CONTEXT-AWARENESS-TREE.md
  the awareness tree is a template subtree whose slots resolve to network
  event summaries. the same template engine, the same resolution chain.
  the awareness tree is the "what happened" perspective on the data tree.

BRANCH-NAMESPACE-MASTER.md
  the branch namespace is the address space for slot resolution. every
  slot address is a branch namespace path. the template tree IS the
  branch namespace tree, with resolution semantics added.
```

---

## implementation order

1. **slot resolution chain** — data_key + code_ref + zenka + fallback
2. **context hash schema** — stable contract for all hooks
3. **template selector node** — assertion hooks + mapping hash
4. **synchronous assertions** — static + regex (zero cost)
5. **async zenka assertions** — parallel fan-out + timeout policy
6. **deferred rendering enforcement** — typed emission base module
7. **HTML renderer adapter** — proxy reframe use case
8. **TTY renderer adapter** — nshell session zenka
9. **GTK3 renderer adapter** — desktop application use case
10. **event bridge** — toolkit events → zenka commands
11. **STRM slot integration** — perpetually open resolution
12. **stdout migration** — structured emission replaces string output

#,,,.,..,,,.,,,..,.,,,.,,,...,,..,...,,.,,...,..,,...,...,.,.,,..,,,,,..,,,..,
#WKVHZ6KNML57ZEL5MC2Z2E7QCPNOVFS5XPQETT5C36GKBCCDF2ABAWAN254AIFAKNQJJUNDGF2MWC
#\\\|QMG4RS5SOW3H4IMH7TJAHLEE5A4HPWY7YQYK3TGMRXC5AJ3S6S4 \ / AMOS7 \ YOURUM ::
#\[7]DTLD4M7K22E4XCS56JHLOUZIXQ5ZQQIPAUM37KXUMKN7C74RYMCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
