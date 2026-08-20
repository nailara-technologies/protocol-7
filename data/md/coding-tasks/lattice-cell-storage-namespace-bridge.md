## [:< ##

# task: lattice cell storage — namespace bridge for element placement

add a cell storage layer to the graphics-matrix grid. cells are the
lattice positions where elements live. each cell holds a reference
count and an element list. the glow system reads cell reference counts
to compute intensity — occupied cells glow, empty cells stay dark.

this is step 4 of the critical path: "element detection feeds namespace".
the cell layer is the receiver — it does not detect elements, it stores
them. detection (vision.*, manual placement, namespace queries) feeds
into this layer from above. the grid renders occupied cells automatically
because glow intensity already exists and only needs reference counts.

this task depends on: cursor-address-resolution-layer.md
— addresses must resolve before cells can be placed by address.


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

    modules/graphics-matrix.glow.compute         — reads reference counts to compute intensity
    modules/graphics-matrix.address.resolve      — resolves any address scheme to coordinates
    modules/graphics-matrix.address.register     — registers positions in address registry
    modules/graphics-matrix.cursor.position      — returns cursor state
    modules/graphics-matrix.channel.translate    — translates intensity to channel color
    modules/graphics-matrix.cmd.glow             — glow command pattern
    modules/graphics-matrix.cmd.address          — address command pattern


## architecture

cells live in the `%data` tree under `graphics-matrix.cell`:

    $data{'graphics-matrix'}{'cell'} = {
        'cells' => {},    ## "x:y:z" => cell hashref
        'count' => 0,     ## total occupied cells
    };

each cell is keyed by canonical coordinate string "x:y:z":

    $data{'graphics-matrix'}{'cell'}{'cells'}{'42:17:3'} = {
        'position' => { 'selX' => 42, 'selY' => 17, 'selZ' => 3 },
        'refs'     => 1,           ## reference count — drives glow
        'elements' => [],          ## list of element hashrefs
        'checksum' => 'A3F2B7C',   ## address checksum for this position
        'created'  => 1713200000,  ## timestamp
        'modified' => 1713200000,  ## last modification timestamp
    };


## the glow bridge

the key connection: when glow.compute is called, it should be able to
read cell reference counts as its input. currently glow.compute accepts
explicit counts per hop. the cell layer provides a new source:

    cell.survey reads all occupied cells relative to cursor position,
    groups them by hop distance, sums reference counts per hop,
    and returns the counts hash that glow.compute already accepts.

this is the bridge: cells exist → survey counts refs by hop →
glow.compute produces intensity → channel.translate renders color.
no new rendering code. the grid lights up where elements are placed.


## files to create

### modules/graphics-matrix.cell.init

    # name  = graphics-matrix.cell.init
    # descr = initialize lattice cell storage

    set up $data{'graphics-matrix'}{'cell'} with empty state:
        'cells' => {}
        'count' => 0

    log at level 2: "cell storage initialized"


### modules/graphics-matrix.cell.place

    # name  = graphics-matrix.cell.place
    # descr = place an element at a grid position

    my $params = shift // {};

    accept hashref:
        position => { selX, selY, selZ } (optional, defaults to cursor)
        element  => hashref (optional, generic element data)
        label    => string (optional, human-readable label)

    compute canonical key: sprintf "%d:%d:%d", selX, selY, selZ

    if cell exists: increment refs, push element to elements list
    if cell is new: create cell structure, set refs=1, register address

    update 'modified' timestamp.

    log at level 2: "cell.place [%d,%d,%d] refs=%d"

    return the cell hashref.


### modules/graphics-matrix.cell.remove

    # name  = graphics-matrix.cell.remove
    # descr = remove an element reference from a grid position

    my $params = shift // {};

    accept hashref:
        position => { selX, selY, selZ } (optional, defaults to cursor)
        clear    => 1 (optional, removes entire cell regardless of refs)

    compute canonical key.

    if 'clear': delete cell entirely, decrement count.
    else: decrement refs. if refs reaches 0, delete cell, decrement count.

    log at level 2: "cell.remove [%d,%d,%d] refs=%d"

    return { removed => boolean, refs => remaining count }


