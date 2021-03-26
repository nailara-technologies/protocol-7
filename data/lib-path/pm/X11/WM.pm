
#   // <-- original source: [cpan] X11::Tops [rev.3.25] written by Brian Keck
#  //
# // --> fixed line 101 + 103 [ // '' ] + minor cleanup + renamed to X11::WM

package X11::WM;

use X11::Protocol;
use Carp;
use strict;
use warnings;

our $VERSION = 0.1;

my @getpropconst = ( 'AnyPropertyType', 0, -1, 0 );

sub new {
    my $X = shift;
    $X = X11::Protocol->new() unless ref $X;
    my $wm;
    $wm->{X}    = $X;
    $wm->{root} = $X->root;                         # assumes only 1 screen
    $wm->{$_}   = $X->InternAtom( $_, 0 ) for qw(
        _NET_CLIENT_LIST
        _XCHAR_CHAR
        _XCHAR_COMMAND
    );
    $wm->{$_} = $X->atom($_) for qw(
        _WIN_CLIENT_LIST
        _NET_ACTIVE_WINDOW
        _NET_CLIENT_LIST_STACKING
        WM_CLASS
        WM_NAME
        WM_ICON_NAME
        STRING
        WM_NORMAL_HINTS
        WM_SIZE_HINTS
    );
    $wm->{$_} || croak("failed to create atom $_") for qw(
        _XCHAR_CHAR
        _XCHAR_COMMAND
    );
    bless $wm;
}

sub fetch_ids {
    my $wm               = shift;
    my $X                = $wm->{X};
    my $root             = $wm->{root};
    my $_NET_CLIENT_LIST = $wm->{_NET_CLIENT_LIST};
    my ( $value, $type, $format, $bytes_after )
        = $X->GetProperty( $root, $_NET_CLIENT_LIST, @getpropconst );
    my @ids = unpack( 'L*', $value );
    \@ids;
}

sub update_ids {
    my $wm  = shift;
    my $ids = $wm->fetch_ids;
    $wm->{byid}{$_} = bless { wm => $wm, id => $_ }, 'X11::WM::class' for @$ids;
    $wm;
}

sub update_from_props {
    my $wm = shift;
    $wm->update_ids;
    for my $wm_c ( values %{ $wm->{byid} } ) {
        $wm_c->class;
        $wm_c->char;
    }
    $wm;
}

sub update {
    my $wm      = shift;
    my @deleted = ();
    my $newids  = $wm->fetch_ids;
    if ( $wm->{byid} ) {
        my %seen;
        for my $id (@$newids) {
            $seen{$id}       = 1;
            $wm->{byid}{$id} = bless { wm => $wm, id => $id }, 'X11::WM::class'
                unless $wm->{byid}{$id};
        }
        for my $id ( keys %{ $wm->{byid} } ) {
            push( @deleted, $wm->{byid}{$id} ) unless $seen{$id};
        }
        for my $wm_c (@deleted) {
            delete $wm->{byid}{ $wm_c->{id} };
            delete $wm->{chars_in_use}{ $wm_c->{char} };
        }
    } else {
        for my $id (@$newids) {
            $wm->{byid}{$id} = bless { wm => $wm, id => $id }, 'X11::WM::class';
        }
    }
    for my $wm_c ( values %{ $wm->{byid} } ) {
        $wm_c->{instance} = $wm_c->instance // ''
            unless defined $wm_c->{instance};
        $wm_c->{char} = $wm->choosechar($wm_c) // ''
            unless defined $wm_c->{char};
    }
    $wm->sort;
    @deleted;
}

sub byid {
    my $wm = shift;
    $wm->{byid};
}

# assume instances set

sub choosechar {
    my ( $wm, $wm_c ) = @_;
    $wm->{char} = sub { [ 'a' .. 'z', '0' .. '9' ] }
        unless $wm->{char};
    my $instance = $wm_c->{instance};
    croak("\$wm_c->{instance} not set for \$wm_c->{id} = $wm_c->{id}")
        unless defined $instance;
    my $char = &{ $wm->{char} }($instance);
    if ( ref $char ) {
        for my $c (@$char) {
            $char = $c, last unless $wm->{chars_in_use}{$c};
        }
    }
    croak("no char matches instance '$instance'") unless defined $char;
    $wm->{chars_in_use}{$char} = 1;
    $wm_c->char($char);
    $char;
}

# assume chars chosen, as after update()

