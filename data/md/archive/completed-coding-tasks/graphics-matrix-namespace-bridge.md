## [:< ##

# task: graphics-matrix namespace bridge — cursor position as live command target

wire the grid-hardnode cursor's selX/selY/selZ coordinates as a live command
interface through the graphics-matrix zenka. this is the keystone connection
that bridges the 3D holographic visualization to the P7 network.

the graphics-matrix zenka already exists (28 modules, document processing +
visual pipeline). it needs cursor navigation commands that expose a 3D position
as routable namespace state — so other zenki can query and set the cursor.


## p7 code style (strictly enforced)

- lowercase comments, [ brackets ] for annotations, no capitals in comments
- `$ARG` not `$_`
- `<[module.name]>->($args)` with args — closing `]>` before `->`
- `<[module.name]>` with no args — do NOT add `->()`, the code parser adds it
- `:flag:` not `--flag`
- `$call->{'args'}` not `$call_args` in cmd modules
- cmd modules: `return { mode => 'size', data => $str }` for output
  `return { mode => 'false', data => 'error text' }` for errors
  `$reply` is pre-declared as a hashref in cmd scope — use `my $out` for strings
- do NOT generate any footer lines whatsoever — signing adds the full AMOS7 footer
- do NOT add `#,,...` stub lines
- syntax check with `ptd -c`, not `perl -c`
- new module header format: `## [:< ##\n\n# name  = ...\n# descr = ...`
- log levels: 0=error, 1=default, 2=info, 3=debug
- log format: `<[base.logs]>->( $level, 'format %s', $arg )`
- config access: `<graphics-matrix.cursor.selX>` not `$data{'cfg'}{'...'}`
- do NOT use `SUPER::` — not valid in P7 module system
- do NOT swap namespace prefixes — if a module is `graphics-matrix.cursor.*`,
  its internal calls use `graphics-matrix.cursor.*`, NOT `graphics.matrix.*`


## key reference files — read these first

    src/graphics-3d.init_code                — 8x7x13 voxel grid, cursor state, 60fps render
    src/graphics-3d.handler.cursor_navigate  — cursor navigation with wrap-around
    src/graphics-3d.render.cursor            — cursor rendering with translucency
    src/graphics-3d.cfg.cursor               — cursor config setup pattern
    src/graphics-matrix.init_code            — existing graphics-matrix init (extend this)
    cfg/zenki/graphics-matrix/start    — existing start file (add new cmds to access list)
    data/md/design/GRID-HARDNODE-CURSOR-MODEL.md — full cursor design spec


## architecture

the cursor lives in the `%data` tree under `graphics-matrix.cursor`:

    $data{'graphics-matrix'}{'cursor'} = {
        'selX'   => 0,       ## integer grid coordinates — unlimited range
        'selY'   => 0,
        'selZ'   => 0,
        'zoom'   => 1.0,     ## float — continuous zoom level
        'radius' => 1,       ## integer — visibility radius in hops
    };

cursor state is content-addressable: same position = same checksum.
the checksum is computed on demand, not cached.


## files to create

### src/graphics-matrix.cursor.init

    # name  = graphics-matrix.cursor.init
    # descr = initialize cursor state in graphics-matrix namespace

    set up cursor state in $data{'graphics-matrix'}{'cursor'} with defaults:
        selX => 0, selY => 0, selZ => 0
        zoom => 1.0
        radius => 1

    read optional config overrides:
        <graphics-matrix.cursor.initial_x> // 0
        <graphics-matrix.cursor.initial_y> // 0
        <graphics-matrix.cursor.initial_z> // 0

    log: "cursor initialized at [%d,%d,%d]"


### src/graphics-matrix.cursor.move

    # name  = graphics-matrix.cursor.move
    # descr = move cursor by relative offset

    my $params = shift // {};

    accept hashref with optional dx, dy, dz (integers, default 0).
    add deltas to current selX/selY/selZ.
    no bounds clamping — coordinates are unlimited integers.

    log at level 2: "cursor.move [%d,%d,%d] → [%d,%d,%d]"

    return the new position hashref { selX => N, selY => N, selZ => N }.


### src/graphics-matrix.cursor.position

    # name  = graphics-matrix.cursor.position
    # descr = return current cursor position and state

    return a copy of $data{'graphics-matrix'}{'cursor'} (shallow copy).
    do not return a reference to the live hash.