### modules/graphics-matrix.cell.query

    # name  = graphics-matrix.cell.query
    # descr = query cell state at a grid position

    my $input = shift // '';

    accept either:
        - hashref with position => { selX, selY, selZ }
        - string address (passed to <[graphics-matrix.address.resolve]>)

    compute canonical key.

    if cell exists: return the cell hashref (copy).
    if empty: return { empty => 1, position => { ... } }


### modules/graphics-matrix.cell.survey

    # name  = graphics-matrix.cell.survey
    # descr = survey occupied cells by hop distance from cursor

    my $params = shift // {};

    accept hashref:
        center => { selX, selY, selZ } (optional, defaults to cursor)
        radius => N (optional, defaults to cursor radius)

    iterate all occupied cells. for each:
        compute manhattan distance from center:
            hop = abs(x - cx) + abs(y - cy) + abs(z - cz)
        skip if hop > radius (when radius > 0)
        accumulate: counts{hop} += cell refs

    return hashref: { counts => { 0 => N, 1 => N, ... }, total => N }

    this output feeds directly into glow.compute:
        <[graphics-matrix.glow.compute]>->( { qw| counts | => $survey->{'counts'} } );


### modules/graphics-matrix.cell.list

    # name  = graphics-matrix.cell.list
    # descr = list occupied cells with optional filtering

    my $params = shift // {};

    accept hashref:
        center => { selX, selY, selZ } (optional)
        radius => N (optional, limits by distance)
        limit  => N (optional, max results, default 20)
        sort   => 'refs' or 'distance' or 'recent' (default 'distance')

    return arrayref of cell summaries:
        [ { key => "x:y:z", refs => N, distance => N, elements => N }, ... ]


### modules/graphics-matrix.cmd.cell

    # name  = graphics-matrix.cmd.cell
    # descr = place, query, and manage lattice cells

    parse $call->{'args'}:
        no args              → show cell at cursor position (or "empty")
        "place"              → place element at cursor
        "place <addr>"       → place element at address
        "remove"             → remove ref at cursor
        "remove <addr>"      → remove ref at address
        "clear"              → clear cell at cursor entirely
        "clear <addr>"       → clear cell at address
        "query <addr>"       → query cell at address
        "survey"             → survey from cursor, feed to glow.compute
        "list"               → list occupied cells near cursor
        "count"              → show total occupied cell count

    for "place": call <[graphics-matrix.cell.place]>
    for "survey": call <[graphics-matrix.cell.survey]>, then
        feed result into <[graphics-matrix.glow.compute]>,
        display glow output like cmd.glow does.

    display for occupied cell:
        cell [42,17,3] refs=3 chk=A3F2B7C
          elements: 3
          created: 2026-04-16 14:30:00
          modified: 2026-04-16 15:45:00

    display for empty:
        cell [42,17,3] empty

    for "list":
        3 occupied cells within radius 5:
          [42,17,3]  refs=3  hop=0  chk=A3F2B7C
          [43,17,3]  refs=1  hop=1  chk=B2E4F1A
          [42,18,3]  refs=1  hop=1  chk=C5D3A2B

    return { mode => 'size', data => $out }


## modifications to existing files

### modules/graphics-matrix.init_code

add cell initialization after address init, before `0;`:

    ## initialize cell storage ##
    <[graphics-matrix.cell.init]>;

### cfg/zenki/graphics-matrix/start

add `cell` to the access.cmd.usr.cube line.


## verify

    ptd -c on all 7 new module files
    check zero footer lines — no `#,,...` stubs
    verify <[module.name]> syntax — ]> before -> when args, no ->() when no args
    verify $ARG not $_ throughout
    verify lowercase comments
    verify cell.survey output is compatible with glow.compute input format
    verify cell.query accepts both hashref and string address
    verify cmd.cell survey subcommand feeds glow.compute and displays result

#,,,.,,,,,..,,.,.,,..,...,.,.,.,.,,,,,,.,,..,,..,,...,.,.,,,.,,..,.,,,,..,,.,,
#U4LL6X4FIAUTXJPN7KZ7LTWLX3N4CW2NQL6RJH2F4FAUBX7WCG6BNC6ETPL7NXNFYFNZ2D2NJX6ZI
#\\\|CDPRAI7ICZ6FB5CPYRLV3DNCPM5LMOUATEAEOTQYV4U45IARD4H \ / AMOS7 \ YOURUM ::
#\[7]3NPPYMCBMHJSZKSVU5B6NFSES33XZUGDLCSR2GOZ4IKFRTX5OICQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
