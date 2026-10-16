package AMOS7::deps::service;

use strict;
use warnings;
use English;

use File::Spec;
use File::Path qw| make_path |;
use Cwd        ();

use Exporter;
use base qw| Exporter |;

our @EXPORT_OK = qw| target_paths install enable disable check |;

##[ service unit management ]#################################################
##
## the legacy install script host steps, testable against a temporary root ##
## [ env P7_DEPS_SERVICE_ROOT prefixes every absolute target path ]. never ##
## starts, stops or restarts the service -- daemon-reload after a changed  ##
## unit is as far as it goes. systemctl is always called list-form         ##
## [ never through a shell ]                                               ##

##[ target_paths ]############################################################

sub target_paths {
    my ( $p7_root, $prefix ) = @_;

    $prefix //= $ENV{'P7_DEPS_SERVICE_ROOT'} // '';

    return {
        'checkout'  => $p7_root,
        'repo_unit' => File::Spec->catfile(
            $p7_root,   'data',
            'lib-path', 'systemd',
            'system',   'Protocol-7.service'
        ),
        'unit_dir' =>
            File::Spec->catdir( $prefix, 'usr', 'lib', 'systemd', 'system' ),
        'unit_path' => File::Spec->catfile(
            $prefix,  'usr', 'lib', 'systemd',
            'system', 'Protocol-7.service'
        ),
        'install_link' =>
            File::Spec->catdir( $prefix, 'usr', 'local', 'protocol-7' ),
        'bin_dir' => File::Spec->catdir( $prefix, 'usr', 'local', 'bin' ),
        'protocol7_link' => File::Spec->catfile(
            $prefix, 'usr', 'local', 'bin', 'Protocol-7'
        ),
        'nshell_link' =>
            File::Spec->catfile( $prefix, 'usr', 'local', 'bin', 'nshell' ),
        'protocol7_bin' =>
            File::Spec->catfile( $p7_root, 'bin', 'Protocol-7' ),
        'nshell_bin' => File::Spec->catfile( $p7_root, 'bin', 'nshell' ),
    };
}

##[ install ]#################################################################
##
## returns a report : [ [ part, status, detail ], .. ] with status ok | set ##
## | changed | failed. the unit is 'changed' only when the content differs, ##
## then followed by a 'systemctl daemon-reload' entry. symlinks replace     ##
## only symlinks -- a regular file in place is left alone and reported      ##

sub install {
    my ($p7_root) = @_;

    my $P      = target_paths($p7_root);
    my @report = ();

    ## parents first [ an empty test root has none of these ] ##
    make_path( $P->{'bin_dir'} ) unless -d $P->{'bin_dir'};
    my $install_parent = ( File::Spec->splitpath( $P->{'install_link'} ) )[1];
    make_path($install_parent) unless -d $install_parent;

    ## unit file ##
    my $repo_content = _slurp( $P->{'repo_unit'} );
    if ( not defined $repo_content ) {
        push(
            @report,
            [   'unit', 'failed',
                sprintf( 'repo copy not found : %s', $P->{'repo_unit'} )
            ]
        );
    } else {
        my $installed = _slurp( $P->{'unit_path'} );
        if ( defined $installed and $installed eq $repo_content ) {
            push( @report, [ 'unit', 'ok', undef ] );
        } elsif ( _write_file( $P->{'unit_path'}, $repo_content ) ) {
            push( @report, [ 'unit', 'changed', undef ] );
            my $reload_ok = _systemctl_void(qw| daemon-reload |);
            push(
                @report,
                [   'systemctl daemon-reload',
                    $reload_ok ? 'ok' : 'failed',
                    undef
                ]
            );
        } else {
            push(
                @report,
                [   'unit', 'failed',
                    sprintf( 'cannot write %s', $P->{'unit_path'} )
                ]
            );
        }
    }

    ## checkout link and launcher symlinks -- a server cloned straight to ##
    ## /usr/local/protocol-7 has the checkout itself there : ok           ##
    push(
        @report,
        _is_the_checkout( $P->{'install_link'}, $P->{'checkout'} )
        ? [ 'install link', 'ok', 'the checkout itself' ]
        : _install_link(
            'install ' . 'link',
            $P->{'install_link'}, $P->{'checkout'}
        )
    );
    push(
        @report,
        _install_link(
            'Protocol-7 symlink', $P->{'protocol7_link'},
            $P->{'protocol7_bin'}
        )
    );
    push(
        @report,
        _install_link(
            'nshell symlink',
            $P->{'nshell_link'}, $P->{'nshell_bin'}
        )
    );

    return \@report;
}

