## [:< ##

# name  = task: ring routing protocol — phase 1 ring key structure
# descr = extend cube zenka's session/route ID primitives with ring
#         key material: ring membership, key load/rotate, and the
#         boundary recognizer that detects ring-crossing routes.
#         no transform applied yet — just the key infrastructure.

## context

the cube zenka already implements per-hop route anonymization:
each hop strips inbound route reference, generates outbound reference.
no hop can reconstruct the full path. this task adds the next layer:
**reversible** ring-keyed transforms so routes can peel and reconstitute.

design doc: `data/md/design/RING-ROUTING-PROTOCOL.md`
reasoning template: `data/yaml/reasoning-templates/ring-key-routing.yaml`

## phase 1 scope: ring key infrastructure only

no transforms applied to live routes yet. this phase establishes
the data structures and lookup primitives that phase 2 will use.

## deliverables

### 1. ring key data tree layout

```
$data{ring}{member}{<ring-id>}{key}       = <K_R bytes>
$data{ring}{member}{<ring-id>}{formed_at} = <ntime>
$data{ring}{member}{<ring-id>}{expires}   = <ntime or undef>
$data{ring}{member}{<ring-id>}{members}   = [ list of session IDs ]
$data{ring}{member}{<ring-id>}{center}    = <session ID of center>
```

### 2. modules

#### `ring.key.load`
load ring configuration from `cfg/zenki/cube/rings.cfg`
(YAML format: ring-id, key-hex, members, center, expires).
populate `$data{ring}{member}`. called from cube init.

#### `ring.key.rotate`
generate new K_R for ring-id, distribute to members via
key-tree-authenticated channel (phase 3). for now: log rotation
event and update local key. accepts ring-id as arg.

#### `ring.member.has_key`
`( $ring_id )` → TRUE if this cube instance holds K_R for ring-id.
used by boundary recognizer before attempting transform.

#### `ring.boundary.recognize`
`( $route_header )` → `{ ring_id => ..., direction => 'inbound'|'outbound' }`
or undef if this route header does not cross a ring boundary this
cube instance is a member of.

the recognizer checks the route header for a ring tag field.
ring-crossing routes carry a compact tag: ring-id + direction bit +
sequence number. the tag is added by the ring initiator at ring
formation time, not by individual hops.

#### `ring.cmd.list`
list all rings this cube instance is a member of:
ring-id, member count, center session ID, expires.
returns SIZE reply.

#### `ring.cmd.stats`
per-ring: routes crossed inbound / outbound / in-flight count.
resets on ring dissolution.

### 3. ring config format

`cfg/zenki/cube/rings.cfg`:

```yaml
rings:
  - id: test-ring-alpha
    key_hex: "0000000000000000000000000000000000000000000000000000000000000000"
    members: []          # populated at runtime via key distribution
    center: null         # nominated at ring formation
    static: true         # static ring, no expiry
    description: "test ring for phase 1 validation"
```

for phase 1: one static test ring with a placeholder key.
actual key distribution (phase 3) replaces the static hex.

### 4. cube start integration

add to `cfg/zenki/cube/zenka.v7`:
```
modules.load = ... ring.key.load ring.member.has_key ring.boundary.recognize ...
[ring.key.load]      ## load ring config at cube init
```

add to `cfg/zenki/cube/subroutine.white-list`:
```
ring.list
ring.stats
```

## validation

```bash
# after cube reload:
p7c ring.list           # shows test-ring-alpha, 0 members, no center
p7c ring.stats          # shows 0 routes crossed

# confirm recognizer returns undef for normal routes (no ring tag):
# (verified by ring.stats staying at 0 during normal operation)
```

## not in this phase

- T_R and T_R^(-1) transforms (phase 2)
- ring formation protocol / key distribution (phase 3)
- center-waypoint routing (phase 4)
- dynamic rings (phase 5)

## dispatch prompt

implement the ring key infrastructure for the cube zenka as described.
read `data/md/design/RING-ROUTING-PROTOCOL.md` for full context first.

create:
- `src/ring.key.load`
- `src/ring.key.rotate`
- `src/ring.member.has_key`
- `src/ring.boundary.recognize`
- `src/ring.cmd.list`
- `src/ring.cmd.stats`
- `cfg/zenki/cube/rings.cfg` (one static test ring)

update `cfg/zenki/cube/zenka.v7` to load ring modules and
call `[ring.key.load]` during init.
update cube `subroutine.white-list` for ring.list and ring.stats.

verify with `p7c ring.list` after cube reload — should show the
test ring loaded with 0 members and no active routes.

#,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

#,,,,,,,,,,,.,,..,.,,,.,.,,,,,,..,,,,,,..,,,,,..,,...,...,.,.,.,.,,..,..,,,,.,
#UUMPDVPDDSOHYIUKEP3ERKWH2XLNA4QDZ3YYQAXEFQEAPUCV4N3VZKBIC2KLUVWURMWRP6XX4OLKE
#\\\|UUU4CHFHN6NDT7AQXATC7L4IBH2MT4OHBV7FJ47QJZYJAGT5S35 \ / AMOS7 \ YOURUM ::
#\[7]DK6DYS5BZGRVEIZEMLRR72VDYBVQK4E3XL276GGSFKTFT4F2OICI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
