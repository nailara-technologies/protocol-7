## [:< ##

# task: similarity graph — cell connections and cluster visibility

add a graph layer to the graphics-matrix lattice. edges connect cells
that share similarity. clusters are groups of cells with high mutual
similarity. the graph makes relationships visible: connected cells
share glow influence, clusters appear as glow regions, gaps between
clusters are dark.

this is step 5 of the critical path: "similarity graph renders as
cross-mapped curves". the graph layer stores and queries connections.
the similarity scores themselves come from above (vision pipeline,
manual assignment, or namespace queries) — this layer does not compute
similarity, it stores and renders it.

this task depends on: lattice-cell-storage-namespace-bridge.md
— cells must exist before edges can connect them.


## p7 code style (strictly enforced)

- lowercase comments, [ brackets ] for annotations, no capitals in comments
- `$ARG` not `$_`
- `<[module.name]>->($args)` with args — closing `]>` before `->`
- `<[module.name]>` with no args — do NOT add `->()`, the code parser adds it
- `:flag:` not `--flag`
- `$call->{'args'}` not `$call_args` in cmd modules
- cmd modules: `return { mode => 'size', data => $str }` for output
  `return { mode => 'false', data => 'error text' }` for errors
- do NOT generate any footer lines whatsoever — signing adds the full AMOS7 footer
- do NOT add `#,,...` stub lines
- syntax check with `ptd -c`, not `perl -c`
- new module header format: `## [:< ##\n\n# name  = ...\n# descr = ...`
- log levels: 0=error, 1=default, 2=info, 3=debug
- do NOT use `SUPER::` — not valid in P7 module system
- do NOT swap namespace prefixes


## key reference files — read these first

    modules/graphics-matrix.cell.place           — cell creation and reference counting
    modules/graphics-matrix.cell.query           — cell lookup by position or address
    modules/graphics-matrix.cell.survey          — hop-distance counting for glow bridge
    modules/graphics-matrix.cell.list            — listing cells with sorting
    modules/graphics-matrix.glow.compute         — intensity computation from counts
    modules/graphics-matrix.address.resolve      — address resolution
    modules/graphics-matrix.cmd.cell             — command pattern with survey→glow bridge


## architecture

the graph lives in the `%data` tree under `graphics-matrix.graph`:

    $data{'graphics-matrix'}{'graph'} = {
        'edges'    => {},    ## "keyA|keyB" => edge hashref
        'clusters' => {},    ## cluster_id => cluster hashref
        'count'    => 0,     ## total edge count
    };

edge key is canonical: the two cell keys sorted alphabetically, joined
by "|". this ensures each pair has exactly one edge regardless of
direction.

    $data{'graphics-matrix'}{'graph'}{'edges'}{'0:0:0|1:0:0'} = {
        'a'      => '0:0:0',          ## cell key A
        'b'      => '1:0:0',          ## cell key B
        'weight' => 0.75,             ## similarity score 0.0-1.0
        'type'   => 'similarity',     ## edge type
        'created' => 1713200000,
    };

clusters group cell keys:

    $data{'graphics-matrix'}{'graph'}{'clusters'}{'c001'} = {
        'id'      => 'c001',
        'members' => ['0:0:0', '1:0:0', '0:1:0'],   ## cell keys
        'center'  => '0:0:0',                         ## centroid cell
        'weight'  => 0.72,      ## average internal edge weight
    };


## glow bridge for graph visibility

the graph influences glow through two mechanisms:

1. edge-weighted survey: when surveying, cells connected to the cursor
   cell contribute their refs multiplied by the edge weight. a cell
   at hop 2 with weight 0.8 and refs 3 contributes 3 * 0.8 = 2.4
   to the hop 2 count. unconnected cells contribute nothing (or a
   small base amount). this makes connected regions glow together.

2. cluster glow: all cells in the same cluster share a base glow
   boost. surveying from any cluster member sees the whole cluster
   as a glowing region.


## files to create

### modules/graphics-matrix.graph.init

    # name  = graphics-matrix.graph.init
    # descr = initialize similarity graph state

    set up $data{'graphics-matrix'}{'graph'} with empty state:
        'edges'    => {}
        'clusters' => {}
        'count'    => 0

    log at level 2: "graph initialized"


### modules/graphics-matrix.graph.connect

    # name  = graphics-matrix.graph.connect
    # descr = create or update an edge between two cells

    my $params = shift // {};

    accept hashref:
        a      => cell key or address string (required)
        b      => cell key or address string (required)
        weight => 0.0-1.0 (default 0.5)
        type   => string (default 'similarity')

    if a or b is not a "x:y:z" key format, resolve via address.resolve
    and compute canonical key.

    canonical edge key: sort [a, b] alphabetically, join with "|".

    if edge exists: update weight (keep higher value).
    if new: create edge, increment count.

    verify both cells exist in cell storage. if not, return error.

    log at level 2: "graph.connect [%s] — [%s] weight=%.2f"

    return the edge hashref.


