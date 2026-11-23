#!/usr/bin/env perl
use v5.32.0;
use strict;
use English;
use warnings;

use FindBin;
BEGIN { unshift @INC, "$FindBin::RealBin/../../data/lib-path/pm" }

use AMOS7::N7FS::Disk  qw| disk_init disk_attach |;
use AMOS7::N7FS::Store qw| assimilate |;

require "$FindBin::RealBin/fixtures/n7fs/helpers.pl";

use constant TRUE => 5;

my $box  = sandbox();
my $root = $box->{'root'};
my $hdir = $box->{'host'};
my $src  = $box->{'src'};
my $host = test_signer();
clock_real();

my %base = ( root => $root, host_dir => $hdir );
my $disk = disk_init(
    %base,
    parent => test_signer(),
    name   => 'space-check-test',
    intent => 'n7fs space check test [ test data ]',
);
my %run = ( %base, disk => $disk, host => $host );
disk_attach(%run);

my $body = "test data : space check\n" x 13;
write_file( "$src/one", $body );
write_file( "$src/two", $body );

local $AMOS7::N7FS::Store::STATVFS
    = sub { return [ 1, 1, 1000, 1000, length($body) - 1, 1, 1, 1 ] };
my $before = snapshot($root);
refused(
    sub { assimilate( %run, paths => [ "$src/one", "$src/two" ] ) },
    qr|expected store growth \d+ bytes exceeds free space \d+ bytes|,
    'too small store file system is refused with both numbers'
);
ok( snap_equal( $before, snapshot($root) ),
    'refusal writes no store content'
);

local $AMOS7::N7FS::Store::STATVFS
    = sub { return [ 1, 1, 1000, 1000, length($body), 1, 1, 1 ] };
my $report = assimilate( %run, paths => [ "$src/one", "$src/two" ] );
ok( $report->{'failed'} == 0, 'exactly enough room passes' );
ok( scalar( grep { $ARG->{'status'} eq 'stored' } $report->{'entries'}->@* )
        == 1,
    'duplicate batch content is counted and stored once'
);

local $AMOS7::N7FS::Store::STATVFS
    = sub { return [ 1, 1, 1000, 1000, 0, 1, 1, 1 ] };
my $repeat = assimilate( %run, paths => ["$src/one"] );
ok( $repeat->{'entries'}[0]{'status'} eq 'unchanged',
    'already stored content needs no free data space'
);

done();

#,,..,...,,.,,,,,,.,.,.,,,...,,,.,...,,..,,,,,..,,...,..,,..,,,.,,,..,..,,,,,,
#JYTZHXOYMX4AMQIVE37WRO2BJOILLMAHXSDF2LAPVQM533V4ZNO7O2WTEGPNM5YOQJKG2EDWQLPTE
#\\\|GCUE7QZWDTCRXOW3DZUIDACWRVMFFASWYDJHLEEJSWLUDNRHIPV \ / AMOS7 \ YOURUM ::
#\[7]WISL7ETALAFDXINWK4JEQL45SEN7M5MEQKEEJFZWIZFRUR2RKCDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
