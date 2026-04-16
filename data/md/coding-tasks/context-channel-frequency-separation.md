## [:< ##

# task: context channel frequency separation — palette translation layer

add a context channel system to the graphics-matrix cursor. channels
represent different viewing angles of the same grid — 5 selectable
frequencies corresponding to the base grid plus 4 rotations (45° in
XY, XZ, YZ, and body diagonal planes). each channel sees the same
glow intensities rendered through a different palette.

this task depends on: cursor-glow-reference-intensity.md
— glow state must exist before channels can translate it.


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

    modules/graphics-matrix.glow.init              — glow state initialization
    modules/graphics-matrix.glow.compute           — glow intensity computation
    modules/graphics-matrix.cursor.init            — cursor state setup pattern
    modules/graphics-matrix.cmd.glow               — glow command (extend or reference)
    modules/graphics-matrix.cmd.cursor             — cursor command pattern
    data/md/design/VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md
        — section "Spatial Tuning — Frequency Selection Through Geometric Angle"
        — section "division-13-table as spatial frequency generator"
    bin/dev/division-13-table
        — source algorithm: 5 protocol types from 7-bit decoded field
          mirror the 5 selectable channel frequencies
    modules/ticker.cfg.font.calc_outline_col
        — existing HSV color code using Convert::Color::HSV
          use same pattern: ->new($hue,$sat,$val), ->as_rgb8->hex, ->rgb


## architecture

channels live in the `%data` tree under `graphics-matrix.channel`:

    $data{'graphics-matrix'}{'channel'} = {
        'active'   => 0,           ## currently selected channel index (0-4)
        'count'    => 5,           ## total selectable frequencies
        'channels' => {
            0 => {
                'name'     => 'base',
                'angle'    => 0,             ## degrees rotation
                'plane'    => 'reference',   ## rotation plane
                'hue_base' => 240,           ## blue — HSV base hue [0-359]
                'label'    => 'f0',
            },
            1 => {
                'name'     => 'xy-rotation',
                'angle'    => 45,
                'plane'    => 'XY',
                'hue_base' => 270,           ## violet
                'label'    => 'f1',
            },
            2 => {
                'name'     => 'xz-rotation',
                'angle'    => 45,
                'plane'    => 'XZ',
                'hue_base' => 200,           ## cyan
                'label'    => 'f2',
            },
            3 => {
                'name'     => 'yz-rotation',
                'angle'    => 45,
                'plane'    => 'YZ',
                'hue_base' => 160,           ## teal-green
                'label'    => 'f3',
            },
            4 => {
                'name'     => 'diagonal',
                'angle'    => 45,
                'plane'    => 'body-diagonal',
                'hue_base' => 300,           ## magenta — alpha/mask
                'alpha'    => 1,             ## transparency channel
                'label'    => 'f4',
            },
        },
    };


## palette translation concept

channels f0-f3 map glow intensity to an opaque color spectrum:

    intensity [0.0 - 1.0]  →  HSV(hue_base, saturation, value)

    saturation = 0.3 + intensity * 0.7    ## dim shells still colored
    value      = 0.1 + intensity * 0.9    ## never fully black

the distribution within each palette is identical — only hue_base shifts.
switching channels rotates the spectral filter, not the data.

channel f4 (diagonal/hyperspace) is different — magenta is a mask/alpha
color in the protocol-7 spectrum. it does not render opaque pigment.
instead it produces transparency: a bridge to neighbouring spectra.

    intensity [0.0 - 1.0]  →  alpha value

    alpha = 0.1 + intensity * 0.9    ## same curve as value

the collector zenka uses f4. it sees through — not its own color.


## files to create

### modules/graphics-matrix.channel.init

    # name  = graphics-matrix.channel.init
    # descr = initialize context channel state

    set up $data{'graphics-matrix'}{'channel'} with the 5-channel structure
    shown in architecture section above.

    read optional config override for active channel:
        <graphics-matrix.channel.default> // 0

    log: "channels initialized [%d channels, active=%s]"


### modules/graphics-matrix.channel.select

    # name  = graphics-matrix.channel.select
    # descr = select active context channel by index or label

    my $selector = shift // 0;

    accept either numeric index (0-4) or label string ('f0'-'f4').
    if label: look up index from channels hash.
    validate: must be valid channel index.

    set $data{'graphics-matrix'}{'channel'}{'active'} = $index.

    log at level 2: "channel.select → %s [%s]"

    return the full channel definition hashref for the selected channel.


### modules/graphics-matrix.channel.current

    # name  = graphics-matrix.channel.current
    # descr = return currently selected channel definition

    return a copy of the active channel's definition hashref
    including the channel index.


