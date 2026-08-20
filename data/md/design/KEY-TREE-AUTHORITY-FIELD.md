## [:< ##

# name  = design: key-tree authority field
# descr = the dot-separated namespace IS the C25519 key derivation tree.
#         each namespace level is one delegation step. the key at any node
#         both projects authority into the network (actuator) and attracts
#         what resonates with that authorization profile (antenna).
#         contextualization through resonance distance, not policy lookup.

## the dual identity

every namespace path in protocol-7 is simultaneously:

```
semantic address:   base.net.connect
                    (human-readable, hierarchical, dot-separated)

key derivation path:
                    root_key
                      → derive(base)     = K_base
                      → derive(net)      = K_base_net
                      → derive(connect)  = K_base_net_connect
```

the key derivation is deterministic from the path. given the root key,
any node in the key tree can be computed. given only a node's key,
nothing above it can be derived (one-way). sibling paths produce
independent keys (sibling isolation).

this is not a design choice layered onto the namespace. it is the
namespace — the dot notation is already the derivation path.

## three simultaneous properties

### 1. implicit immutability

the key tree is its own audit trail. every delegation is
cryptographically verifiable without a central authority.
a signature produced by `K_base_net_connect` can only have been
produced by an entity that held the key at that namespace node.
the namespace IS the identity claim.

```
claim: "I am base.net.connect"
proof: signature under K_base_net_connect
verification: anyone with K_base can derive K_base_net_connect and verify
no intermediary required
```

### 2. outward delegation

authority flows from the visual session owner (root key holder)
outward toward the network periphery:

```
session owner:     holds root_key → can authorize anything
module namespace:  holds K_base → can authorize base.* operations
sub-namespace:     holds K_base_net → can authorize base.net.* operations
leaf node:         holds K_base_net_connect → can sign connect operations only
```

each delegation step narrows authority. no child node can exceed
the authority of its parent. the tree naturally mirrors the topology
of trust: the session owner at the root, the periphery at the leaves.

### 3. self-authorizing antenna

the key at any node does two things simultaneously:

```
actuator:  the key signs operations within its authorized scope
           projecting the owner's entropy into the network as
           grid-aligned actuators — each namespace node can act
           on what it is authorized to act on

antenna:   the key attracts data that resonates with its authorization
           profile — data that is "already own" or that would be
           useful to someone with exactly this authorization pattern
           surfaces toward the key without being explicitly requested
```

the antenna property produces **contextualization through omission**:
the field around the key does not present everything — it presents
what has semantic gravity within the authorization scope. sensitive
information surfaces to those already known to be in spirit with it.
nothing is hidden by policy; it simply has no resonance with keys
outside its natural scope.

## visual proximity as authority distance

in synesthetic space, elements sort by essence-distance to the
observer's key:

```
same namespace (key sibling):     appears close, high brightness
parent namespace (key ancestor):  appears present but elevated
unrelated namespace:              appears distant, low brightness
incompatible authorization:       drifts to periphery or becomes
                                  invisible via resonance fall-off
```

this is not a display rule — it is the natural fall-off of semantic
gravity across key distance. compatible patterns cluster because they
are close in the key tree. incompatible patterns drift because they
have no key relationship.

**the space organizes itself by the authorization topology.**
the observer does not configure proximity — the key tree determines it.

## implementation in protocol-7

### current state

the codebase has:
- `src/crypt.C25519.*` — Curve25519 key generation and operations
- dot-notation namespace throughout (module names, routing paths)
- `$data{<path>}` addressing mirrors the namespace structure
- per-session numerical IDs (cube session IDs)

### what needs adding

#### key derivation for namespace paths

```perl
# derive child key from parent key + path component
sub derive_child_key {
    my ($parent_key, $path_component) = @_;
    # HKDF or similar: deterministic, one-way, collision-resistant
    # input: parent_key bytes + path_component string
    # output: child key bytes (same length as parent)
}
```

#### namespace key registry

```
$data{keyring}{namespace}{<dot-path>}{key}     = <derived key bytes>
$data{keyring}{namespace}{<dot-path>}{depth}   = <integer>
$data{keyring}{namespace}{<dot-path>}{parent}  = <parent dot-path>
```

the registry is populated lazily: a key is derived when first needed,
cached in the registry for the session lifetime.

#### resonance distance metric

