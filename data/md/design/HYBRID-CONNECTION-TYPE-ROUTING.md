## [:< ##

# hybrid connection-type routing — design sketch

status: design-ready, not yet implemented. session: 2026-06-20. see
[[topic-hybrid-namespace-routing]] (memory) for the three motivating
cases that triggered this — recorded there, not repeated in full here.

## the core precedence rule

when a dotted name could resolve either as a local/internal match (a
command table entry, a loaded module, an in-process namespace) or as a
route to something else (a child zenka, a tunnel, a mounted cube),
**local always wins, by default, even to the point of masking** — not
just as a tiebreaker, as the default behavior.

reasoning: local is always fully known and present in proximity —
there's no uncertainty about what it is or whether it'll answer.
routing is inherently less certain (a child may be slow, gone,
unreachable, stale). preferring the known-complete answer over the
externally-dependent one is the only default that doesn't introduce
surprise latency/failure modes into what looks like a simple local
call. explicit override (deliberately routing past a local match that
would otherwise mask it) should be possible, but never the default.

## connection-type family (generalizes `list sessions`'s existing
`unix` / `ip.tcp` types)

```
unix, ip.tcp     existing — real transport-layer connections

module           in-process code namespace (e.g. coding.self-test.*),
                 registered in session/routing management without
                 spawning a real process — the original motivating
                 case (coding.self_test.cmd.* naming collision)

tunnel / route   relay-zenki registering a network path it relays
                 through, without itself being the endpoint —
                 second motivating case

cube / mount     virtual route into a mounted holographic data cube
                 (63K/63M topology, see [[topic-node-group-geometry]] —
                 not yet built). route is cryptographic + data-cube-
                 topology-based, not a real network path. access
                 unlocks progressively via authorized decryption/
                 mapping into the cube's layers (same layered-access
                 spirit as the existing key-tree/checksum model).
                 the mounted cube may contain full inner zenki — a
                 holographic sub-network snapshot, not just data.

alias            mounts a mnemonic, human-readable name onto a BASE32
                 checksum/key-based route — pure aliasing, no new
                 resolution behavior of its own. resolves to whatever
                 the canonical BASE32 address would, just spares typing
                 it. the natural friendly-name overlay for the
                 project's existing checksum-addressing system.

macro / template a route that resolves to a stored script/macro/
                 template rather than a live process/module/cube;
                 invoking it expands or executes the template instead
                 of calling a "thing" that answers.

                 two distinct tiers, NOT one feature:
                 tier A (buildable now, no language expansion): flat,
                   scope-free macros in the existing zenka-start-file
                   style — sequential commands only, no loops, no
                   conditionals. fits this design's family directly.
                 tier B (deliberately gated, see below): full loops/
                   conditionals/scopes — a real language expansion
                   with security-analysis implications, intentionally
                   postponed for years, not something to add casually.
```

each type is generic and useful on its own merit, not just as a
workaround for one naming collision — worth documenting as a real,
small, closed family once built, in `list sessions`'s own reference
material.

## the module-loading analogy — same precedence rule, different layer

the same local-wins principle should apply recursively to module
*loading*, not just to session/connection routing:

```
current:    flat, fully-qualified dotted filenames in src/
            (e.g. src/coding.self_test.run) — one file, one name,
            no nesting

possible future: submodule directories within the src/ namespace
            (nested organization, e.g. src/coding/self_test/run)

precedence: if/when nested submodule directories are ever supported,
            the CURRENT flat fully-qualified-filename resolution stays
            preempting/prioritized over the nested form for any name
            that could resolve either way. this isn't just backward
            compatibility — it's the identical local-wins-by-default
            rule applied one layer down: the flat form is the fully-
            known, already-present-in-proximity one; nested resolution
            would require directory traversal, which is structurally
            the same "less certain until resolved" position routing
            occupies relative to a local module-table hit.
```

## open, not yet decided

```
- exact mechanism for "explicit override" of the masking default (a
  call-site syntax? a config flag per route? per [[topic-dot-path-
  case-notation]]'s existing case-notation ideas, could uppercase vs.
  lowercase distinguish "force route" from "prefer local" at the
  syntax level — worth checking that doc for overlap before inventing
  new syntax)
- whether `module`/`tunnel`/`cube` types need different precedence
  rules from each other, or whether "local wins" is uniform across all
  three against real child-zenka routing
- the `cube`/`mount` type is gated on the underlying holographic data
  cube technology existing at all — purely speculative until then
```

#,,,,,.,,,...,..,,...,,,,,..,,.,.,..,,,..,,,,,..,,...,...,...,...,.,.,.,,,..,,
#HLLXBXDRR6PIQZVKNJN4R2RU6D2UVZQXJNWZ3GH5BNVKMO5EWKUVOCVIHKIEICFXZF7NYJVDK2GYG
#\\\|5ABE2XQODJ2PMNLERKKTDUELIM7D6RTOZYACPQCCOHDSGD2I3GU \ / AMOS7 \ YOURUM ::
#\[7]GF42QCOQLIWQVS7REGDBXDAQ5FRZKIOHRUMZS64SOFCX5JGUD2DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
