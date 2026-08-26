## [:< ##

# name  = design: ring routing protocol
# descr = shared ring keys enabling layered self-removing anonymization
#         toward a common center. tree answers "who" (authority);
#         ring answers "through what" (topology, anonymized).
#         the cube zenka's session/route ID primitives are the seed.

## the primitive already exists

the cube zenka already implements the numerical core:

```
each zenka:    a randomized numerical session ID
each route:    two randomized numerical IDs — one per hop namespace
each hop:      strips inbound route component, generates outbound
               the route exists on each hop as two unrelated numbers
               no hop can reconstruct the full path from local state
```

ring routing extends this: instead of one-way stripping (anonymization
without reconstruction), rings give the hop-by-hop anonymization
a **reversible structure** — any ring member can undo what crossing
the ring did.

## ring structure

a ring is a set of nodes that share circularly distributed key material:

```
ring R:  nodes { A, B, C, D } share key material K_R

crossing ring R inbound (toward center):
  transform T_R applied to route header:
    - routing context wrapped/encrypted under K_R
    - workload component extracted and passed through unchanged

crossing ring R outbound (away from center):
  transform T_R^(-1) applied to route header:
    - routing context unwrapped/decrypted under K_R
    - workload component (response) attached and passed back
```

the key is not held by any single node — it is the shared property
of the ring membership. any member can apply or undo T_R.

## layered rings toward a center

a route crossing N rings toward a common center:

```
origin → [ring 1 boundary] → [ring 2 boundary] → [center] → response

at ring 1 crossing:
  route header: wrapped under K_1
  workload:     extracted, passed through

at ring 2 crossing:
  route header: wrapped again under K_2 (outer wraps inner)
  workload:     still the same, passed through again

at center:
  route header: fully wrapped — center sees only the innermost
                ring's wrapping, knows nothing of origin
  workload:     fully visible — center performs work on it
  response:     created and attached to the workload

return journey (reverse rings):
  ring 2 outbound: header unwrapped under K_2
  ring 1 outbound: header unwrapped under K_1 → origin reached
```

at every point the route header is **smaller than what arrived**
(one layer peeled per ring). at the center, it contains nothing
about the origin. on the return, it reconstitutes exactly.

## the center commitment

the only mandatory waypoint is the center. this is the minimal
commitment that makes the whole structure work:

```
ring membership:   distributed key → any ring member can apply/undo
center:            single waypoint commitment — route through here
everything else:   self-removing layers
```

the center does not need to know where the route came from.
it performs work and produces a response. the rings carry the
response back. the origin receives the result.

## composition with the key tree

```
key tree (who):
  each namespace level = one C25519 delegation step
  authority flows outward from session owner
  each entity holds keys derived from root by path
  signature verification: possible anywhere in tree

ring topology (through what):
  each ring = one anonymization layer
  routing flows inward toward center
  each hop holds only its ring's key share
  route reconstruction: not possible at any hop

together:
  center can verify the tree-derived signature without knowing
  the route origin (ring hides it)

  rings can carry the response to the right destination without
  knowing the signature (tree carries it)

  authorization and routing are fully decoupled
```

## ring membership and key distribution

### static rings (administrative)

defined at configuration time. ring members share key material
established during ring formation. suitable for:
- inter-datacenter segments
- trust-domain boundaries
- persistent organizational structures

### dynamic rings (session-scoped)

formed on demand for a specific routing context. key material
generated fresh, distributed via the key tree (tree authority
authorizes ring formation). suitable for:
- ephemeral circuits
- task-specific routing (coding zenka job isolation)
- multi-hop mesh traversal

### key distribution

ring formation protocol:
```
1. ring initiator holds tree authority to form ring
2. initiator generates K_R (random, session-scoped)
3. K_R distributed to ring members via key-tree-authenticated channel
4. each member stores K_R for the ring's lifetime
5. ring dissolves → K_R erased at all members simultaneously
```

## cube zenka integration

the cube zenka already owns route/session ID assignment. ring routing
adds one hook point per hop:

```
current (per-hop):
  receive route → strip inbound reference → create outbound reference
  → forward

ring-aware (per-hop):
  receive route → check: am I a ring boundary?
    yes: apply T_R (inbound) or T_R^(-1) (outbound)
    no:  pass through unchanged
  → strip inbound reference → create outbound reference → forward
```

the ring check is O(1): the hop maintains a set of ring keys it holds.
if the route header matches a ring's recognizer, apply that ring's
transform. otherwise pass through.

## failure modes and defenses

### ring member compromise

an attacker compromises one ring member and obtains K_R. they can
now decrypt route headers for routes crossing that ring.

**defense**: ring key rotation. rings operating over untrusted paths
should rotate K_R on a schedule shorter than the expected
deanonymization window. forward secrecy via ephemeral ring keys
ensures past routes remain protected after rotation.

### incomplete ring traversal

a route stalls mid-ring — the workload arrives at the center but
the return path loses a ring crossing. the response cannot
reconstruct the origin.

**defense**: ring boundary timeout-and-purge. if no return crosses
a ring boundary within T seconds of an inbound crossing, the
boundary node emits a timeout to both directions and purges the
half-open route state. originator retries.

### center compromise

the center learns workload content. if workload contains origin
information, anonymization is defeated.

**defense**: workload discipline. protocols using ring routing
MUST NOT embed origin information in workload. the workload
is the work — it should be expressible without reference to
who sent it. the response is the work result — it should not
name the requester.

## implementation phases

```
phase 1:  ring key structure in data tree
          ring.member.has_key / ring.key.load / ring.key.rotate
          ring recognizer: does this route header belong to ring R?

phase 2:  ring boundary hook in cube route handler
          T_R and T_R^(-1) transforms (symmetric cipher, ring-keyed)
          inbound/outbound detection per hop

phase 3:  ring formation protocol
          ring initiator module + key distribution via key-tree auth
          static ring config in zenka start files

phase 4:  center-waypoint routing primitive
          route planning: path guaranteed to cross center
          center nomination: which zenka IS the center for this ring set

phase 5:  dynamic rings (session-scoped)
          on-demand ring formation for task isolation
          ring dissolution and key erasure on task completion
```

## relation to other design docs

- `data/yaml/reasoning-templates/ring-key-routing.yaml` — conceptual
  template this doc implements
- `data/yaml/reasoning-templates/key-tree-authority-field.yaml` — the
  tree half of the tree+ring complementarity
- `data/yaml/reasoning-templates/harmonic-silence.yaml` — self-removing
  layers as active cancellation applied to routing metadata
- `data/md/design/CREDENTIAL-FABRIC-INTEGRATION-AND-UI.md` — credential
  fabric already uses tree authority; ring routing is the transport
  anonymization layer beneath it

#,,,,,,.,,,..,,.,,,..,,..,,,,,,.,,,,,,.,.,..,,..,,...,...,..,,,..,,.,,.,.,,,,,
#DC5XZDXXHFKWBEYSNQZC2XE24VTF4SQCX6E7OUKQ7BQHZO2RRXXN5RWQJQSXQAS6YIBWXOHD5FHEQ
#\\\|TWFSJGRPVSAK3BUOXD5HIEVAXTY5BGJ3GBS4XV32SGRYXUWB57C \ / AMOS7 \ YOURUM ::
#\[7]DHTUBDXSHDDPMFIDJZQ6RUOUUOF73CC2TWOONACVT4UB245IM4CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