```
resonance_distance(key_A, key_B):
  if same key:         0    (identical, maximum resonance)
  if parent/child:     1    (adjacent in tree)
  if sibling:          2    (same parent)
  if cousin:           3    (same grandparent)
  ...
  if unrelated:        depth_A + depth_B (no common ancestor in scope)
```

used by: visual proximity sorting, synesthetic space brightness,
attention filter attenuation.

#### signature operations

```
keyring.sign         sign a datum with the namespace key at given path
keyring.verify       verify a signature against a known key or derivable key
keyring.derive       derive and cache the key for a namespace path
keyring.distance     compute resonance distance between two namespace paths
keyring.authorize    check if a given key has authority over a namespace path
```

## the key tree as cancellation library

the connection to harmonic silence / active cancellation:

```
key tree scope:    defines what is "own" for a given key
outside scope:     defines what is "not own"
resonance filter:  things outside scope are "known patterns" —
                   they cancel from the canvas of this key's attention

what remains:      things within scope that are novel, unexpected,
                   or high-signal relative to the current authorization context
```

the key tree IS the cancellation library for the authority field.
every namespace boundary is a pattern boundary. what falls outside
the authorized scope cancels from the observer's canvas automatically —
not by policy, but by the physics of resonance distance.

## relation to ring routing

```
key tree:    answers WHO — individual authority, outward delegation
             each entity's authorized scope is precise and derivable
             no central authority required

ring routing: answers THROUGH WHAT — group authority, inward anonymization
              each ring's shared key enables transparent route wrapping
              no hop can see the full path

together:    center can verify the tree-derived signature (who sent this)
             without knowing the route origin (ring hides it)
             periphery can trust the response came from an authorized center
             without the center knowing who asked
```

they are complementary axes: tree gives precise individual authority,
ring gives collective anonymous traversal. neither is complete alone.

## key derivation function selection

C25519 (already in codebase) handles key generation and DH operations.
for namespace key derivation (parent → child), the operation is
symmetric: given parent key bytes + path component string → child key bytes.

candidate: HKDF-SHA256
- `prk` = parent key bytes
- `info` = path component string (e.g., `"net"`)
- `okm` = 32-byte child key

this is deterministic, one-way, and produces keys indistinguishable
from random given only the output. it composes correctly (derive child
of child gives the same result as derive two levels from root).

## implementation phases

```
phase 1:  key derivation function
          derive_child_key ( parent_key, path_component ) → child_key
          test: derive base.net.connect from root, verify chain

phase 2:  namespace key registry
          keyring.derive / keyring.sign / keyring.verify
          lazy population, session-scoped cache

phase 3:  resonance distance metric
          keyring.distance ( path_A, path_B ) → integer
          use in visual proximity sorting (synesthetic space)

phase 4:  authorization check
          keyring.authorize ( key, target_path ) → TRUE/FALSE
          integrates with base.handler.command as authority gate

phase 5:  antenna / attractor field
          keyring.suggest — given current key context, surface
          data items with high resonance (low distance) from
          $data tree — the autonomous contextualization layer
```

## relation to other design docs

- `data/md/design/RING-ROUTING-PROTOCOL.md` — ring routing is the
  complement: tree=who, ring=through-what; both needed for full
  authority+routing separation
- `data/yaml/reasoning-templates/key-tree-authority-field.yaml` —
  conceptual template this doc implements
- `data/md/design/HARMONIC-SILENCE.md` — the key tree is the
  cancellation library for the authority field; resonance distance
  = signal attenuation function
- `data/yaml/reasoning-templates/synesthetic-space.yaml` —
  visual proximity sorting by key distance is the synesthetic
  space rendered through the authority lens

#,,..,,..,.,.,,..,,.,,,,.,,..,..,,...,,.,,...,..,,...,...,...,..,,,,.,...,,,,,
#77VA5ZXIVN5FVVFOL25X5BS6KLOYHJ7U2IIZQCYNTDIY77YJVRIXWKR7CY6SQQBFVMVB235ZV5ABG
#\\\|4UM2CXVJLTV2L6V6KBZDTDQYMU2VCFUE4KNJIPRKLKV4EGYRVPO \ / AMOS7 \ YOURUM ::
#\[7]ZFDWUQBYXIU6ZTZSCUKSOEU7PVWE7BCPIUQHUYZC4RNF5NXG6WCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