sub _install_link {
    my ( $part, $link, $target ) = @_;

    if ( -l $link ) {
        my $current = readlink($link);
        return [ $part, 'ok', undef ]
            if defined $current and $current eq $target;
        return [
            $part, 'failed',
            sprintf( 'cannot remove old symlink : %s', $OS_ERROR )
            ]
            unless unlink($link);
    } elsif ( -e $link ) {
        return [ $part, 'failed', 'regular file in place -- left alone' ];
    }

    return symlink( $target, $link )
        ? [ $part, 'set', undef ]
        : [ $part, 'failed', sprintf( 'symlink failed : %s', $OS_ERROR ) ];
}

##[ enable \ disable ]########################################################

sub enable  { return _set_enabled(1) }
sub disable { return _set_enabled(0) }

sub _set_enabled {
    my ($enable) = @_;

    my @verb = $enable ? qw| enable Protocol-7 | : qw| disable Protocol-7 |;
    my $ok   = _systemctl_void(@verb);

    return [
        [ sprintf( 'systemctl %s', $verb[0] ), $ok ? 'ok' : 'failed', undef ]
    ];
}

##[ check ]###################################################################
##
## read-only, no root needed. returns ( report, all_ok ) -- the file parts  ##
## report ok | missing | differs, the unit state reports enabled | disabled ##
## and active | inactive. all_ok covers the file parts only                 ##
## [ the unit state is information for the admin, not a breakage ]          ##

sub check {
    my ($p7_root) = @_;

    my $P      = target_paths($p7_root);
    my @report = ();
    my $all_ok = 1;

    ## unit file ##
    my $repo_content = _slurp( $P->{'repo_unit'} );
    my $installed    = _slurp( $P->{'unit_path'} );
    if ( not defined $installed ) {
        push( @report, [ 'unit', 'missing', undef ] );
        $all_ok = 0;
    } elsif ( not defined $repo_content ) {
        push( @report, [ 'unit', 'differs', 'repo copy not found' ] );
        $all_ok = 0;
    } elsif ( $installed eq $repo_content ) {
        push( @report, [ 'unit', 'ok', undef ] );
    } else {
        push( @report, [ 'unit', 'differs', undef ] );
        $all_ok = 0;
    }

    ## checkout link and launcher symlinks ##
    if ( _is_the_checkout( $P->{'install_link'}, $P->{'checkout'} ) ) {
        push( @report, [ 'install link', 'ok', 'the checkout itself' ] );
    } else {
        $all_ok = 0
            unless _check_link( \@report, 'install link',
            $P->{'install_link'}, $P->{'checkout'} );
    }
    $all_ok = 0
        unless _check_link(
        \@report,               'Protocol-7 symlink',
        $P->{'protocol7_link'}, $P->{'protocol7_bin'}
        );
    $all_ok = 0
        unless _check_link(
        \@report,            'nshell symlink',
        $P->{'nshell_link'}, $P->{'nshell_bin'}
        );

    ## unit state [ informational ] ##
    my ( undef, $enabled_out )
        = _systemctl_capture(qw| is-enabled Protocol-7 |);
    push(
        @report,
        [   'systemctl is-enabled',
            ( defined $enabled_out and $enabled_out eq 'enabled' )
            ? 'enabled'
            : 'disabled',
            undef
        ]
    );
    my ( undef, $active_out )
        = _systemctl_capture(qw| is-active Protocol-7 |);
    my $is_active = ( defined $active_out and $active_out eq 'active' );
    push( @report,
        [ 'systemctl is-active', $is_active ? 'active' : 'inactive', undef ]
    );

    ## what the running service uses [ informational ] : a unit file      ##
    ## written after the last start applies only at the next start -- the ##
    ## running process keeps the unit it was started with                 ##
    my ( undef, $need_reload )
        = _systemctl_capture(
        qw| show Protocol-7 -p NeedDaemonReload --value |);
    push( @report, [ 'unit loaded', 'stale', 'daemon-reload pending' ] )
        if defined $need_reload and $need_reload eq 'yes';

    if ( $is_active and defined $installed ) {
        my ( undef, $started ) = _systemctl_capture(
            qw| show Protocol-7 -p ActiveEnterTimestamp --value
                --timestamp=unix |
        );
        my $unit_mtime = ( stat( $P->{'unit_path'} ) )[9];
        if ( defined $started and $started =~ m|^@(\d+)$| ) {
            my $started_at = $1;
            push(
                @report,
                $unit_mtime > $started_at
                ? [ 'running service',
                    'older',
                    'started before the unit changed '
                        . '-- it applies at the next start'
                    ]
                : [ 'running service', 'ok', 'uses the installed unit' ]
            );
        }
    }

    return ( \@report, $all_ok );
}