sub sort {
    my $wm    = shift;
    my $order = $wm->{order};    # hashref char->integer
    my $max   = -1;
    if ($order) {
        for ( values %$order ) {
            croak(    "values in order hash should be nonnegative integers,"
                    . " not '$_'" )
                unless /^\d+$/;
            $max = $_ if $max < $_;
        }
    }
    for my $n ( 0 .. 127 ) {
        my $char = chr($n);
        next if defined $order->{$char};    # XXX: <- patch / hotfix!
        $order->{$char} = $max + 1 + $n;
    }
    @{ $wm->{sorted} }
        = sort { $order->{ $a->{char} } <=> $order->{ $b->{char} } }
        values %{ $wm->byid };
}

sub sorted {
    my $wm = shift;
    $wm->sort unless $wm->{sorted};
    $wm->{sorted};
}

# assume chars chosen, as after update()

sub bychar {
    my $wm     = shift;
    my $bychar = {};
    for my $wm_c ( values %{ $wm->byid } ) {
        $bychar->{ $wm_c->{char} } = $wm_c;
    }
    $bychar;
}

sub X {
    my $wm = shift;
    $wm->{X};
}

sub match {
    my ( $wm, $prop, $regex ) = @_;
    for my $wm_c ( values %{ $wm->{byid} } ) {
        my $value = $wm_c->{$prop};
        $value = eval "\$wm_c->$prop" unless defined $value;
        return $wm_c if $value =~ $regex;
    }
}

for my $sub (qw(class instance title icon char)) {
    no strict 'refs';
    *$sub = sub {
        my ( $wm, $regex ) = @_;
        $wm->match( $sub, $regex );
    }
}

# argument normally $wm, but not used except to find this

sub active {
    my $wm                 = shift;
    my $X                  = $wm->{X};
    my $root               = $wm->{root};
    my $_NET_ACTIVE_WINDOW = $wm->{_NET_ACTIVE_WINDOW};
    my ( $value, $type, $format, $bytes_after )
        = $X->GetProperty( $root, $_NET_ACTIVE_WINDOW, @getpropconst );
    unpack( 'L*', $value );
}

# see raise & lower

# argument normally $wm, but not used except to find this

sub stacking {
    my $wm                        = shift;
    my $X                         = $wm->{X};
    my $root                      = $wm->{root};
    my $_NET_CLIENT_LIST_STACKING = $wm->{_NET_CLIENT_LIST_STACKING};
    my ( $value, $type, $format, $bytes_after )
        = $X->GetProperty( $root, $_NET_CLIENT_LIST_STACKING, @getpropconst );
    unpack( 'L*', $value );
}

sub NorthWest () { 1; }
sub North ()     { 2; }
sub NorthEast () { 3; }
sub West ()      { 4; }
sub Center ()    { 5; }
sub East ()      { 6; }
sub SouthWest () { 7; }
sub South ()     { 8; }
sub SouthEast () { 9; }

sub Gravity {
    my $arg = shift;
    $arg = shift if ref $arg;
    return undef unless $arg =~ /^\d$/;
    (   undef,
        qw(
            NorthWest
            North
            NorthEast
            West
            Center
            East
            SouthWest
            South
            SouthEast
        )
    )[$arg];
}

# also X11::WM::class method

sub monitor_property_change {
    my $wm = shift;
    my $X  = $wm->{X};
    my $id = $wm->{root};
    $X->ChangeWindowAttributes( $id,
        event_mask => $X->pack_event_mask('PropertyChange') );
}

package X11::WM::class;

sub id {
    my $wm_c = shift;
    $wm_c->{id};
}

sub instance {
    my $wm_c     = shift;
    my $wm       = $wm_c->{wm};
    my $X        = $wm->{X};
    my $WM_CLASS = $wm->{WM_CLASS};
    return $wm_c->{instance} if defined $wm_c->{instance};
    my ( $value, $type, $format, $bytes_after )
        = $X->GetProperty( $wm_c->{id}, $WM_CLASS, @getpropconst );
    my ( $instance, $class ) = split "\0", $value;
    $wm_c->{instance} = $instance;
    $wm_c->{class}    = $class;
    $instance;
}

sub class {
    my $wm_c = shift;
    my $wm   = $wm_c->{wm};
    return $wm_c->{class} if defined $wm_c->{class};
    my $X        = $wm->{X};
    my $WM_CLASS = $wm->{WM_CLASS};
    my ( $value, $type, $format, $bytes_after )
        = $X->GetProperty( $wm_c->{id}, $WM_CLASS, @getpropconst );
    croak("failed to fetch WM_CLASS for window $wm_c") unless $value;
    my ( $instance, $class ) = split "\0", $value;
    $wm_c->{instance} = $instance;
    $wm_c->{class}    = $class;
    $class;
}