### src/graphics-matrix.cursor.set

    # name  = graphics-matrix.cursor.set
    # descr = set cursor to absolute position

    my $params = shift // {};

    accept hashref: selX, selY, selZ, zoom, radius (all optional).
    only update fields that are defined in $params.
    validate: zoom must be > 0. radius must be >= 0 integer.

    log at level 2: "cursor.set → [%d,%d,%d] zoom=%.2f radius=%d"

    return the new full state hashref (copy).


### src/graphics-matrix.cursor.checksum

    # name  = graphics-matrix.cursor.checksum
    # descr = compute content-address checksum of current cursor state

    build a canonical string from cursor state:
        my $canonical = sprintf "%d:%d:%d:%.6f:%d",
            $cursor->{'selX'}, $cursor->{'selY'}, $cursor->{'selZ'},
            $cursor->{'zoom'}, $cursor->{'radius'};

    compute AMOS checksum via <[base.chk-sum.amos]>->($canonical)
    return the checksum string.


### src/graphics-matrix.cmd.cursor

    # name  = graphics-matrix.cmd.cursor
    # descr = query or move the grid-hardnode cursor

    parse $call->{'args'}:
        no args              → show current position + checksum
        "move dx dy dz"      → relative move [ all three required ]
        "set x y z"          → absolute position
        "zoom level"         → set zoom level (float)
        "radius N"           → set visibility radius

    for "move": call <[graphics-matrix.cursor.move]>->({ dx => $dx, ... })
    for "set":  call <[graphics-matrix.cursor.set]>->({ selX => $x, ... })
    for "zoom": call <[graphics-matrix.cursor.set]>->({ zoom => $level })
    for "radius": call <[graphics-matrix.cursor.set]>->({ radius => $n })
    for no args: call <[graphics-matrix.cursor.position]>

    always show: position, zoom, radius, checksum
    format:
        cursor [%d,%d,%d] zoom=%.2f radius=%d chk=%s

    return { mode => 'size', data => $out }


### src/graphics-matrix.cmd.cursor-state

    # name  = graphics-matrix.cmd.cursor-state
    # descr = return cursor state as structured data for other zenki

    call <[graphics-matrix.cursor.position]>
    add checksum via <[graphics-matrix.cursor.checksum]>
    format as single-line key=value pairs:
        selX=0 selY=0 selZ=0 zoom=1.00 radius=1 chk=ABCDEF

    return { mode => 'size', data => "$out\n" }


## modifications to existing files

### cfg/zenki/graphics-matrix/start

add `cursor cursor-state` to the access.cmd.usr.cube line.
do NOT rewrite the file — just add the two command names.

### src/graphics-matrix.init_code

add cursor initialization at the end, before the `0;` return:

    ## initialize cursor state ##
    <[graphics-matrix.cursor.init]>;

### cfg/zenki/graphics-matrix/subroutine.white-list

if this file exists, add the new modules. if not, check whether the zenka
uses wildcard loading — the start file loads `modules.load = ... graphics-matrix
graphics.matrix` which may already include all matching modules. in that case,
no white-list update is needed. look at other zenki white-lists for format
reference: `cfg/zenki/invoke-web/subroutine.white-list`


## verify

    ptd -c on all 6 new module files
    check zero footer lines — no `#,,...` stubs
    check the cmd module return format: { mode => 'size', data => $string }
    verify <[module.name]> syntax — ]> before -> when args, no ->() when no args
    verify $ARG not $_ throughout
    verify lowercase comments

#,,..,,.,,,..,.,,,,..,.,,,,,.,,,,,..,,.,,,.,.,..,,...,..,,..,,,,,,.,,,.,.,.,.,
#U4HRENJM52HTREF2LUMVNO2QNPHTH67GU7OAMJO5UUNCFKIRSRA4G37OXEOUUI4EEZQMVNLPVOUYW
#\\\|RODKDWLZC7FQJWPOEQO2XALHQG4LAWNCPFTFFHBZSFWV5JUQJFM \ / AMOS7 \ YOURUM ::
#\[7]Y556RWF6Y2LOPG47IAXRMBS6BWMJ4AW5VSHIRCUNNTMX5IPGN2CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