sub _check_link {
    my ( $report, $part, $link, $target ) = @_;

    if ( -l $link ) {
        my $current = readlink($link);
        if ( defined $current and $current eq $target ) {
            push( @{$report}, [ $part, 'ok', undef ] );
            return 1;
        }
        push( @{$report}, [ $part, 'differs', undef ] );
    } elsif ( -e $link ) {
        push( @{$report}, [ $part, 'differs', 'not a symlink' ] );
    } else {
        push( @{$report}, [ $part, 'missing', undef ] );
    }
    return 0;
}

##[ systemctl helpers ]#######################################################
##
## list form only -- no shell. _systemctl_void discards stdout              ##
## [ systemctl enable \ daemon-reload chatter ], _systemctl_capture returns ##
## the first output line                                                    ##
## [ a missing systemctl reads as disabled \ inactive ]                     ##

sub _systemctl_void {
    my (@args) = @_;

    my $pid = fork() // return 0;
    if ( $pid == 0 ) {
        open( STDOUT, '>', File::Spec->devnull );
        exec( qw| systemctl |, @args );
        exit 127;
    }
    waitpid( $pid, 0 );
    return $CHILD_ERROR == 0;
}

sub _systemctl_capture {
    my (@args) = @_;

    my $pid = open( my $pipe, '-|' ) // return ( 1, undef );
    if ( $pid == 0 ) {
        exec( qw| systemctl |, @args );
        exit 127;
    }
    my $line = <$pipe> // '';
    close($pipe);
    chomp $line;
    return ( $CHILD_ERROR >> 8, $line );
}

##[ file helpers ]############################################################

sub _slurp {
    my ($path) = @_;

    open my $fh, '<', $path or return undef;
    local $INPUT_RECORD_SEPARATOR = undef;
    my $content = <$fh>;
    close $fh;
    return $content;
}

## a real directory [ not a symlink ] that IS the checkout ##
sub _is_the_checkout {
    my ( $path, $checkout ) = @_;
    return 0 if -l $path or not -d $path;
    my $real_path     = Cwd::realpath($path);
    my $real_checkout = Cwd::realpath($checkout);
    return (    defined $real_path
            and defined $real_checkout
            and $real_path eq $real_checkout ) ? 1 : 0;
}

## atomic : a temporary file in the same directory, renamed over the target ##
## -- never a half written unit ; 0644 ; write errors count                 ##
sub _write_file {
    my ( $path, $content ) = @_;

    my $dir = File::Spec->catdir( ( File::Spec->splitpath($path) )[ 0, 1 ] );
    make_path($dir) unless -d $dir;
    my $tmp = sprintf '%s.p7-deps.%d', $path, $$;
    open( my $fh, '>', $tmp ) or return 0;
    my $ok = ( print {$fh} $content ) ? 1 : 0;
    $ok = 0 if not close($fh);
    $ok = 0 if $ok and not chmod( 0644, $tmp );
    $ok = 0 if $ok and not rename( $tmp, $path );
    unlink($tmp) if not $ok;
    return $ok;
}

1;

#,,,.,,,,,,,.,.,.,,,.,,..,,..,.,.,..,,,,.,...,..,,...,...,.,.,.,.,,,.,..,,,,,,
#5F4N5ZLLL3PSEA7H6EOG5BTCX4P3OLJBXIASVTK2IPPTUEQHLOYPAHEJ3KP63VV3DERBUO5BXPKRW
#\\\|ZRY5KRML6OYEKXHR7GD4OL4TODC3VWQIEWCE5W3OZAWPWJXBK7A \ / AMOS7 \ YOURUM ::
#\[7]YPQHI34RXQATA4QBEQTBXVNERYBW6Y3FCE4R3M7CILBNAY7O2KAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
