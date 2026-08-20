---
name: hybrid-namespace-routing
description: not-yet-decided architecture idea — let a zenka register a virtual sub-namespace (e.g. self-test) that participates in dotted command routing without being a real spawned child process
metadata: 
  node_type: memory
  type: project
  originSessionId: 0167cea8-7299-4bd1-b3b4-a507800e7687
---

Root cause identified 2026-06-20 of a recurring confusion (this session
hit it directly with `coding.self_test.cmd.*`): models naturally write
dotted command names like `coding.self-test.run-all` expecting it to
work, because dots in this system's existing convention mean "route to
a child zenka" (`zenka.command` syntax). This isn't a naming mistake —
it's the model correctly inferring the established convention and
applying it one level too eagerly, since there's currently no formal
concept of a sub-namespace that's just a logical/code-level grouping
without being an actual spawned process with its own session entry.

`access.cmd.usr.cube` entries can only ever be bare command names (see
[[feedback-access-grant-scope]]) — there's no dot-awareness there at
all, which is the symptom; this note is about the underlying gap that
produces the symptom.

## three sketched resolution paths (none decided, all speculative)

1. **expand the command table to understand dots, with precedence over
   child routing**: the dispatcher checks an internal dotted-command
   table first; only falls back to treating the first segment as a
   child-zenka route if no internal match exists.

2. **register a sub-namespace as a virtual "child" in session
   management, without spawning a real process**: add a new connection
   *type* (alongside the existing `unix`/`ip.tcp` types visible in
   `list sessions`) — call it `module` — so a loaded sub-namespace like
   `self-test` shows up in the routing table exactly like a real child
   zenka would, but never spawns anything.

3. **pair with loadable/unloadable modules**: registration-as-virtual-
   session would naturally happen at module load time. Could even be
   on-demand-loadable, though the user flagged this specifically as
   risking confusion (about when the registration appears/disappears)
   — noted as the least settled part of the idea.

## second use case identified (2026-06-20, same session)

relay-zenki registering a tunnel or route has the same shape: it needs
to appear in session/routing management without being a real spawned
endpoint itself, same as the `module` type idea above — but it's
clearly a *different* type (a network path, not an in-process code
namespace). this reframes the generalization: the actual missing
piece isn't one new type called `module`, it's making connection type
itself an extensible, documented family — `unix`, `ip.tcp` (existing
real transports) alongside `module` and `tunnel`/`route` (registered-
but-not-spawned participants) — each generic and useful on its own,
worth documenting well as a set once built.

## third use case identified (2026-06-20, same session) — threshold met

mounting a holographic "data cube" (the project's own 63K/63M cube/grid
topology — see [[topic-node-group-geometry]] — not yet built, but
anticipated as a future transportable artifact). a mounted cube brings
its own command interface; access into its src/commands unlocks
progressively via authorized decryption/mapping into the cube's layers
(not all-or-nothing — same layered-access spirit as the project's
existing key-tree/checksum model). the cube could contain full inner
zenki — a holographic snapshot of an entire sub-network, not just
static data. routing into it would then be virtual: primarily
cryptographic and data-cube-topology-based, not a real network route.

this is structurally the most different of the three cases: `module`
is in-process/no-network, `tunnel`/`route` is real-network/no-process,
this is neither — a crypto/topology-defined virtual route into a
structure that might itself contain a nested zenki sub-network. three
genuinely different answers to "what's on the other end of this
connection," all needing the same underlying capability: appear in
session/routing management as a navigable connection without being a
literal `unix`/`ip.tcp` socket.

threshold met per the meta-point below — this is the trigger to design
the generalized connection-type architecture, even though the `cube`
mount case's own underlying technology doesn't exist yet. the
generalization (extensible, documented connection-type family) is
ready to design independent of whether all three concrete cases are
themselves built.

## design doc written: `HYBRID-CONNECTION-TYPE-ROUTING.md`

resolution principle confirmed by the user: local always wins over
routing, by default, even to the point of masking — local is fully
known and present in proximity, routing is inherently less certain.
applies recursively to module *loading* too (flat fully-qualified
filenames in `src/` stay preempting/prioritized over any future
nested submodule-directory form, same precedence rule one layer down).
full sketch: `data/md/design/HYBRID-CONNECTION-TYPE-ROUTING.md`.

## concrete consumer identified (2026-06-21): command-relay zenka

`data/tasks/command-relay-zenka.md` — a new zenka requirement noted:
maps input commands/routes to output routes, primarily for
interconnecting a local/trusted core cube with a DMZ-facing cube where
externally-reachable zenki (httpd, httpsd, etc.) connect. this is
likely the concrete zenka that ends up needing the `tunnel`/`route`
connection type once `HYBRID-CONNECTION-TYPE-ROUTING.md` gets built —
not designed in detail yet, just noted as the natural first consumer.

## the meta-point, worth remembering on its own

the user's framing for *when* to actually build this: wait for a second
and third independent use case to want the same capability before
generalizing — at which point the design starts feeling like it "always
should have been this way," even though it wasn't implemented yet.
that retroactive-inevitability feeling is the signal to build, not a
reason to suspect premature generalization. don't propose building this
from a single pressure point (tonight's self-test naming collision) —
watch for the next one or two before raising it again.

[[feedback-access-grant-scope]] · [[topic-dot-path-case-notation]] ·
[[coding-zenka-improvement-pipeline]]

#,,,,,...,,..,,,,,.,,,,,.,...,,,.,.,.,...,..,,..,,...,...,..,,,.,,,..,.,.,,..,
#OSNMD5RSJILRS5FX4EJMZC4FPH7R6PRDQR43YPQBEXD7DETFGU5NJXFLZH5HGMQU23MVBYPZIPIQO
#\\\|KLY3Y6JFECUNSOHNJKGP3F3TW3S2JHTOKGBK43MM3ZKQO6R4EZ7 \ / AMOS7 \ YOURUM ::
#\[7]JRONO4ZUNTBYASXPRXXQXEPGHKVYRUUZBQ7BBIYQHBSIVUB6WYBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
