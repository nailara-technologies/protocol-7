## [:< ##

# task: cursor glow — reference count to luminosity mapping

add a glow intensity layer to the graphics-matrix cursor system. glow
represents live economic activity: reference transaction counts at each
distance shell translate to luminosity values. closer = brighter.

this task depends on: graphics-matrix-namespace-bridge.md
— the cursor state and commands must exist before glow can be wired.


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

    src/graphics-3d.render.cursor             — cursor voxel rendering, translucency curves
    src/graphics-3d.calc.cursor-translucency  — translucency calculation pattern
    src/graphics.matrix.visual.sphere          — sphere classification (0-6), 13³-based sizes
    src/graphics.matrix.visual.cubic-layers    — hierarchical sphere layer builder
    data/md/design/VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md — glow economics section (~line 3700+)
    data/md/design/GRID-HARDNODE-CURSOR-MODEL.md   — vision propagation in waves (hop distance)


## architecture

glow is computed per distance shell from the cursor position:

    hop 0  →  cursor center (node-group) — maximum intensity
    hop 1  →  63 overlapping neighbors   — intensity = base / 1
    hop 2  →  neighbors of neighbors     — intensity = base / 2
    hop N  →  N-hop shell                — intensity = base / N

intensity at each shell = reference_count(shell) / hop_distance

reference counts come from the data tree. for now, use simulated counts
until the checksum cluster index is wired. the module should accept
both real and simulated data through the same interface.

glow state lives at:

    $data{'graphics-matrix'}{'glow'} = {
        'base_intensity' => 1.0,    ## maximum luminosity [ 0.0 - 1.0 ]
        'falloff'        => 'inverse',  ## 'inverse' | 'inverse_square' | 'linear'
        'shells'         => {},     ## hop_distance => { count => N, intensity => F }
        'active'         => 0,     ## boolean — glow computation enabled
    };


## files to create

### src/graphics-matrix.glow.init

    # name  = graphics-matrix.glow.init
    # descr = initialize glow intensity state

    set up $data{'graphics-matrix'}{'glow'} with defaults above.
    read optional config:
        <graphics-matrix.glow.base_intensity> // 1.0
        <graphics-matrix.glow.falloff> // 'inverse'

    log: "glow initialized [falloff=%s base=%.2f]"


### src/graphics-matrix.glow.compute

    # name  = graphics-matrix.glow.compute
    # descr = compute glow intensity per distance shell from reference counts

    my $params = shift // {};

    accept hashref:
        counts => { 0 => N, 1 => N, 2 => N, ... }  ## hop => reference_count
        ## if no counts provided, use simulated data for testing

    for each hop distance in counts:
        compute intensity based on falloff mode:
            'inverse'        → count / (hop + 1)
            'inverse_square' → count / (hop + 1)²
            'linear'         → count * (1 - hop / max_hop)

        normalize to 0.0 - 1.0 range (clamp, multiply by base_intensity)
        store in $data{'graphics-matrix'}{'glow'}{'shells'}{$hop}

    return the full glow state hashref (copy).

    ## simulated data for testing ##
    if no counts provided:
        generate test pattern: hop 0 = 100, hop 1 = 63, hop 2 = 27, hop 3 = 13
        these numbers are not random — they echo the topology constants


### src/graphics-matrix.glow.query

    # name  = graphics-matrix.glow.query
    # descr = return glow intensity at a specific hop distance

    my $hop = shift // 0;
    $hop = int($hop);

    return the intensity value for that shell:
        $data{'graphics-matrix'}{'glow'}{'shells'}{$hop}{'intensity'} // 0.0


### src/graphics-matrix.cmd.glow

    # name  = graphics-matrix.cmd.glow
    # descr = query or configure cursor glow intensity

    parse $call->{'args'}:
        no args             → show current glow state (all shells)
        "compute"           → trigger glow computation with simulated data
        "compute N N N ..."  → compute with provided counts (hop0 hop1 hop2 ...)
        "falloff inverse"   → change falloff mode
        "base 0.8"          → change base intensity

    for "compute" with args: parse space-separated counts into hop => count hash
    for "compute" without:   call with no counts (triggers simulated data)

    display format:
        glow [falloff=inverse base=1.00]
          hop 0 : count=100  intensity=1.00  ████████████████████
          hop 1 : count=63   intensity=0.63  ████████████▌
          hop 2 : count=27   intensity=0.27  █████▍
          hop 3 : count=13   intensity=0.13  ██▌

    the bar is a simple repeat of █ scaled to 20 chars max.
    use: my $bar = '█' x int($intensity * 20 + 0.5)

    return { mode => 'size', data => $out }


## modifications to existing files

### cfg/zenki/graphics-matrix/zenka.v7

add `glow` to the access.cmd.usr.cube line.

### src/graphics-matrix.init_code

add glow initialization after cursor init, before `0;`:

    ## initialize glow state ##
    <[graphics-matrix.glow.init]>;


## verify

    ptd -c on all 4 new module files
    check zero footer lines — no `#,,...` stubs
    verify <[module.name]> syntax — ]> before -> when args, no ->() when no args
    verify $ARG not $_ throughout
    verify lowercase comments
    verify bar rendering uses utf-8 block character

#,,,,,.,.,.,,,.,.,,.,,...,.,.,.,.,...,..,,,,.,..,,...,...,,,,,..,,..,,,,.,.,.,
#22N2NQSA6TCPHCTXIGKI5ZTEB4JJNIXHY7WR5VXGNWHHVFDDH57LWHCB7LAKU45PMNW2ABWOSN7AW
#\\\|7XVYCDEO2HZWOX7AUCTAFXUJG4LRLH6GVYMPZPEXVRAL2APLREI \ / AMOS7 \ YOURUM ::
#\[7]35SLWGCYX6KRTACGPTQHFRCZZHK3CN6FQWPUVTWDQM2Z3CDFSUAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