sub title {
    my $wm_c    = shift;
    my $wm      = $wm_c->{wm};
    my $X       = $wm->{X};
    my $WM_NAME = $wm->{WM_NAME};
    my ( $value, $type, $format, $bytes_after )
        = $X->GetProperty( $wm_c->{id}, $WM_NAME, @getpropconst );
    $value;
}

sub icon {
    my $wm_c         = shift;
    my $wm           = $wm_c->{wm};
    my $X            = $wm->{X};
    my $WM_ICON_NAME = $wm->{WM_ICON_NAME};
    my ( $value, $type, $format, $bytes_after )
        = $X->GetProperty( $wm_c->{id}, $WM_ICON_NAME, @getpropconst );
    $value;
}

sub char {
    my ( $wm_c, $char ) = @_;
    my $wm          = $wm_c->{wm};
    my $X           = $wm->{X};
    my $_XCHAR_CHAR = $wm->{_XCHAR_CHAR};
    unless ( defined $char ) {
        return $wm_c->{char} if defined $wm_c->{char};
        my ( $value, $type, $format, $bytes_after )
            = $X->GetProperty( $wm_c->{id}, $_XCHAR_CHAR, @getpropconst );
        return $wm_c->{char} = $value;
    }
    $wm_c->{char} = $char;
    my $STRING = $wm->{STRING};
    $X->ChangeProperty(
        $wm_c->{id},     # window
        $_XCHAR_CHAR,    # property
        $STRING,         # type
        8,               # format
        'Replace',       # mode
        $char,           # data
    );
}

sub command {
    my ( $wm_c, $command ) = @_;
    my $wm             = $wm_c->{wm};
    my $X              = $wm->{X};
    my $_XCHAR_COMMAND = $wm->{_XCHAR_COMMAND};
    my $STRING         = $wm->{STRING};
    unless ( defined $command ) {
        my ( $value, $type, $format, $bytes_after )
            = $X->GetProperty( $wm_c->{id}, $_XCHAR_COMMAND, @getpropconst );
        return $value;
    }
    $X->ChangeProperty(
        $wm_c->{id},        # window
        $_XCHAR_COMMAND,    # property
        $STRING,            # type
        8,                  # format
        'Replace',          # mode
        $command,           # data
    );
}

# also X11::WM method
sub monitor_property_change {
    my $wm_c = shift;
    my $wm   = $wm_c->{wm};
    my $X    = $wm->{X};
    my $id   = $wm_c->{id};
    $X->ChangeWindowAttributes( $id,
        event_mask => $X->pack_event_mask('PropertyChange') );
}

sub monitor_property_and_visibility_change {
    my $wm_c = shift;
    my $wm   = $wm_c->{wm};
    my $X    = $wm->{X};
    my $id   = $wm_c->{id};
    $X->ChangeWindowAttributes( $id,
        event_mask =>
            $X->pack_event_mask( 'PropertyChange', 'VisibilityChange' ) );
}

# doesn't work with fvwm [+taskbar3] or twm [+taskbar4] ...
sub monitor_property_and_structure_change {
    my $wm_c = shift;
    my $wm   = $wm_c->{wm};
    my $X    = $wm->{X};
    my $id   = $wm_c->{id};
    $X->ChangeWindowAttributes( $id,
        event_mask =>
            $X->pack_event_mask( 'PropertyChange', 'SubstructureNotifyMask' ) );
}

sub attributes {
    my $wm_c = shift;
    my $wm   = $wm_c->{wm};
    my $X    = $wm->{X};
    my $id   = $wm_c->{id};
    $X->GetWindowAttributes($id);    # %attributes
}

# see stacking

sub raise {
    my $wm_c = shift;
    my $wm   = $wm_c->{wm};
    my $X    = $wm->{X};
    my $id   = $wm_c->{id};
    $X->MapWindow($id);
    $X->ConfigureWindow( $id, stack_mode => 'Above' );
}

# if call $wm_c->geometry then mouse & focus often don't move  ...
sub raise_and_focus {
    my $wm_c = shift;
    my $wm   = $wm_c->{wm};
    my $X    = $wm->{X};
    my $id   = $wm_c->{id};
    $X->MapWindow($id);
    $X->ConfigureWindow( $id, stack_mode => 'Above' );
    my %geometry = $X->GetGeometry($id);
    my $x        = int( $geometry{width} / 2 );
    my $y        = int( $geometry{height} / 2 );
    $X->WarpPointer( 'None', $id, 0, 0, 0, 0, $x, $y );
    $X->SetInputFocus( $id, 'RevertToPointerRoot', 'CurrentTime' );
}

