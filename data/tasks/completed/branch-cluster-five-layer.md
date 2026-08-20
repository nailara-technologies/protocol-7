# task: branch.cluster.* — five-layer knowledge cluster meta-pattern

## context

every major concept in p7 is organized as a five-layer cluster with a gate
node. the structure is forced by 1001 = 7×11×13 ring geometry. the gate
(+1) closes the cluster into a locatable rhizome node. this task implements
the subroutines for creating, validating, addressing, and navigating
knowledge clusters.

design reference: `data/md/design/BRANCH-OPEN-CAPACITY-SESSION-DAG.md`
design reference: `data/md/design/UNIFYING-PRINCIPLE-CHECKSUM-COORDINATES.md`

## signatures note

do not modify or regenerate AMOS7 signature lines. leave them untouched.

## the five layers

```
5   dataspace address     bmw384 gate into cluster as rhizome node
4   intent template       overarching why/direction
3   design document(s)    what the system is
2   reasoning template(s) how to think about it
1   task file(s)          what to build
  + gate node             the +1 address: closes open field into closed cluster
```

layer families:

```
lower 5  (1 task / 2 template / 3 design)  →  076923 family [materialization]
upper 5  (4 intent / 5 address + meta)     →  153846 family [navigation]
gate (+1)                                  →  13th element, the pivot
```

ring arithmetic:

```
5+1+5 = 11   one unit of 1001 ring  (1001/91 = 11)
11×7  = 77   1001/13  (bridge to 1/13 harmonic)
13×77 = 1001 full ring, complete tiling
```

## cluster data structure

```perl
## stored in data/yaml/cluster-registry/<cluster-name>.yaml
{
    name     => $cluster_name,
    address  => $bmw384_hex,        ## gate address, ring position
    ring_pos => $index,             ## 0..12
    layers   => {
        task     => [ @task_file_paths ],
        template => [ @reasoning_template_paths ],
        design   => [ @design_doc_paths ],
        intent   => $intent_template_path,
        address  => $address_node_id,
    },
    family   => {                   ## generator family per layer group
        lower    => '076923',
        upper    => '153846',
    },
    meta     => $meta_cluster_ref,  ## optional: the mirror cluster
}
```

## modules to create

- `src/branch.cluster.address` — compute bmw384 of cluster content
  (concatenation of all layer paths + cluster name). return hex string.
  this is the gate address — the ring position is derived from it.

- `src/branch.cluster.ring_position` — map bmw384 address to
  1001-ring harmonic index (0..12). use:
    `index = bmw384_as_bigint mod 13`
  return integer 0..12 identifying which of the 13 harmonics owns
  this cluster.

- `src/branch.cluster.layers_list` — given cluster name, return
  hashref of all five layer entries from the registry yaml. error if
  registry yaml not found.

- `src/branch.cluster.gate_node` — return the gate node identifier
  (+1 node that closes the cluster). the gate is the bmw384 address
  itself, stored as a branch node in the dag.

- `src/branch.cluster.family` — return '076923' or '153846' for a
  given layer type ('task'|'template'|'design' → lower; 'intent'|'address'
  → upper). the gate always returns '13th'.

- `src/branch.cluster.mirror` — given a cluster, generate the
  meta-cluster (the 5+1+5 reflection). the meta-cluster has the same
  five layers, but each layer is the meta-equivalent of the original:
    task → task-about-task
    template → template-about-template
    etc.
  return the meta-cluster structure without writing to disk.

- `src/branch.cluster.validate` — check that a cluster has:
  - all five layer entries populated (non-empty lists)
  - a gate address computed
  - ring position consistent with address
  return list of missing/invalid items.

- `src/branch.cluster.register` — write cluster yaml to
  `data/yaml/cluster-registry/<name>.yaml`. compute address and ring
  position if not already set. refuse to register if validate() fails.

## yaml registry location

`data/yaml/cluster-registry/` — one yaml per cluster, keyed by cluster name.

`data/yaml/cluster-registry/_index.yaml` — list of all registered clusters
with their addresses and ring positions, for fast lookup without loading
each cluster in full:

```yaml
clusters:
  branch-open-capacity-session-dag:
    address:  <bmw384_hex>
    ring_pos: 4
  cred-mesh:
    address:  <bmw384_hex>
    ring_pos: 9
```

## applying the pattern to existing work

the three proxy/transport/credential task files from this session are
instances of this cluster pattern. they currently have only layer 1 (task).
to complete their clusters:

```
cred-mesh cluster:
  layer 1  task:     data/tasks/cred-mesh.md
  layer 2  template: data/yaml/reasoning-templates/  (to be written)
  layer 3  design:   data/md/design/PRIVACY-PRESERVING-IDENTITY-CREDENTIALS.md
  layer 4  intent:   (to be written)
  layer 5  address:  (derived by branch.cluster.address)
```

## style

- `$ARG` not `$_`; `@ARG` not `@_`
- yaml I/O via existing `format.yaml.load_file` / `format.yaml.write_file`
- bmw384 via `AMOS7::Digest::BMW::bmw384`
- lowercase comments, `[ word ]` bracket annotations

## acceptance

- `p7c branch.cluster.address <name>` returns consistent bmw384 hex
- `p7c branch.cluster.ring_position <name>` returns 0..12
- `p7c branch.cluster.validate <name>` lists missing layers cleanly
- register writes yaml and updates _index.yaml
- mirror returns valid 5+1+5 structure without writing to disk

#,,,,,..,,..,,,,,,,,,,.,.,,,,,.,.,...,,,,,,,,,..,,...,...,...,..,,,,.,,,,,..,,
#3KPLZHGPLNYGXXGZKJANB2EJFLIC4RG5UORODFTOPAK5L2BGSZAVKXBCEGRZMLBMPXQEW6BR4AA3E
#\\\|UK3SXIC3MPWLZBYKCYAS2OEL4PZVVJ4TY2OPUTDZYB6XTF4AHTX \ / AMOS7 \ YOURUM ::
#\[7]LX76U2ZGIWTFN6YW572CJIWMGB4NKK63LZZPORUOU4MF2XQFGIAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
