
#   // <- original source: [cpan] X11::Tops [rev.3.25] written by Brian Keck
#  //
# // -> fixed line 101 + 103 [ // '' ] + minor cleanup

package X11::Tops;

use X11::Protocol;
use Carp;
use strict;
use warnings;

our $VERSION = 0.2;

my @getpropconst = ( 'AnyPropertyType', 0, -1, 0 );

sub new {
    my $X = shift;
    $X = X11::Protocol->new() unless ref $X;
    my $xtops;
    $xtops->{X}    = $X;
    $xtops->{root} = $X->root;    # assumes only 1 screen
    $xtops->{$_} = $X->InternAtom( $_, 0 ) for qw(
        _NET_CLIENT_LIST
        _XCHAR_CHAR
        _XCHAR_COMMAND
    );
    $xtops->{$_} = $X->atom($_) for qw(
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
    $xtops->{$_} || croak("failed to create atom $_") for qw(
        _XCHAR_CHAR
        _XCHAR_COMMAND
    );
    bless $xtops;
}

sub fetch_ids {
    my $xtops            = shift;
    my $X                = $xtops->{X};
    my $root             = $xtops->{root};
    my $_NET_CLIENT_LIST = $xtops->{_NET_CLIENT_LIST};
    my ( $value, $type, $format, $bytes_after )
        = $X->GetProperty( $root, $_NET_CLIENT_LIST, @getpropconst );
    my @ids = unpack( 'L*', $value );
    \@ids;
}

sub update_ids {
    my $xtops = shift;
    my $ids   = $xtops->fetch_ids;
    $xtops->{byid}{$_} = bless { xtops => $xtops, id => $_ }, 'X11::Top'
        for @$ids;
    $xtops;
}

sub update_from_props {
    my $xtops = shift;
    $xtops->update_ids;
    for my $xtop ( values %{ $xtops->{byid} } ) {
        $xtop->class;
        $xtop->char;
    }
    $xtops;
}

sub update {
    my $xtops   = shift;
    my @deleted = ();
    my $newids  = $xtops->fetch_ids;
    if ( $xtops->{byid} ) {
        my %seen;
        for my $id (@$newids) {
            $seen{$id} = 1;
            $xtops->{byid}{$id} = bless { xtops => $xtops, id => $id },
                'X11::Top'
                unless $xtops->{byid}{$id};
        }
        for my $id ( keys %{ $xtops->{byid} } ) {
            push( @deleted, $xtops->{byid}{$id} ) unless $seen{$id};
        }
        for my $xtop (@deleted) {
            delete $xtops->{byid}{ $xtop->{id} };
            delete $xtops->{chars_in_use}{ $xtop->{char} };
        }
    } else {
        for my $id (@$newids) {
            $xtops->{byid}{$id} = bless { xtops => $xtops, id => $id },
                'X11::Top';
        }
    }
    for my $xtop ( values %{ $xtops->{byid} } ) {
        $xtop->{instance} = $xtop->instance // ''
            unless defined $xtop->{instance};
        $xtop->{char} = $xtops->choosechar($xtop) // ''
            unless defined $xtop->{char};
    }
    $xtops->sort;
    @deleted;
}

sub byid {
    my $xtops = shift;
    $xtops->{byid};
}

# assume instances set

sub choosechar {
    my ( $xtops, $xtop ) = @_;
    $xtops->{char} = sub { [ 'a' .. 'z', '0' .. '9' ] }
        unless $xtops->{char};
    my $instance = $xtop->{instance};
    croak("\$xtop->{instance} not set for \$xtop->{id} = $xtop->{id}")
        unless defined $instance;
    my $char = &{ $xtops->{char} }($instance);
    if ( ref $char ) {
        for my $c (@$char) {
            $char = $c, last unless $xtops->{chars_in_use}{$c};
        }
    }
    croak("no char matches instance '$instance'") unless defined $char;
    $xtops->{chars_in_use}{$char} = 1;
    $xtop->char($char);
    $char;
}

# assume chars chosen, as after update()

sub sort {
    my $xtops = shift;
    my $order = $xtops->{order};    # hashref char->integer
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
    @{ $xtops->{sorted} }
        = sort { $order->{ $a->{char} } <=> $order->{ $b->{char} } }
        values %{ $xtops->byid };
}

sub sorted {
    my $xtops = shift;
    $xtops->sort unless $xtops->{sorted};
    $xtops->{sorted};
}

# assume chars chosen, as after update()

sub bychar {
    my $xtops  = shift;
    my $bychar = {};
    for my $xtop ( values %{ $xtops->byid } ) {
        $bychar->{ $xtop->{char} } = $xtop;
    }
    $bychar;
}

sub X {
    my $xtops = shift;
    $xtops->{X};
}

sub match {
    my ( $xtops, $prop, $regex ) = @_;
    for my $xtop ( values %{ $xtops->{byid} } ) {
        my $value = $xtop->{$prop};
        $value = eval "\$xtop->$prop" unless defined $value;
        return $xtop if $value =~ $regex;
    }
}

for my $sub (qw(class instance title icon char)) {
    no strict 'refs';
    *$sub = sub {
        my ( $xtops, $regex ) = @_;
        $xtops->match( $sub, $regex );
        }
}

# argument normally $xtops, but not used except to find this

sub active {
    my $xtops              = shift;
    my $X                  = $xtops->{X};
    my $root               = $xtops->{root};
    my $_NET_ACTIVE_WINDOW = $xtops->{_NET_ACTIVE_WINDOW};
    my ( $value, $type, $format, $bytes_after )
        = $X->GetProperty( $root, $_NET_ACTIVE_WINDOW, @getpropconst );
    unpack( 'L*', $value );
}

# see raise & lower

# argument normally $xtops, but not used except to find this

sub stacking {
    my $xtops                     = shift;
    my $X                         = $xtops->{X};
    my $root                      = $xtops->{root};
    my $_NET_CLIENT_LIST_STACKING = $xtops->{_NET_CLIENT_LIST_STACKING};
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

# also X11::Top method

sub monitor_property_change {
    my $xtops = shift;
    my $X     = $xtops->{X};
    my $id    = $xtops->{root};
    $X->ChangeWindowAttributes( $id,
        event_mask => $X->pack_event_mask('PropertyChange') );
}

package X11::Top;

sub id {
    my $xtop = shift;
    $xtop->{id};
}

sub instance {
    my $xtop     = shift;
    my $xtops    = $xtop->{xtops};
    my $X        = $xtops->{X};
    my $WM_CLASS = $xtops->{WM_CLASS};
    return $xtop->{instance} if defined $xtop->{instance};
    my ( $value, $type, $format, $bytes_after )
        = $X->GetProperty( $xtop->{id}, $WM_CLASS, @getpropconst );
    my ( $instance, $class ) = split "\0", $value;
    $xtop->{instance} = $instance;
    $xtop->{class}    = $class;
    $instance;
}

sub class {
    my $xtop  = shift;
    my $xtops = $xtop->{xtops};
    return $xtop->{class} if defined $xtop->{class};
    my $X        = $xtops->{X};
    my $WM_CLASS = $xtops->{WM_CLASS};
    my ( $value, $type, $format, $bytes_after )
        = $X->GetProperty( $xtop->{id}, $WM_CLASS, @getpropconst );
    croak("failed to fetch WM_CLASS for window $xtop") unless $value;
    my ( $instance, $class ) = split "\0", $value;
    $xtop->{instance} = $instance;
    $xtop->{class}    = $class;
    $class;
}

sub title {
    my $xtop    = shift;
    my $xtops   = $xtop->{xtops};
    my $X       = $xtops->{X};
    my $WM_NAME = $xtops->{WM_NAME};
    my ( $value, $type, $format, $bytes_after )
        = $X->GetProperty( $xtop->{id}, $WM_NAME, @getpropconst );
    $value;
}

sub icon {
    my $xtop         = shift;
    my $xtops        = $xtop->{xtops};
    my $X            = $xtops->{X};
    my $WM_ICON_NAME = $xtops->{WM_ICON_NAME};
    my ( $value, $type, $format, $bytes_after )
        = $X->GetProperty( $xtop->{id}, $WM_ICON_NAME, @getpropconst );
    $value;
}

sub char {
    my ( $xtop, $char ) = @_;
    my $xtops       = $xtop->{xtops};
    my $X           = $xtops->{X};
    my $_XCHAR_CHAR = $xtops->{_XCHAR_CHAR};
    unless ( defined $char ) {
        return $xtop->{char} if defined $xtop->{char};
        my ( $value, $type, $format, $bytes_after )
            = $X->GetProperty( $xtop->{id}, $_XCHAR_CHAR, @getpropconst );
        return $xtop->{char} = $value;
    }
    $xtop->{char} = $char;
    my $STRING = $xtops->{STRING};
    $X->ChangeProperty(
        $xtop->{id},     # window
        $_XCHAR_CHAR,    # property
        $STRING,         # type
        8,               # format
        'Replace',       # mode
        $char,           # data
    );
}

sub command {
    my ( $xtop, $command ) = @_;
    my $xtops          = $xtop->{xtops};
    my $X              = $xtops->{X};
    my $_XCHAR_COMMAND = $xtops->{_XCHAR_COMMAND};
    my $STRING         = $xtops->{STRING};
    unless ( defined $command ) {
        my ( $value, $type, $format, $bytes_after )
            = $X->GetProperty( $xtop->{id}, $_XCHAR_COMMAND, @getpropconst );
        return $value;
    }
    $X->ChangeProperty(
        $xtop->{id},        # window
        $_XCHAR_COMMAND,    # property
        $STRING,            # type
        8,                  # format
        'Replace',          # mode
        $command,           # data
    );
}

# also X11::Tops method
sub monitor_property_change {
    my $xtop  = shift;
    my $xtops = $xtop->{xtops};
    my $X     = $xtops->{X};
    my $id    = $xtop->{id};
    $X->ChangeWindowAttributes( $id,
        event_mask => $X->pack_event_mask('PropertyChange') );
}

sub monitor_property_and_visibility_change {
    my $xtop  = shift;
    my $xtops = $xtop->{xtops};
    my $X     = $xtops->{X};
    my $id    = $xtop->{id};
    $X->ChangeWindowAttributes( $id,
        event_mask =>
            $X->pack_event_mask( 'PropertyChange', 'VisibilityChange' ) );
}

# doesn't work with fvwm [+taskbar3] or twm [+taskbar4] ...
sub monitor_property_and_structure_change {
    my $xtop  = shift;
    my $xtops = $xtop->{xtops};
    my $X     = $xtops->{X};
    my $id    = $xtop->{id};
    $X->ChangeWindowAttributes( $id,
        event_mask =>
            $X->pack_event_mask( 'PropertyChange', 'SubstructureNotifyMask' ) );
}

sub attributes {
    my $xtop  = shift;
    my $xtops = $xtop->{xtops};
    my $X     = $xtops->{X};
    my $id    = $xtop->{id};
    $X->GetWindowAttributes($id);    # %attributes
}

# see stacking

sub raise {
    my $xtop  = shift;
    my $xtops = $xtop->{xtops};
    my $X     = $xtops->{X};
    my $id    = $xtop->{id};
    $X->MapWindow($id);
    $X->ConfigureWindow( $id, stack_mode => 'Above' );
}

# if call $xtop->geometry then mouse & focus often don't move  ...
sub raise_and_focus {
    my $xtop  = shift;
    my $xtops = $xtop->{xtops};
    my $X     = $xtops->{X};
    my $id    = $xtop->{id};
    $X->MapWindow($id);
    $X->ConfigureWindow( $id, stack_mode => 'Above' );
    my %geometry = $X->GetGeometry($id);
    my $x        = int( $geometry{width} / 2 );
    my $y        = int( $geometry{height} / 2 );
    $X->WarpPointer( 'None', $id, 0, 0, 0, 0, $x, $y );
    $X->SetInputFocus( $id, 'RevertToPointerRoot', 'CurrentTime' );
}

sub lower {
    my $xtop  = shift;
    my $xtops = $xtop->{xtops};
    my $X     = $xtops->{X};
    my $id    = $xtop->{id};
    $X->ConfigureWindow( $id, stack_mode => 'Below' );
}

sub geometry {
    my $xtop  = shift;
    my $xtops = $xtop->{xtops};
    my $X     = $xtops->{X};
    my $id    = $xtop->{id};
    my %geom  = $X->GetGeometry($id);
    my ( $root2, $parent, @kids ) = $X->QueryTree($id);
    my ( $same_screen, $child, $x, $y )
        = $X->TranslateCoordinates( $parent, $root2, $geom{x}, $geom{y} );
    return ( $geom{width}, $geom{height}, $x, $y );
}

sub frame_geometry {
    my $xtop  = shift;
    my $xtops = $xtop->{xtops};
    my $X     = $xtops->{X};
    my $frame = $xtop->{id};
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
    ],                               # PAspect
    [qw(base_width base_height)],    # PBaseSize
    [qw(gravity)],                   # PWinGravity
);

sub wm_normal_hints {
    my $xtop            = shift;
    my $xtops           = $xtop->{xtops};
    my $X               = $xtops->{X};
    my $WM_NORMAL_HINTS = $xtops->{WM_NORMAL_HINTS};
    my $WM_SIZE_HINTS   = $xtops->{WM_SIZE_HINTS};
    my %wm_normal_hints = @_;
    if (%wm_normal_hints) {
        my $value
            = pack( 'L*', map { $wm_normal_hints{$_} || 0 } @wm_normal_hints );
        $X->ChangeProperty(
            $xtop->{id},         # window
            $WM_NORMAL_HINTS,    # property
            $WM_SIZE_HINTS,      # type
            32,                  # format
            'Replace',           # mode
            $value               # data
        );
        return;
    }
    my ( $value, $type, $format, $bytes_after )
        = $X->GetProperty( $xtop->{id}, $WM_NORMAL_HINTS, @getpropconst );
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
    my ( $xtop, $geometry ) = @_;
    my $X = $xtop->{xtops}{X};
    my ( $w, $h, $x, $y ) = $geometry =~ /^(\d+)x(\d+)([+-]-?\d+)([+-]-?\d+)$/;
    my $g;    # gravity
    my $screenwidth  = $X->width_in_pixels;
    my $screenheight = $X->height_in_pixels;

    if ( $w == 0 || $h == 0 || $x eq '00' || $y eq '00' ) {
        my %xtop;
        @xtop{qw(w h x y)} = $xtop->geometry;
        $w = $xtop{w} if $w == 0;
        $h = $xtop{h} if $h == 0;
        $x = $xtop{x} if $x eq '00';
        $y = $xtop{y} if $y eq '00';
    }

    if ( my ($a) = $x =~ /^-\+?(-?\d+)/ ) {
        if ( my ($b) = $y =~ /^-\+?(-?\d+)/ ) {
            $g = X11::Tops::SouthEast;
            $x = $screenwidth - $w - $a;
            $y = $screenheight - $h - $b;
        } else {
            $g = X11::Tops::NorthEast;
            $x = $screenwidth - $w - $a;
            $y =~ s/^\+//;
            $y = 0 + $y;
        }
    } else {
        if ( my ($b) = $y =~ /^-\+?(-?\d+)/ ) {
            $g = X11::Tops::SouthWest;
            $x =~ s/^\+//;
            $x = 0 + $x;
            $y = $screenheight - $h - $b;
        } else {
            $g = X11::Tops::NorthWest;
            $x =~ s/^\+//;
            $y =~ s/^\+//;
            $x = 0 + $x;
            $y = 0 + $y;
        }
    }
    ( $w, $h, $x, $y, $g );
}

sub requested_geometry {
    my $xtop = shift;

    my %geometry;
    @geometry{qw(w h x y)} = $xtop->geometry;

    my %frame_geometry;
    @frame_geometry{qw(w h x y)} = $xtop->frame_geometry;

    my %wm_normal_hints = $xtop->wm_normal_hints;
    my $gravity         = $wm_normal_hints{gravity};

    my $w = $geometry{w};
    my $h = $geometry{h};

    my $x
        = $gravity == X11::Tops::NorthWest
        || $gravity == X11::Tops::SouthWest ? $frame_geometry{x}
        : $gravity == X11::Tops::NorthEast || $gravity == X11::Tops::SouthEast
        ? $frame_geometry{x} - $frame_geometry{w} + $geometry{w}
        : croak("unknown gravity '$gravity'");

    my $y
        = $gravity == X11::Tops::NorthWest
        || $gravity == X11::Tops::NorthEast ? $frame_geometry{y}
        : $gravity == X11::Tops::SouthEast || $gravity == X11::Tops::SouthWest
        ? $frame_geometry{y} - $frame_geometry{h} + $geometry{h}
        : croak("unknown gravity '$gravity'");

    ( $w, $h, $x, $y, $gravity );
}

# +taskbar7

sub move {
    my ( $xtop, $geometry ) = @_;    # (src, dst)
    my $X = $xtop->{xtops}{X};

    my %src_wm_normal_hints = $xtop->wm_normal_hints;

    my %dst;
    @dst{qw(w h x y g)} = $xtop->parse_geometry($geometry);

    my %dst_wm_normal_hints = %src_wm_normal_hints;
    $dst_wm_normal_hints{gravity} = $dst{g};

    $xtop->wm_normal_hints(%dst_wm_normal_hints);

    $X->ConfigureWindow(
        $xtop->{id},
        width  => $dst{w},
        height => $dst{h},
        x      => $dst{x},
        y      => $dst{y}
    );
}

# +taskbar[78]

sub expand {
    my ( $xtop, $geometry ) = @_;    # (src, dst)
    my $X11 = $xtop->{xtops}{X};

    my %src;
    @src{qw(w h x y g)} = $xtop->requested_geometry;
    $src{X}             = $src{x} + $src{w};
    $src{Y}             = $src{y} + $src{h};

    my %dst;
    @dst{qw(w h x y g)} = $xtop->parse_geometry($geometry);
    $dst{X}             = $dst{x} + $dst{w};
    $dst{Y}             = $dst{y} + $dst{h};

    my $x = $src{x} < $dst{x} ? $src{x} : $dst{x};
    my $y = $src{y} < $dst{y} ? $src{y} : $dst{y};
    my $X = $src{X} > $dst{X} ? $src{X} : $dst{X};
    my $Y = $src{Y} > $dst{Y} ? $src{Y} : $dst{Y};
    my $w = $X - $x;
    my $h = $Y - $y;

    my %wm_normal_hints = $xtop->wm_normal_hints;
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

    $wm_normal_hints{gravity}    = X11::Tops::NorthWest;
    $wm_normal_hints{user_w}     = $w;
    $wm_normal_hints{user_h}     = $h;
    $wm_normal_hints{user_x}     = $x;
    $wm_normal_hints{user_y}     = $y;
    $wm_normal_hints{max_width}  = $w;
    $wm_normal_hints{max_height} = $h;

    $xtop->wm_normal_hints(%wm_normal_hints);

    $X11->ConfigureWindow(
        $xtop->{id},
        width  => $w,
        height => $h,
        x      => $x,
        y      => $y
    );
}

1;
