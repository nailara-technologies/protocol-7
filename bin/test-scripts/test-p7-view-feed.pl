#!/usr/bin/env perl

## runs the headless view-feed test [ node ] that lives beside the view in ##
## data/web-root/vhosts/visual.v7.ax/tests/ -- js files there carry no     ##
## signature footer, a '#' footer would break the js syntax                ##

use v5.32.0;
use strict;
use warnings;
use FindBin;

my $root = "$FindBin::RealBin/../..";
my $test = "$root/data/web-root/vhosts/visual"
    . ".v7.ax/tests/test-p7-view-feed.js";

my ($node) = grep {-x} (
    $ENV{'P7_NODE'} // (),
    glob('~/.nvm/versions/node/*/bin/node'),
    '/usr/bin/node', '/usr/local/bin/node'
);

if ( not defined $node ) {
    say 'skip : no node runtime found [ set P7_NODE ]';
    exit 0;
}

exec( $node, $test ) or die "exec $node : $!\n";

#,,,,,,,,,,..,...,..,,,,.,...,,..,...,...,.,,,..,,...,..,,...,,..,,..,,,.,.,.,
#GLFBM25NXPW6337ZVAYJN4NNIP7UTXHMVE6IIZ7EX37NLSUD5QOOVK3VYVWV3XWANI5MCFBFFVNDQ
#\\\|Q3D3646CTQJEA6V3T6EC4CJAZVJBJIZSWO4FC7VNWH2Z7EJ7ASV \ / AMOS7 \ YOURUM ::
#\[7]XXO3OWFUGPXNRNNXEKWQHI5YIBVKJ6Z3SM2NWFQ3OZCVULXEXGBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
