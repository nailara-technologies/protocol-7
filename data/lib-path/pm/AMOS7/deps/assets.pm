package AMOS7::deps::assets;
our $VERSION = qw| AMOS7::deps::assets-VERSION.7TPQEYA |;

## profile 'assets:' entries [ .deps/profiles.yaml ] : repo files installed ##
## system-wide by bin/p7-deps install, checked by bin/p7-deps check         ##
##                                                                          ##
##   copy <repo path> <target dir>   a file or a whole tree, into the dir   ##
##   alternative <name> <path>       debian update-alternatives --set       ##
##                                                                          ##
## only missing or differing files are written ; a font target runs         ##
## fc-cache once afterwards                                                 ##

use v5.32.0;
use strict;
use warnings;
use English;
use File::Spec;
use File::Find     qw| find |;
use File::Path     qw| make_path |;
use File::Copy     qw| copy |;
use File::Compare  qw| compare |;
use File::Basename qw| dirname basename |;
use Exporter       qw| import |;

our @EXPORT_OK = qw| asset_state install_asset |;

## [ { src, dst } .. ] for one copy entry ##
sub copy_pairs {
    my ( $root, $src_rel, $dst_dir ) = @ARG;
    my $src = File::Spec->catfile( $root, $src_rel );
    return [] if not -e $src;
    my $top = File::Spec->catfile( $dst_dir, basename($src) );
    return [ { 'src' => $src, 'dst' => $top } ] if -f $src;
    my @pairs;
    find(
        {   'no_chdir' => 1,
            'wanted'   => sub {
                return if not -f $File::Find::name;
                my $rel = File::Spec->abs2rel( $File::Find::name, $src );
                push @pairs,
                    {
                    'src' => $File::Find::name,
                    'dst' => File::Spec->catfile( $top, $rel )
                    };
            }
        },
        $src
    );
    return [ sort { $a->{'dst'} cmp $b->{'dst'} } @pairs ];
}

sub current_alternative {
    my ($name) = @ARG;
    my $value = '';
    open( my $fh, '-|', qw| update-alternatives --query |, $name )
        or return '';
    while (<$fh>) { $value = $1 if m|^Value:\s*(\S+)| }
    close($fh);
    return $value;
}

## { label, ok, detail, pending => [ .. ] } for one assets: entry ##
sub asset_state {
    my ( $root, $entry ) = @ARG;
    my ( $kind, @arg )   = split( m|\s+|, $entry );
    $kind //= '';
    if ( $kind eq 'copy' and @arg == 2 ) {
        my $pairs = copy_pairs( $root, @arg );
        return {
            'label'   => $arg[0],
            'ok'      => 0,
            'detail'  => 'source missing in the repo',
            'pending' => []
            }
            if not @{$pairs};
        my @pending = grep {
            not -f $ARG->{'dst'}
                or compare( $ARG->{'src'}, $ARG->{'dst'} )
                != 0
        } @{$pairs};
        return {
            'label'   => $arg[0],
            'ok'      => @pending ? 0 : 1,
            'detail'  => $arg[1],
            'kind'    => 'copy',
            'pending' => \@pending,
        };
    }
    if ( $kind eq 'alternative' and @arg == 2 ) {
        my $ok = current_alternative( $arg[0] ) eq $arg[1] ? 1 : 0;
        return {
            'label'   => $arg[0],
            'ok'      => $ok,
            'detail'  => basename( dirname( $arg[1] ) ),
            'kind'    => 'alternative',
            'name'    => $arg[0],
            'path'    => $arg[1],
            'pending' => $ok ? [] : [ $arg[1] ],
        };
    }
    return {
        'label'   => $entry,
        'ok'      => 0,
        'detail'  => 'unknown assets entry',
        'pending' => []
    };
}

## install one pending state ; returns ( ok, written files, font dirs ) ##
sub install_asset {
    my ($state) = @ARG;
    my ( %font_dirs, $written );
    $written = 0;
    if ( ( $state->{'kind'} // '' ) eq 'copy' ) {
        foreach my $pair ( @{ $state->{'pending'} } ) {
            make_path( dirname( $pair->{'dst'} ), { 'mode' => 0755 } );
            copy( $pair->{'src'}, $pair->{'dst'} ) or return ( 0, $written );
            chmod( 0644, $pair->{'dst'} );
            $written++;
            $font_dirs{ dirname( $pair->{'dst'} ) } = 1
                if $pair->{'dst'} =~ m|/fonts/|;
        }
        system( qw| fc-cache -f |, $ARG ) foreach sort keys %font_dirs;
        return ( 1, $written );
    }
    if ( ( $state->{'kind'} // '' ) eq 'alternative' ) {
        return ( 0, 0 ) if not -e $state->{'path'};
        system( qw| update-alternatives --set |,
            $state->{'name'}, $state->{'path'} );
        return ( $CHILD_ERROR == 0 ? 1 : 0, 1 );
    }
    return ( 0, 0 );
}

1;

#,,,,,,..,,..,.,.,...,.,,,..,,..,,.,.,.,,,.,.,..,,...,...,,.,,,,.,,..,.,.,.,.,
#K2C6C7ASBCIH4EFHB7QRJBNAFHLQYKQKHFI5ZOH4GDIL7VSHNCRJLVKJ7BWVUMLD3BDOTOADKE2WO
#\\\|7K2UGETQZL6WVXZQXMACFU36GTKNPAGDBJEGNBUXYUZWOAQ7EQP \ / AMOS7 \ YOURUM ::
#\[7]UWSR2ASUEJUBDILWNSIUUA5Y2RYWPDZ2G7DUEGIXC74W6UESYWAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