sub lower {
    my $wm_c = shift;
    my $wm   = $wm_c->{wm};
    my $X    = $wm->{X};
    my $id   = $wm_c->{id};
    $X->ConfigureWindow( $id, stack_mode => 'Below' );
}

sub geometry {
    my $wm_c = shift;
    my $wm   = $wm_c->{wm};
    my $X    = $wm->{X};
    my $id   = $wm_c->{id};
    my %geom = $X->GetGeometry($id);
    my ( $root2, $parent, @kids ) = $X->QueryTree($id);
    my ( $same_screen, $child, $x, $y )
        = $X->TranslateCoordinates( $parent, $root2, $geom{x}, $geom{y} );
    return ( $geom{width}, $geom{height}, $x, $y );
}

sub frame_geometry {
    my $wm_c  = shift;
    my $wm    = $wm_c->{wm};
    my $X     = $wm->{X};
    my $frame = $wm_c->{id};
    while (1) {
        my ( $root2, $parent, @kids ) = $X->QueryTree($frame);
        last if $parent == $root2;
        $frame = $parent;
    }
    my %geom = $X->GetGeometry($frame);
    ( $geom{width}, $geom{height}, $geom{x}, $geom{y} );
}

our @wm_normal_hints = qw(
    flags
    user_x user_y user_w user_h
    min_width min_height
    max_width max_height
    width_inc height_inc
    min_aspect_num min_aspect_den
    max_aspect_num max_aspect_den
    base_width base_height
    gravity
);

my @wm_normal_hints_flags = (
    [qw(user_x user_y)],           # USPosition
    [qw(user_w user_h)],           # USSize
    [],                            # PPosition
    [],                            # PSize
    [qw(min_width min_height)],    # PMinSize
    [qw(max_width max_height)],    # PMaxSize
    [qw(width_inc height_inc)],    # PResizeInc
    [   qw(min_aspect_num min_aspect_den
            max_aspect_num max_aspect_den)
    ],                             # PAspect
    [qw(base_width base_height)],  # PBaseSize
    [qw(gravity)],                 # PWinGravity
);

sub wm_normal_hints {
    my $wm_c            = shift;
    my $wm              = $wm_c->{wm};
    my $X               = $wm->{X};
    my $WM_NORMAL_HINTS = $wm->{WM_NORMAL_HINTS};
    my $WM_SIZE_HINTS   = $wm->{WM_SIZE_HINTS};
    my %wm_normal_hints = @_;
    if (%wm_normal_hints) {
        my $value
            = pack( 'L*', map { $wm_normal_hints{$_} || 0 } @wm_normal_hints );
        $X->ChangeProperty(
            $wm_c->{id},         # window
            $WM_NORMAL_HINTS,    # property
            $WM_SIZE_HINTS,      # type
            32,                  # format
            'Replace',           # mode
            $value               # data
        );
        return;
    }
    my ( $value, $type, $format, $bytes_after )
        = $X->GetProperty( $wm_c->{id}, $WM_NORMAL_HINTS, @getpropconst );
    my %xxx;
    @xxx{@wm_normal_hints} = unpack( 'L*', $value );
    my $flags = $wm_normal_hints{flags} = $xxx{flags};
    for my $i (@wm_normal_hints_flags) {
        $wm_normal_hints{$_} = $flags & 1 ? $xxx{$_} : undef for @$i;
        $flags >>= 1;
    }
    %wm_normal_hints;
}

sub parse_geometry {
    my ( $wm_c, $geometry ) = @_;
    my $X = $wm_c->{wm}{X};
    my ( $w, $h, $x, $y ) = $geometry =~ /^(\d+)x(\d+)([+-]-?\d+)([+-]-?\d+)$/;
    my $g;    # gravity
    my $screenwidth  = $X->width_in_pixels;
    my $screenheight = $X->height_in_pixels;

    if ( $w == 0 || $h == 0 || $x eq '00' || $y eq '00' ) {
        my %wm_c;
        @wm_c{qw(w h x y)} = $wm_c->geometry;
        $w                 = $wm_c{w} if $w == 0;
        $h                 = $wm_c{h} if $h == 0;
        $x                 = $wm_c{x} if $x eq '00';
        $y                 = $wm_c{y} if $y eq '00';
    }

    if ( my ($a) = $x =~ /^-\+?(-?\d+)/ ) {
        if ( my ($b) = $y =~ /^-\+?(-?\d+)/ ) {
            $g = X11::WM::SouthEast;
            $x = $screenwidth - $w - $a;
            $y = $screenheight - $h - $b;
        } else {
            $g = X11::WM::NorthEast;
            $x = $screenwidth - $w - $a;
            $y =~ s/^\+//;
            $y = 0 + $y;
        }
    } else {
        if ( my ($b) = $y =~ /^-\+?(-?\d+)/ ) {
            $g = X11::WM::SouthWest;
            $x =~ s/^\+//;
            $x = 0 + $x;
            $y = $screenheight - $h - $b;
        } else {
            $g = X11::WM::NorthWest;
            $x =~ s/^\+//;
            $y =~ s/^\+//;
            $x = 0 + $x;
            $y = 0 + $y;
        }
    }
    ( $w, $h, $x, $y, $g );
}

