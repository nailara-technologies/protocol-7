## [:< ##

# name  = task: base.has_access — source SID hierarchical matching
# descr = extend access control to support usr.cube.system = cmds syntax

## rewrite note (2026-06-09)

attempted implementation (kimi, session b929dd82) extended `base.has_access`
with a `$source_sid` third param and extracted the source zenka from command
args in `base.handler.command`. reverted — the approach is technically wrong
AND architecturally wrong:

- `base.has_access` is a pure table lookup, not a runtime filter. adding
  call-context awareness changes its fundamental nature.
- source SID resolution at the handler level is unreliable — cube strips or
  aliases the source before commands reach the zenka handler.
- the correct gate for "only system zenka can call teardown" already exists:
  `cube/access.zenki` (routing-level, before command delivery). that is not
  a `base.has_access` concern.

a correct implementation would need a new design: a cube-side policy layer
that enriches routed commands with a verified source tag, or a separate
module operating on cube-provided metadata rather than heuristic arg parsing.
`base.has_access` should not be the host for this feature.

## context

the current access control system is user-centric:

```
access.cmd.usr.cube   = *          ## all cube-routed commands allowed
access.cmd.usr.system = teardown   ## system zenka can call teardown
```

`access.cmd.usr.cube = *` is a wildcard for ALL zenki connecting through
cube. there is no way to express "only system zenka can call teardown"
without removing the wildcard, which would require listing every other
v7 command explicitly — brittle and maintenance-heavy.

the real gate is `cube/access.zenki` which controls routing. v7/start
access lines are a second check, but behind the cube wildcard they are
effectively no-ops for any zenka that already passes cube's check.

## goal

extend `base.has_access` (and the config parser) to support a hierarchical
source SID qualifier:

```
access.cmd.usr.cube          = *          ## all cube users: wildcard (unchanged)
access.cmd.usr.cube.system   = teardown   ## cube user 'system' specifically
```

the parser reads `usr.cube.system` as: "the zenka named system, connecting
via cube". when matching `access.cmd.usr.cube = *`, also check for a more
specific `access.cmd.usr.cube.<source_sid>` entry — specificity wins.

alternatively (route-based approach):

```
access.cmd.route.cube.system = teardown
```

where `route` is a new directive meaning "check the routing path SID chain".
more powerful but requires more parser work — matches the P7 routing model
more naturally.

## what to read first

```bash
cat modules/base.has_access          ## current matching logic
cat modules/base.parser.access_conf  ## how access lines are parsed
grep -n 'usr\.' cfg/zenki/cube/access.zenki | head -20
grep -n 'access.cmd' cfg/zenki/v7/start
```

## approach 1: hierarchical key (simpler)

extend the config key parser to split `usr.cube.system` into:
  - base key: `usr.cube`
  - specificity qualifier: `system` (source SID)

in `base.has_access`: after matching `usr.cube`, check if a more specific
`usr.cube.<source_sid>` entry exists — if yes, use that instead of the
wildcard.

this is a natural extension of the existing syntax. minimal parser change.

## approach 2: route SID hook (more powerful)

add a new `access.cmd.route` directive that checks the full routing SID
chain (cube → source zenka). allows path-aware access control.

more flexible but requires more work in `base.has_access`.

## routing model — departure route, closest hop first

the chain in `usr.cube.system` reads as the departure route from the
destination's perspective — closest hop first:

```
usr.cube          ## v7's direct source is cube (always, for cube-routed traffic)
usr.cube.system   ## cube's source was system (source alias propagated one hop)
usr.cube.httpd.web ## cube's source was httpd, httpd's source was web
```

v7 only ever sees `cube` as its direct peer. the rest of the chain comes
from source aliases propagated by intermediate zenki. currently this
propagation is voluntary — if any hop doesn't propagate, the chain
silently truncates.

## phase 2: immutable source tracing (future upgrade)

a command or route can declare `require-source-trace` — the protocol then
enforces source identity propagation at every hop automatically:

```
access.cmd.usr.cube.system = teardown require-source-trace
```

- every intermediate zenka MUST propagate the source SID/name chain
- a zenka that cannot propagate causes the route to fail, not silently drop
- the destination receives a complete, protocol-enforced hop list
- immutable: intermediate zenki cannot strip or forge the chain

this makes `usr.cube.system` a security primitive, not a best-effort hint.
the self-propagation means the requirement travels with the command —
no manual configuration of each intermediate zenka needed.

## use case that prompted this

`v7.teardown` should only be callable by the `system` zenka. currently:
- cube/access.zenki controls routing — no zenka has teardown except system
  (once granted) — this is the real gate, already correct
- v7/start `access.cmd.usr.cube = *` makes any further v7-level restriction
  impossible without listing all other commands explicitly

with this enhancement:
```
## in v7/start:
access.cmd.usr.cube           = *        ## all v7 commands for cube users
access.cmd.usr.cube.system    = teardown ## teardown only for system
## or: teardown not in the wildcard, explicit list for everyone else
```

## signatures note

do not add signature stubs. do not run update-signatures.
do not add or modify subroutine whitelists.

## style

$ARG not $_ in loops
lowercase comments, [ word ] bracket annotations

## dispatch

model: kimi
reasoning: medium

prompt: |
  Implement the task at data/tasks/base-has-access-source-sid-matching.md

  Read base.has_access and base.parser.access_conf first to understand the
  current matching logic before writing anything. Implement approach 1
  (hierarchical key: usr.cube.system) as it requires the smallest parser
  change. The goal: access.cmd.usr.cube.system = teardown works correctly
  alongside access.cmd.usr.cube = *. No signature stubs, no whitelist changes.

#,,,,,,.,,,.,,,.,,,.,,.,.,.,.,,,.,.,,,.,.,,..,..,,...,...,..,,..,,,,,,..,,,,.,
#TCDMCWLTDIBK7Y2UP3WJ5QE6REJU6PFC3WE257MUIKGGZOOQGCU5CYMZLVH7GZDKPW27WG2D6VDM4
#\\\|RIFIK4PHD4BHHLRAP3Q5UM5D6RFEVFH6KXCT5SXY7PF5LRWABTN \ / AMOS7 \ YOURUM ::
#\[7]WKNT2HLKVHDHWZRP466VCWKIHCVD4P764ROYHNCKNXULQYJQ7CCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