### modules/graphics-matrix.channel.translate

    # name  = graphics-matrix.channel.translate
    # descr = translate glow intensity to channel-specific color

    my $params = shift // {};

    accept hashref:
        intensity => 0.0-1.0 (required)
        channel   => index (optional, defaults to active channel)

    look up channel definition.

    if channel has 'alpha' key set (channel f4 / diagonal):
        ## magenta is a mask color — transparency, not opaque pigment ##
        ## f4 bridges to neighbouring spectra rather than rendering its own ##
        alpha      = 0.1 + intensity * 0.9   ## same curve as value ##
        return hashref:
            { r => 0, g => 0, b => 0, a => 0-255,
              hex => '#000000',
              alpha => F, intensity => F,
              mode => 'alpha' }

    otherwise (channels f0-f3, opaque):
        compute HSV:
            hue        = hue_base (from channel)
            saturation = 0.3 + intensity * 0.7
            value      = 0.1 + intensity * 0.9

        convert HSV to RGB using standard algorithm.

        return hashref:
            { r => 0-255, g => 0-255, b => 0-255,
              hex => '#RRGGBB',
              hue => N, saturation => F, value => F,
              mode => 'color' }


### modules/graphics-matrix.channel.palette

    # name  = graphics-matrix.channel.palette
    # descr = generate full palette for current channel from glow shells

    no arguments — reads glow state and active channel.

    for each hop in $data{'graphics-matrix'}{'glow'}{'shells'}:
        call <[graphics-matrix.channel.translate]> with shell intensity
        store result in palette array

    return arrayref of { hop => N, intensity => F, color => { ... } }
    ## color hashref includes 'mode' key: 'color' or 'alpha' ##


### modules/graphics-matrix.cmd.channel

    # name  = graphics-matrix.cmd.channel
    # descr = select and display context channel state

    parse $call->{'args'}:
        no args          → show active channel + all channel list
        "select N"       → select channel by index
        "select fN"      → select by label
        "palette"        → show glow palette for active channel
        "list"           → list all channels with hue

    for "palette": call <[graphics-matrix.channel.palette]>
    display depends on channel mode:

      for opaque channels (f0-f3):
        channel f0 [base] hue=240 (blue)
          hop 0 : #3333FF  intensity=1.00
          hop 1 : #2121A3  intensity=0.63
          hop 2 : #111157  intensity=0.27
          hop 3 : #0A0A30  intensity=0.13

      for alpha channel (f4):
        channel f4 [diagonal] alpha (bridge)
          hop 0 : alpha=0.99  intensity=1.00
          hop 1 : alpha=0.67  intensity=0.63
          hop 2 : alpha=0.34  intensity=0.27
          hop 3 : alpha=0.22  intensity=0.13

    for "list":
        f0  base          hue=240  (blue)     ← active
        f1  xy-rotation   hue=270  (violet)
        f2  xz-rotation   hue=200  (cyan)
        f3  yz-rotation   hue=160  (teal)
        f4  diagonal      alpha    (bridge)

    return { mode => 'size', data => $out }


## modifications to existing files

### configuration/zenki/graphics-matrix/start

add `channel` to the access.cmd.usr.cube line.

### modules/graphics-matrix.init_code

add Convert::Color autoload (after Graphics::Magick line):

    <[base.perlmod.autoload]>->( qw| Convert::Color | );

add channel initialization after glow init, before `0;`:

    ## initialize channel state ##
    <[graphics-matrix.channel.init]>;


## HSV to RGB conversion

use Convert::Color::HSV — already available in the system, used by
ticker.cfg.font.calc_outline_col. do NOT reimplement HSV→RGB manually.

    ## load Convert::Color::HSV ##
    <[base.perlmod.autoload]>->( qw| Convert::Color::HSV | );

    ## convert in channel.translate ##
    my $hsv = Convert::Color::HSV->new( $hue, $sat, $val );
    my @rgb = $hsv->rgb;                    ## float 0.0-1.0 ##
    my $r   = int( $rgb[0] * 255 + 0.5 );
    my $g   = int( $rgb[1] * 255 + 0.5 );
    my $b   = int( $rgb[2] * 255 + 0.5 );
    my $hex = '#' . $hsv->as_rgb8->hex;     ## uppercase hex string ##


## verify

    ptd -c on all 6 new module files
    check zero footer lines — no `#,,...` stubs
    verify <[module.name]> syntax — ]> before -> when args, no ->() when no args
    verify $ARG not $_ throughout
    verify lowercase comments
    verify Convert::Color::HSV used — no manual HSV→RGB reimplementation
    verify channel f4 returns mode => 'alpha', not mode => 'color'
    verify cmd.channel displays alpha for f4, hex colors for f0-f3

#,,,.,,,,,,,.,,,,,.,.,,.,,.,.,,.,,,..,.,,,.,,,..,,...,..,,..,,,.,,..,,.,.,,,,,
#WDWXVL4UUNEA47TONRPM2DNLG5MSN4NXUPURLL2SSA32LRHCGUNJLQTNTR7BV5II7NMEEO3G2LIJG
#\\\|DCY2UBPASTZW2LLE5HS6BKOUCAI2LYEOF2QHWNKH5PTXX2P3GV2 \ / AMOS7 \ YOURUM ::
#\[7]BXUFJNRMWWQEM5QDQ545HSP2LUEHGFOGTQNIW34JD2Y6TXOWNYAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
