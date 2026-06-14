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
    my ( $out, $err, $exit ) = p7c( 'v7.start', $name );
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

#,,..,.,,,...,,,.,,,.,...,..,,,,.,,..,.,.,,,.,..,,...,..,,...,.,.,,,.,,,.,,.,,
#BBI5JKN2R2YHB4B3GUJ4XXOSGOSPUGXC4YZJNYCQ3KXJL43V24XFVZ22NCCIJIUT5MFVIFIHXVRSO
#\\\|G4ZAAEXVUIG7X4X6YIMTUE5BLGE6IZGBQ5A4AYQO2ZVPA5EECMP \ / AMOS7 \ YOURUM ::
#\[7]QAHJSH7OAAHEAAO6N477JUONE4NR6QL6HEGMVIXPHZQWYFWDYABQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
