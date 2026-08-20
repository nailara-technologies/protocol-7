## [:< ##

# task: cursor address resolution — multi-scheme position addressing

add an address resolution layer to the graphics-matrix cursor. the same
grid position can be addressed through multiple schemes — checksum,
decimal coordinates, packed numeric, directional routing, or label.
the resolver accepts any scheme and returns internal coordinates.

which scheme is most useful in which context or on which layer will
crystallize automatically — the interface must not prefer one over
another. all schemes coexist through a single resolve entry point.

this task depends on: context-channel-frequency-separation.md
— channels must exist before address display can include channel context.


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

    modules/graphics-matrix.cursor.set          — current absolute position setter
    modules/graphics-matrix.cursor.position     — returns cursor state copy
    modules/graphics-matrix.cursor.checksum     — AMOS checksum of position
    modules/graphics-matrix.cursor.move         — relative movement
    modules/graphics-matrix.cmd.cursor          — existing command interface
    modules/graphics-matrix.channel.current     — active channel context
    bin/dev/division-13-table
        — directional routing protocol: UP/LEFT/RIGHT/DOWN + hop count
          from the 7-bit decoded field (lines 139-199)


## addressing schemes

the resolver accepts any of these formats and returns { selX, selY, selZ }:

### 1. decimal coordinates (current default)

    "42,17,3"    or    "42 17 3"

    direct integer triple. what cursor.set already uses.

### 2. checksum address

    "CHKSUM7"    (7-char uppercase hex-like string)

    looks up position from the address registry — a reverse map from
    checksum to coordinates. the registry is populated whenever a cursor
    position is set or moved (checksum computed, stored as key).

    $data{'graphics-matrix'}{'address'}{'checksum'} = {
        'A3F2B7C' => { 'selX' => 42, 'selY' => 17, 'selZ' => 3 },
        ...
    };

### 3. directional routing (division-13-table protocol)

    "U3"    = move UP 3 hops from current position
    "L1"    = move LEFT 1 hop
    "R5"    = move RIGHT 5 hops
    "D2"    = move DOWN 2 hops

    relative addressing using the 4-direction + hop count format from
    the division-13-table 7-bit decoded field. direction mapping:

        U = +Y (up)
        D = -Y (down)
        L = -X (left)
        R = +X (right)

    Z axis not encoded in this scheme (stays current). this is the
    cursor equivalent of the protocol's directional routing opcode.

### 4. octal-7 packed

    "o7:52.21.03"

    each coordinate packed as 2-digit octal value (base 8), giving
    0-63 range per axis. the "o7:" prefix identifies the scheme.
    dot-separated. compact for 7-bit field contexts.

### 5. base32 label

    "b32:KQTE"

    position encoded as base32 string (5 bits per character).
    3 coordinates * 7 bits each = 21 bits = ~5 base32 chars.
    the "b32:" prefix identifies the scheme.

### 6. channel-qualified address

    "f2@42,17,3"    or    "f2@CHKSUM7"    or    "f2@U3"

    any scheme prefixed with channel label + "@". resolves the position
    using the scheme after "@", and also sets the viewing channel.
    this is how multi-cursor multi-channel views are addressed.


## architecture

the address registry lives at:

    $data{'graphics-matrix'}{'address'} = {
        'checksum' => {},    ## chksum → { selX, selY, selZ }
        'label'    => {},    ## name → { selX, selY, selZ }
    };


## files to create

### modules/graphics-matrix.address.resolve

    # name  = graphics-matrix.address.resolve
    # descr = resolve any addressing scheme to grid coordinates

    my $input = shift // '';

    detect scheme from input format:
        - starts with letter + digit(s), length 2-3, letter in [UDLR]
          → directional routing
        - matches m/^[A-Z0-9]{7}$/ → checksum lookup
        - starts with "o7:" → octal-7 packed
        - starts with "b32:" → base32 label
        - contains "@" → split into channel + recurse on remainder
        - contains "," or spaces with integers → decimal coordinates
        - else → try label lookup, then error

    return hashref:
        { selX => N, selY => N, selZ => N,
          scheme => 'decimal|checksum|route|octal7|base32|label',
          channel => N or undef }

    on error: return { mode => 'false', data => 'reason' }


### modules/graphics-matrix.address.encode

    # name  = graphics-matrix.address.encode
    # descr = encode grid position in a specific addressing scheme

    my $params = shift // {};

    accept hashref:
        position => { selX, selY, selZ } (optional, defaults to current cursor)
        scheme   => 'decimal|checksum|octal7|base32' (required)

    return the encoded string for the given scheme:
        decimal  → "42,17,3"
        checksum → result of <[graphics-matrix.cursor.checksum]>
                   (set cursor temporarily if position differs, or compute
                   canonical string + checksum inline)
        octal7   → "o7:52.21.03"
        base32   → "b32:KQTE"

    for checksum: also register in the address registry.