### modules/graphics-matrix.graph.disconnect

    # name  = graphics-matrix.graph.disconnect
    # descr = remove an edge between two cells

    my $params = shift // {};

    accept hashref:
        a => cell key or address string (required)
        b => cell key or address string (required)

    compute canonical edge key.
    delete edge if exists, decrement count.

    return { removed => boolean }


### modules/graphics-matrix.graph.neighbors

    # name  = graphics-matrix.graph.neighbors
    # descr = find all cells connected to a given cell

    my $input = shift // '';

    accept cell key string or address string.
    resolve to canonical key if needed.

    scan all edges for this cell key (in position a or b).

    return arrayref of:
        [ { cell => key, weight => F, edge_key => "a|b" }, ... ]

    sorted by weight descending.


### modules/graphics-matrix.graph.cluster

    # name  = graphics-matrix.graph.cluster
    # descr = auto-cluster connected cells by edge weight

    my $params = shift // {};

    accept hashref:
        threshold => 0.0-1.0 (default 0.55, minimum edge weight
                     for cluster membership)

    algorithm: simple connected components with weight threshold.
        - start with all cells as unvisited
        - for each unvisited cell, BFS/DFS through edges with
          weight >= threshold
        - each connected component becomes a cluster
        - cluster id: "c" + 3-digit sequential number
        - cluster center: member with highest total edge weight sum
        - cluster weight: average of internal edge weights

    store clusters in $data{'graphics-matrix'}{'graph'}{'clusters'}.

    log at level 1: "graph.cluster: %d clusters from %d cells"

    return { clusters => N, cells => N, threshold => F }


### modules/graphics-matrix.graph.survey

    # name  = graphics-matrix.graph.survey
    # descr = survey cells with graph-weighted influence

    my $params = shift // {};

    accept hashref:
        center => { selX, selY, selZ } (optional, defaults to cursor)
        radius => N (optional, defaults to cursor radius)

    like cell.survey, but edge-weighted:
        - find the center cell key
        - get all neighbors via graph.neighbors
        - for each occupied cell within radius:
            if connected to center: count += refs * edge_weight
            if same cluster as center: count += refs * cluster_boost (0.3)
            if unconnected: count += refs * base_factor (0.1)
        - group counts by hop distance

    return { counts => { hop => N }, total => N }

    this output feeds glow.compute just like cell.survey does.


### modules/graphics-matrix.cmd.graph

    # name  = graphics-matrix.cmd.graph
    # descr = manage similarity graph and visualize connections

    parse $call->{'args'}:
        no args               → show graph stats
        "connect <a> <b> [w]" → create edge (weight optional)
        "disconnect <a> <b>"  → remove edge
        "neighbors"           → show neighbors of cursor cell
        "neighbors <addr>"    → show neighbors of address
        "cluster"             → auto-cluster with default threshold
        "cluster <threshold>" → auto-cluster with custom threshold
        "clusters"            → list all clusters
        "survey"              → graph-weighted survey → glow
        "edges"               → list all edges

    for "connect": parse two addresses and optional weight.
        connect 0,0,0 1,0,0 0.8

    for "survey": call graph.survey, feed to glow.compute,
        display like cmd.cell survey does.

    for "neighbors":
        neighbors of [0,0,0]:
          [1,0,0]  weight=0.80
          [0,1,0]  weight=0.65
          [0,0,1]  weight=0.45

    for "clusters":
        3 clusters (threshold=0.55):
          c001: 3 members, center=[0,0,0], avg=0.72
          c002: 2 members, center=[5,5,0], avg=0.61
          c003: 1 member,  center=[10,0,0], avg=0.00

    for "edges":
        5 edges:
          [0,0,0] — [1,0,0]  w=0.80  (similarity)
          [0,0,0] — [0,1,0]  w=0.65  (similarity)
          ...

    return { mode => 'size', data => $out }


## modifications to existing files

### modules/graphics-matrix.init_code

add graph initialization after cell init, before `0;`:

    ## initialize similarity graph ##
    <[graphics-matrix.graph.init]>;

### configuration/zenki/graphics-matrix/start

add `graph` to the access.cmd.usr.cube line.


## verify

    ptd -c on all 7 new module files
    check zero footer lines — no `#,,...` stubs
    verify <[module.name]> syntax — ]> before -> when args, no ->() when no args
    verify $ARG not $_ throughout
    verify lowercase comments
    verify edge key canonicalization (sorted alphabetically)
    verify graph.survey output is compatible with glow.compute input format
    verify graph.cluster produces correct connected components
    verify cmd.graph connect parses addresses correctly

#,,.,,.,,,,,,,..,,,.,,.,,,.,.,..,,.,.,,,.,.,,,..,,...,..,,,..,,..,,,,,,,,,.,.,
#6ZVEG5EYJOQMOPAAGBPJKJ3SZRJZUGKVQB3CIHD3Q5AFGLINPELN32MET6GSB7C33OJ4PHPJZWPVY
#\\\|K4PMIHMGLM5HGTCGNCIMQXUQHHGHGAAR63QOPSPUIRPM3QQ2AEC \ / AMOS7 \ YOURUM ::
#\[7]ZIPR4WQXLEUJFEGJVDLAEY5ISKUBXKW3JZHBSLOS3AMYKBD466CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
