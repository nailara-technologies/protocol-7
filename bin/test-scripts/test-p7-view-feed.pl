#!/usr/bin/env perl

## runs the headless view-feed test [ node ] that lives beside the view in ##
## data/web-root/vhosts/visual.v7.ax/tests/ -- js files there carry no     ##
## signature footer, a '#' footer would break the js syntax                ##

use v5.32.0;
use strict;
use warnings;
use FindBin;

my $root = "$FindBin::Bin/../..";
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

#,,,,,,,,,.,,,,,,,,.,,..,,,,.,,,.,,,.,,,.,...,..,,...,..,,.,.,.,.,,..,,,,,.,.,
#GSQBZK5WQ3QWY3YTC2OB5CSTW7TXBQMOPIUIOUMPWPDN6RCZST4FKPYNL7YCEHW52D4G3SFDLDHJM
#\\\|MNNKOZKDGRTPUX7LEK6745UUARE4MXSIKTUIGB6QY6IZTFG7DOM \ / AMOS7 \ YOURUM ::
#\[7]F725WHPMTHDNEVAS7LFXR2E3BOYVB6UIROK3H6EDKNKYXHGWU6CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
