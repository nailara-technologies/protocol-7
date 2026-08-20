## [:< ##

# name  = amos-term.handler.command
# descr = Command handler for amos-term protocol

my ( $session_id, $command_line ) = @ARG;

my $window = <amos-term.windows.by_id>->{$session_id};
if ( not defined $window ) {
    <[base.logs]>->( 0, ":: command for unknown window %d", $session_id );
    return undef;
}

## === parse command === ##
my ( $cmd, @args ) = split m{\s+}, $command_line;
$cmd = lc( $cmd // '' );

<[base.logs]>->( 2, "[amos-term:%d] cmd: %s", $session_id, $cmd )
    if <system.debug>;

## === command dispatch === ##
if ( $cmd eq qw| open | ) {
    my $result = <[amos-term.window-open]>->($session_id);
    return $result ? "+ window opened\n" : "- open failed\n";
} elsif ( $cmd eq qw| close | ) {
    my $result = <[amos-term.window-close]>->($session_id);
    return $result ? "+ window closed\n" : "- close failed\n";
} elsif ( $cmd eq qw| destroy | ) {
    my $result = <[amos-term.window-destroy]>->($session_id);
    return $result ? "+ window destroyed\n" : "- destroy failed\n";
} elsif ( $cmd eq qw| move | ) {
    my ( $x, $y ) = @args;
    return "- usage: move <x> <y>\n" unless defined $x and defined $y;
    <[amos-term.window-move]>->( $session_id, $x, $y );
    return "+ moved to $x,$y\n";
} elsif ( $cmd eq qw| resize | ) {
    my ( $w, $h ) = @args;
    return "- usage: resize <width> <height>\n"
        unless defined $w and defined $h;
    <[amos-term.window-resize]>->( $session_id, $w, $h );
    return "+ resized to ${w}x$h\n";
} elsif ( $cmd eq qw| fullscreen | ) {
    my $on = ( $args[0] // 'on' ) =~ m{^(on|1|true)$}i ? TRUE : FALSE;
    <[amos-term.window-fullscreen]>->( $session_id, $on );
    return $on ? "+ fullscreen enabled\n" : "+ fullscreen disabled\n";
} elsif ( $cmd eq qw| buffer | ) {
    ## buffer commands: create, write, read, clear
    my $subcmd = shift @args;
    if ( $subcmd eq qw| create | ) {
        my $result = <[amos-term.buffer-create]>->($session_id);
        return $result ? "+ buffer created\n" : "- buffer creation failed\n";
    } elsif ( $subcmd eq qw| write | ) {
        my ( $x, $y, $z, $data ) = @args;
        <[amos-term.buffer-write]>->( $session_id, $x, $y, $z, $data );
        return "+ written\n";
    } elsif ( $subcmd eq qw| clear | ) {
        <[amos-term.buffer-clear]>->($session_id);
        return "+ buffer cleared\n";
    }
    return "- usage: buffer <create|write|read|clear>\n";
} elsif ( $cmd eq qw| cursor | ) {
    my $subcmd = shift @args;
    if ( $subcmd eq qw| move | ) {
        my ( $dx, $dy, $dz ) = @args;
        my $new_pos
            = <[amos-term.cursor-move]>->( $session_id, $dx, $dy, $dz );
        return sprintf( "+ cursor at %d,%d,%d\n", @$new_pos{qw| x y z |} );
    } elsif ( $subcmd eq qw| set | ) {
        my ( $x, $y, $z ) = @args;
        <[amos-term.cursor-set_pos]>->( $session_id, $x, $y, $z );
        return "+ cursor set to $x,$y,$z\n";
    }
    return "- usage: cursor <move|set>\n";
} elsif ( $cmd eq qw| plugin | ) {
    my $subcmd = shift @args;
    if ( $subcmd eq qw| load | ) {
        my $plugin = shift @args;
        my $result = <[amos-term.plugin-load]>->( $session_id, $plugin );
        return $result ? "+ plugin '$plugin' loaded\n" : "- load failed\n";
    } elsif ( $subcmd eq qw| unload | ) {
        my $plugin = shift @args;
        <[amos-term.plugin-unload]>->( $session_id, $plugin );
        return "+ plugin '$plugin' unloaded\n";
    }
    return "- usage: plugin <load|unload|list>\n";
} elsif ( $cmd eq qw| attach | ) {
    ## attach client to buffer
    my ( $target, $client_type ) = @args;
    $target      //= 'current';
    $client_type //= 'generic';
    return <[amos-term.cmd.attach_buffer]>->( $target, $client_type );

} elsif ( $cmd eq qw| attachments | ) {
    ## list attached clients
    my $target = shift @args // 'current';
    return <[amos-term.cmd.list_attachments]>->($target);

} elsif ( $cmd eq qw| detach | ) {
    ## detach client from buffer
    my $attach_id = shift @args;
    return "- usage: detach <attach_id>\n" unless defined $attach_id;
    my $result = <[amos-term.buffer-detach]>->($attach_id);
    return $result ? "+ detached $attach_id\n" : "- detach failed\n";

} elsif ( $cmd eq qw| mount-9p | ) {
    ## mount buffer via 9P protocol
    my ( $target, $path ) = @args;
    $target //= 'current';
    return <[amos-term.cmd.mount-9p]>->( { 'args' => "$target $path" } );

} elsif ( $cmd eq qw| mount | ) {
    ## DEPRECATED: use mount-9p instead
    return "- 'mount' deprecated, use 'mount-9p' "
        . "instead (FUSE replaced with 9P)\n";

} elsif ( $cmd eq qw| umount | ) {
    ## DEPRECATED: 9P unmount is handled by the OS
    return "- 'umount' deprecated, use 'sudo umount <mountpoint>'\n";

} elsif ( $cmd eq qw| info | ) {
    my @attachments
        = $window->{'attachments'} ? $window->{'attachments'}->@* : ();
    return sprintf(
        ": amos-id: %s\n: name: %s\n: state: "
            . "%d\n: visible: %s\n: attachments: %d\n",
        $window->{'amos_id'},
        $window->{'client_name'},
        $window->{'state'},
        $window->{'display'}->{'visible'} ? 'yes' : 'no',
        scalar(@attachments)
    );
}

return "- unknown command: $cmd\n";

#,,..,..,,..,,.,,,,,.,..,,,.,,.,.,.,,,,,.,,,.,.,.,...,...,...,..,,,,.,,,.,,.,,
#APILH2LXCF3ITZX7SUUCBD7EF7FECXOBLH7ORY5Z2GVF7II43JGJTZ6DOSPM5I65CCOVNKE3ZGYWK
#\\\|GR56YDPEFTHQD7ZLI5CAJBVY4XRFHKN4WPFISPGL4KU2I5QLYBP \ / AMOS7 \ YOURUM ::
#\[7]BK5SD6ORLNQPPQXNDK64DKOFASH3TTMXIDYJYMDLJY7ZDSX2XQDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
