#!/usr/bin/perl

# [ helper: ensure proxy + transport + cred-mesh zenki are running ]

use v5.24;
use strict;
use warnings;
use English;

use File::Spec;
use FindBin qw| $RealBin |;
use lib File::Spec->catdir( $RealBin, 'lib' );
use CredMeshTest qw|
    p7c zenka_running wait_for_zenka_online proxy_port_ready
    |;

my $VERBOSE = $ENV{'CREDMESH_TEST_VERBOSE'} // 0;

sub start_if_missing {
    my ($name) = @ARG;
    if ( zenka_running($name) ) {
        print "[ info ] $name already running\n" if $VERBOSE;
        return 1;
    }
    print "[ info ] starting $name zenka\n";
    my $start_arg = $name;
    if ( $name =~ m{^(?:cred-mesh|proxy|transport)$} ) {
        $start_arg = "$name :env:PROTOCOL_7_VAR=$ENV{'CREDMESH_TEST_DIR'}:";
    }
    my ( $out, $err, $exit ) = p7c( 'v7-zenki.start', $start_arg );
    if ( $exit != 0 or $out !~ m{job queued|already running}i ) {
        warn "[ warn ] failed to start $name: $out $err\n";
        return 0;
    }

    ## v7-zenki.start only queues the start job -- wait for cube to actually
    ## see it online before returning, so callers issuing commands right
    ## after this don't race a zenka that hasn't finished connecting yet
    ## ("client not present" failures) ##
    if ( not wait_for_zenka_online( $name, 15 ) ) {
        warn "[ warn ] $name did not reach 'online' status in time\n";
        return 0;
    }
    print "[ info ] $name online\n" if $VERBOSE;
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

#,,,.,.,.,...,,.,,,,,,...,...,..,,.,.,,,.,.,,,..,,...,...,,..,...,,.,,,.,,..,,
#QABGIYB7UKT25PYBZG2HCU3REVOCB7CQCKRI2VFJVNSA2DBCRQFNLDO5DQ2EOPZ3NLMMGTT3VERH6
#\\\|R567HMRO5J47PENKGX7N7ZNOW4WVPAAO2UOY7LBUDQ2FMIS5UMI \ / AMOS7 \ YOURUM ::
#\[7]GJX6KYAZUKQCJDEVJKXM37WLNC4JS5FR7AR2V2WTT7AHLVIHY2CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
