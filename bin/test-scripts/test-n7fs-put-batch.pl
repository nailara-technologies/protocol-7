#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## holder_put_batch : many small blobs in three ssh calls
## [ probe, tar upload, tar read back ] ; existing blobs kept, a wrong size
## refused

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }
use AMOS7::N7FS         qw| make_dirs read_file write_new_file |;
use AMOS7::N7FS::Sum    qw| bmw384_bytes bmw_b32 |;
use AMOS7::N7FS::Holder qw| holder_put_batch |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

my $box  = sandbox();
my $base = $box->{'base'};
my $fake = "$base/fake-ssh.sh";
copy_tree( "$FindBin::Bin/fixtures/n7fs/fake-ssh.sh", $fake );
chmod 0755, $fake or die $OS_ERROR;
my $remote = "$base/remote";
make_dirs( "$remote/holder", 0700 );
my $log = "$base/ssh.log";
write_new_file( $log, '' );
$ENV{'N7FS_SSH'}         = $fake;
$ENV{'FAKE_SSH_LOG'}     = $log;
$ENV{'FAKE_HOLDER_ROOT'} = "$remote/holder";
$ENV{'N7FS_SSH_BACKOFF'} = '0,0,0,0,0';
my $spec  = 'ssh:fake:/holder';
my $spool = "$base/spool";
make_dirs( $spool, 0700 );

sub spooled {
    my $bytes = shift;
    my $name  = bmw_b32( bmw384_bytes($bytes) );
    write_new_file( "$spool/$name", $bytes ) if not -e "$spool/$name";
    return [ "$spool/$name", $name, qw| map | ];
}

sub calls {
    my $text = read_file($log) // '';
    return scalar( () = $text =~ m|\n|g );
}

my @items = map { spooled( "shard $ARG " . ( 'x' x $ARG ) ) } 1 .. 40;
## one blob already on the holder : kept, not uploaded again
write_new_file( "$remote/holder/$items[0][1]", read_file( $items[0][0] ) );

my $before = calls();
my $ok     = eval { holder_put_batch( $spec, \@items ); 1 };
ok( $ok,                    'batch of 40 blobs accepted' ) or say $EVAL_ERROR;
ok( calls() - $before == 3, 'three ssh calls for the whole batch' )
    or say calls() - $before;
my $all = 1;
foreach my $item (@items) {
    $all = 0
        if ( read_file("$remote/holder/$item->[1]") // '' ) ne
        read_file( $item->[0] );
}
ok( $all, 'every blob on the holder byte for byte' );
my @left = glob "$remote/holder/.batch.*";
ok( !@left, 'no temporary batch directory left' );

## a rerun is a no-op upload : the probe sees every blob
$before = calls();
$ok     = eval { holder_put_batch( $spec, \@items ); 1 };
ok( $ok && calls() - $before == 2, 'rerun : probe and read back only' );

## a holder blob of the wrong size refuses the batch
my @bad = ( spooled('bad one'), spooled('bad two') );
write_new_file( "$remote/holder/$bad[0][1]", 'short' );
refused( sub { holder_put_batch( $spec, \@bad ) },
    qr|wrong size|, 'wrong-size holder blob refused' );

## a single item goes the one-blob way
$before = calls();
$ok     = eval { holder_put_batch( $spec, [ spooled('alone') ] ); 1 };
ok( $ok,                    'single item placed' );
ok( calls() - $before >= 1, 'single item uses holder_put' );

done();

#,,..,.,,,,,.,,,.,...,,,.,.,.,.,.,..,,.,,,.,,,..,,...,...,,,,,,..,,,.,,,,,,,,,
#MPM33TCCIPZLCAAQCYQWPWRL4SZV3RMP6MMVJH2FWBIS4PRSO2YUUWC77ETZCWTFOSIK54UKYPOLQ
#\\\|Z6HIYNIPZ7K3TJQX63HQ2IY5AE7EFKEXGR6WOAOSILFNTMFSMPF \ / AMOS7 \ YOURUM ::
#\[7]OZGCXMHYYE6JN3HR2C27WPNZYZQM7ONKHFNYKFCKWJELW5K22AAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