### modules/graphics-matrix.address.register

    # name  = graphics-matrix.address.register
    # descr = register a position in the address registry

    my $params = shift // {};

    accept hashref:
        position => { selX, selY, selZ } (required)
        checksum => string (optional, computed if missing)
        label    => string (optional, named bookmark)

    compute checksum if not provided:
        use same canonical format as cursor.checksum:
        sprintf "%d:%d:%d:%.6f:%d", selX, selY, selZ, zoom, radius
        then <[base.chk-sum.amos]>

    store in registry:
        $data{'graphics-matrix'}{'address'}{'checksum'}{$chk} = $pos;
        $data{'graphics-matrix'}{'address'}{'label'}{$label} = $pos
            if label defined;

    log at level 3: "address.register [%s] → [%d,%d,%d]"

    return { checksum => $chk, position => $pos }


### modules/graphics-matrix.address.init

    # name  = graphics-matrix.address.init
    # descr = initialize address registry

    set up $data{'graphics-matrix'}{'address'}:
        'checksum' => {}
        'label'    => {}

    register current cursor position (origin) in registry.

    log at level 2: "address registry initialized"


### modules/graphics-matrix.cmd.address

    # name  = graphics-matrix.cmd.address
    # descr = resolve, encode, and manage cursor addresses

    parse $call->{'args'}:
        no args           → show current position in all schemes
        "resolve <addr>"  → resolve address, show result
        "encode <scheme>" → encode current position in scheme
        "goto <addr>"     → resolve address and move cursor there
        "label <name>"    → register current position with label
        "labels"          → list all labeled addresses
        "registry"        → show address registry stats

    for no args, display all encodings of current position:

        address [42,17,3] chk=A3F2B7C
          decimal  : 42,17,3
          octal-7  : o7:52.21.03
          base32   : b32:KQTE
          channel  : f0@42,17,3

    for "goto": resolve, then call <[graphics-matrix.cursor.set]>
    with resolved coordinates. register new position.

    return { mode => 'size', data => $out }


## modifications to existing files

### modules/graphics-matrix.init_code

add address initialization after channel init, before `0;`:

    ## initialize address registry ##
    <[graphics-matrix.address.init]>;

### modules/graphics-matrix.cursor.set

after setting position (before the log line), register new position:

    ## register position in address registry ##
    <[graphics-matrix.address.register]>->( {
        qw| position | => {
            qw| selX | => $cursor->{'selX'},
            qw| selY | => $cursor->{'selY'},
            qw| selZ | => $cursor->{'selZ'},
        },
    } );

### modules/graphics-matrix.cursor.move

same registration after computing new position.

### cfg/zenki/graphics-matrix/start

add `address` to the access.cmd.usr.cube line.


## notes on flexibility

the resolve module is the single entry point. new addressing schemes
can be added later by extending the detection logic — no other module
needs to change. the registry grows naturally as positions are visited.

the division-13-table directional routing is intentionally limited to
2D (XY plane) in this implementation. Z-axis routing and the full
7-bit protocol decode can be added as additional schemes later without
changing the resolver interface.

the octal-7 and base32 schemes are numerical packing formats — compact
representations for contexts where character count matters (protocol
framing, checksum fields, display labels). which packing is most
natural for a given layer will emerge from usage.


## verify

    ptd -c on all 5 new module files
    check zero footer lines — no `#,,...` stubs
    verify <[module.name]> syntax — ]> before -> when args, no ->() when no args
    verify $ARG not $_ throughout
    verify lowercase comments
    verify address.resolve correctly detects all 6 scheme formats
    verify goto command moves cursor and registers new position
    verify cursor.set and cursor.move register in address registry

#,,,,,..,,...,...,,..,...,..,,.,.,,,.,.,.,,,,,..,,...,...,..,,,..,,,.,.,,,..,,
#NBDKGULMVGZUQTMGSL5XKM5WNYGAGWRPZOA722TISY7MSLS5ZEDJSIKE7ZLCGSPNRDKE5KVARKRIW
#\\\|CPI4LICOZCMIO7NMSLP6F5BR6L6X4PADNMIDPGQFKTGDHQTSUTH \ / AMOS7 \ YOURUM ::
#\[7]QWP6QVYJDLUBLNXAQITXEJNHKWORFXKKUXGA2IRETNUAIEKIW2BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