sub requested_geometry {
    my $wm_c = shift;

    my %geometry;
    @geometry{qw(w h x y)} = $wm_c->geometry;

    my %frame_geometry;
    @frame_geometry{qw(w h x y)} = $wm_c->frame_geometry;

    my %wm_normal_hints = $wm_c->wm_normal_hints;
    my $gravity         = $wm_normal_hints{gravity};

    my $w = $geometry{w};
    my $h = $geometry{h};

    my $x
        = $gravity == X11::WM::NorthWest
        || $gravity == X11::WM::SouthWest ? $frame_geometry{x}
        : $gravity == X11::WM::NorthEast || $gravity == X11::WM::SouthEast
        ? $frame_geometry{x} - $frame_geometry{w} + $geometry{w}
        : croak("unknown gravity '$gravity'");

    my $y
        = $gravity == X11::WM::NorthWest
        || $gravity == X11::WM::NorthEast ? $frame_geometry{y}
        : $gravity == X11::WM::SouthEast || $gravity == X11::WM::SouthWest
        ? $frame_geometry{y} - $frame_geometry{h} + $geometry{h}
        : croak("unknown gravity '$gravity'");

    ( $w, $h, $x, $y, $gravity );
}

# +taskbar7

sub move {
    my ( $wm_c, $geometry ) = @_;    # (src, dst)
    my $X = $wm_c->{wm}{X};

    my %src_wm_normal_hints = $wm_c->wm_normal_hints;

    my %dst;
    @dst{qw(w h x y g)} = $wm_c->parse_geometry($geometry);

    my %dst_wm_normal_hints = %src_wm_normal_hints;
    $dst_wm_normal_hints{gravity} = $dst{g};

    $wm_c->wm_normal_hints(%dst_wm_normal_hints);

    $X->ConfigureWindow(
        $wm_c->{id},
        width  => $dst{w},
        height => $dst{h},
        x      => $dst{x},
        y      => $dst{y}
    );
}

# +taskbar[78]

sub expand {
    my ( $wm_c, $geometry ) = @_;    # (src, dst)
    my $X11 = $wm_c->{wm}{X};

    my %src;
    @src{qw(w h x y g)} = $wm_c->requested_geometry;
    $src{X}             = $src{x} + $src{w};
    $src{Y}             = $src{y} + $src{h};

    my %dst;
    @dst{qw(w h x y g)} = $wm_c->parse_geometry($geometry);
    $dst{X}             = $dst{x} + $dst{w};
    $dst{Y}             = $dst{y} + $dst{h};

    my $x = $src{x} < $dst{x} ? $src{x} : $dst{x};
    my $y = $src{y} < $dst{y} ? $src{y} : $dst{y};
    my $X = $src{X} > $dst{X} ? $src{X} : $dst{X};
    my $Y = $src{Y} > $dst{Y} ? $src{Y} : $dst{Y};
    my $w = $X - $x;
    my $h = $Y - $y;

    my %wm_normal_hints = $wm_c->wm_normal_hints;
    my %base;
    $base{w} = $wm_normal_hints{base_width};
    $base{h} = $wm_normal_hints{base_height};
    my %inc;
    $inc{w} = $wm_normal_hints{width_inc};
    $inc{h} = $wm_normal_hints{height_inc};
    if ( $inc{w} && $inc{h} ) {
        $w += ( $base{w} - $w ) % $inc{w};
        $h += ( $base{h} - $h ) % $inc{h};
    }

    $wm_normal_hints{gravity}    = X11::WM::NorthWest;
    $wm_normal_hints{user_w}     = $w;
    $wm_normal_hints{user_h}     = $h;
    $wm_normal_hints{user_x}     = $x;
    $wm_normal_hints{user_y}     = $y;
    $wm_normal_hints{max_width}  = $w;
    $wm_normal_hints{max_height} = $h;

    $wm_c->wm_normal_hints(%wm_normal_hints);

    $X11->ConfigureWindow(
        $wm_c->{id},
        width  => $w,
        height => $h,
        x      => $x,
        y      => $y
    );
}

1;
