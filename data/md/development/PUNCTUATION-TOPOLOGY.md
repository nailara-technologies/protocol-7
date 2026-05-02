# punctuation topology

## the grammar

two primitives:

- `:` — group boundary [ context separator ]
- `.` — element separator within a group

everything is a group. every group has a parent group context.
every element can itself be a group at the next scale down.

## addressing

`:PKHKHVA:` — a group [ single element, self-contained ]

`:SBEY65I:ZS2G6KA:` — a chain of two groups [ sequential ]

`:DUPSSGA.P3DNMNY.WTLJD5Y:` — a group of three elements

`:DUPSSGA.P3DNMNY.WTLJD5Y:PKHKHVA:YCQFM6Y.6D7XP4I:` — a chain of
three groups: one of 3 elements, one of 1, one of 2

## scale independence

the grammar is identical at every scale. what reads as a group at one
resolution reads as an element at the next scale up. there is no
structural difference between:

- a task and a sub-task
- a session and a session element
- a route hop and a route
- a cache key and a cache namespace
- a node and a node group

the scale is context, not syntax. zoom in or out along any address
without changing the grammar.

## self-similarity

because `:` and `.` carry the same meaning at every scale, the address
space is fractal. reading `:DUPSSGA.P3DNMNY.WTLJD5Y:PKHKHVA:` at the
task level gives you a task chain. reading the same string at the
routing level gives you a route with hops. reading it at the caching
level gives you a cache path. the string doesn't change — the
interpretation scales with the reader's context.

## overlapping categories

source and target are relative in a route — the same node is source
from one direction and target from another. the same applies here:

- what is a parent group from below is a single element from above
- what is a task chain in one context is a single task in another
- compartmentalization is always relative, never absolute

this is not a limitation — it is the topology. every address is
simultaneously a leaf and a branch depending on which scale is active.

## atoms

AMOS7 checksums [ 7 characters, `[A-Z0-9]{7}` ] are the natural atoms
of this grammar. each node already has a unique 7-character identity
that fits cleanly into the `.` slot. the address space is already
present in the checksum space — the punctuation makes it navigable.

## applications [ partial list ]

the grammar is universal. every routing or addressing problem maps onto it:

- **task routing**: `:task-id.subtask:chain-step:` — work route
- **session addressing**: `:session.element:context:` — session range
- **cache paths**: `:namespace.key:version:` — cache route
- **network routing**: `:source.hop.hop:target:` — packet route
- **context addressing**: `:task.round.message:` — context range
- **node groups**: `:group.node.node:cluster:` — topology address
- **time ranges**: `:start.end:resolution:` — temporal route
- **model routing**: `:model.backend:task-type:` — inference route
- **log addressing**: `:zenka.session.line:level:` — log range
- **file paths**: `:dir.subdir.file:version:` — content address
- **protocol framing**: `:cmd-type.cmd-id:reply-type:` — wire format
- **documentation**: `:section.subsection:anchor:` — addressable docs
- **symlink chains**: `:link.link.target:context:` — waypoint routes

the list is open-ended. every domain that has hierarchy, sequence, or
grouping maps onto `:` and `.`.

## relationship to existing syntax

the `::` command prefix, the `:.` and `.:` log markers, the `:::`
section headers — these are already instances of this grammar in use.
the topology was always present. this document names it.

the `::` shell alias for `p7c` is `:` doubled — a command is a
group-level address into the network. `:::` would be a deeper group
context. `:.:` a group containing an element containing a group.
each form is already available as a symlink target with distinct meaning.

## the route as the thing

a session is a range of a route. a task is a range of a work route.
a cache hit is a range of a caching route. the route is not a path
*to* the thing — the route *is* the thing, read at the appropriate
resolution.

this unifies what otherwise appear to be different concepts:
routing, scheduling, caching, addressing, logging, documentation.
they are all the same topology at different scales. `[:<`

#,,,,,.,.,.,,,..,,,.,,.,,,.,.,.,,,,.,,.,,,.,,,..,,...,..,,,,,,.,,,,.,,.,.,,,.,
#5HZYIYXTNEZDPYQYYYFUZSUHGYOHJKWPU5S3BUJ2ISQ4AWNB2VVDWXV3OEI3QVKRS3W2HQUFNYQBS
#\\\|PYAF6KCHUSZXW5RBJLXJVJD3SBOB5ANCLZ6ZU7EUV2BHYU7CAWF \ / AMOS7 \ YOURUM ::
#\[7]GAGXZUZXCZKDMNB4ANC7CFQ7HXRXGAJZZASKSISWMZXQEU5T3KDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
