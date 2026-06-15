#!/usr/bin/perl

# [ helper: ensure proxy + transport + cred-mesh zenki are running ]

use v5.24;
use strict;
use warnings;
use English;

use File::Spec;
use FindBin qw| $RealBin |;
use lib File::Spec->catdir( $RealBin, 'lib' );
use CredMeshTest qw| p7c zenka_running proxy_port_ready |;

my $VERBOSE = $ENV{'CREDMESH_TEST_VERBOSE'} // 0;

sub start_if_missing {
    my ($name) = @ARG;
    if ( zenka_running($name) ) {
        print "[ info ] $name already running\n" if $VERBOSE;
        return 1;
    }
    print "[ info ] starting $name zenka\n";
    my ( $out, $err, $exit ) = p7c( 'v7.start', $name );
    if ( $exit != 0 or $out !~ m{job queued|already running}i ) {
        warn "[ warn ] failed to start $name: $out $err\n";
        return 0;
    }
    return 1;
}

start_if_missing('cred-mesh');
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

#,,,.,,.,,..,,...,,..,,.,,.,,,,,.,.,,,.,.,,..,..,,...,..,,.,.,.,.,.,.,.,,,.,,,
#BBNK3TUJHQHNP5FTAG5XW6CBZ4S74IOBBE2PJHOID3FTW2N7QREURJLMIIQIDUNPF2UZFUWQIV6B4
#\\\|KDA2B6QQFFABBYNZCULQ2TNWJR2SDX3H6QAAL65CLQB7JCPIQ6M \ / AMOS7 \ YOURUM ::
#\[7]7UEWWPGCRNFWLITAOKQB2T4W6LFTLAY6IR3PENVHHKBRZBXLW2CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
