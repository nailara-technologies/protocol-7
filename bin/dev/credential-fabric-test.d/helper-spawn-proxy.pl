#!/usr/bin/perl

# [ helper: ensure proxy + transport + credential_fabric zenki are running ]

use v5.24;
use strict;
use warnings;
use English;

use File::Spec;
use FindBin qw| $RealBin |;
use lib File::Spec->catdir( $RealBin, 'lib' );
use CredFabTest qw| p7c zenka_running proxy_port_ready |;

my $VERBOSE = $ENV{'CREDFAB_TEST_VERBOSE'} // 0;

sub start_if_missing {
    my ($name) = @ARG;
    if ( zenka_running($name) ) {
        print "[ info ] $name already running\n" if $VERBOSE;
        return 1;
    }
    print "[ info ] starting $name zenka\n";
    my ( $out, $err, $exit ) = p7c( 'v7-zenki.start', $name );
    if ( $exit != 0 or $out !~ m{job queued|already running}i ) {
        warn "[ warn ] failed to start $name: $out $err\n";
        return 0;
    }
    return 1;
}

start_if_missing('credential_fabric');
start_if_missing('proxy');
start_if_missing('transport');

# [ wait for proxy listener ]
if ( proxy_port_ready() ) {
    print "[ info ] proxy listening on 127.0.0.1:8118\n";
    exit 0;
}

warn "[ fatal ] proxy did not become ready on 127.0.0.1:8118\n";
exit 1;

# [ end ]

#,,,.,,.,,.,,,..,,,.,,,,,,..,,...,,,.,,.,,..,,..,,...,...,..,,..,,,..,.,.,,..,
#G2YQWPCWCBMGDU4J4AIR4L2E2S7PJ2PBTXZCWBWBFWARGLEBIRXJ44MCPW6X7G4J4J2GRYXXC2U24
#\\\|4LPT3WBXM6ZVIQCCBFEUXH4SOKIAGWHRX3DBGD4QHMVGGO7L6MP \ / AMOS7 \ YOURUM ::
#\[7]OKQQBNU3CGPI3GH2H25JCO5DDGDT32X4Y6S4UNQYG6ZKO22Y3UAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
