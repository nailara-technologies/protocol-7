#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## small sealed nodes packed into shared blobs : recovery, checks, damage.

use FindBin;
BEGIN { unshift @INC, "$FindBin::RealBin/../../data/lib-path/pm" }

use AMOS7::N7FS qw| make_dirs |;

require "$FindBin::RealBin/fixtures/n7fs/helpers.pl";

my $box  = sandbox();
my $base = $box->{'base'};
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
$ENV{'N7FS_TEST_PACK_SIZE'} = 64 * 1024;

sub cli {
    my ( $pass, @args ) = @ARG;
    my $pf = "$base/pass";
    write_file( $pf, $pass );
    my $out = "$base/out";
    my $pid = fork // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDIN,  '<',     $pf )      or exit 98;
        open( STDOUT, '>:raw', $out )     or exit 98;
        open( STDERR, '>&',    \*STDOUT ) or exit 98;
        exec( $EXECUTABLE_NAME, "$FindBin::RealBin/../n7fs", '-root', $root,
            '-host-dir', $hdir, @args, '-pass-fd', 0 )
            or exit 99;
    }
    waitpid $pid, 0;
    my $rc = $CHILD_ERROR >> 8;
    open( my $fh, '<:raw', $out ) or die;
    local $INPUT_RECORD_SEPARATOR;
    return ( $rc, scalar <$fh> );
}

sub slurp {
    open( my $fh, '<:raw', shift ) or return undef;
    local $INPUT_RECORD_SEPARATOR;
    return scalar <$fh>;
}

my ( $rc, $out ) = cli( '', 'keygen', "$hdir/host.key" );
( $rc, $out ) = cli( '', 'keygen', "$hdir/parent.key" );
( $rc, $out ) = cli( '', 'pubkey', "$hdir/parent.key" );
write_file( "$hdir/trusted-parents", $out );
( $rc, $out ) = cli( '', 'init', '-name', 't', '-intent', 'x' );
my ($disk)
    = grep { !m|^\.| } do { opendir( my $d, $root ) or die; readdir $d };
( $rc, $out ) = cli( '', 'attach', $disk );

my $tree = "$src/many";
make_dirs("$tree/sub");
write_file( "$tree/f$ARG",     "small file $ARG\n" x $ARG ) for 1 .. 300;
write_file( "$tree/sub/empty", '' );
open( my $big, '>:raw', "$tree/big.bin" ) or die;
print {$big} pack( 'N', $ARG ) x 300000 for 1 .. 2;
close $big;
( $rc, $out )
    = cli( '', 'assimilate', '-disk', $disk, '-keep', '-tree', 't', $tree );
ok( $rc == 0, 'fixture imported' ) or say $out;
( $rc, $out )
    = cli( "pw\npw\n", 'root', 'init', "$base/rk", '-argon-m', 1024,
    '-argon-t', 1 );
my $holder = "$base/holder";
( $rc, $out )
    = cli( "pw\n", 'seal', $disk, '-root-key', "$base/rk", '-out',
    $holder, '-all-trees' );
ok( $rc == 0, 'sealed with packs' ) or say $out;
my $hsub = holder_sub($holder);
ok( defined $hsub, 'a fresh holder starts in the per-root layout' )
    or say $out;
my @blobs = holder_blobs($holder);
## the map adds up to 256 shard blobs + root + journal : packs stay few ##
ok( @blobs < 40 + 258,
    'about 300 small nodes stored in few blobs [ ' . scalar(@blobs) . ' ]' );
my @packs
    = grep { substr( slurp("$hsub/$ARG") // '', 0, 5 ) eq "P7SP\x01" } @blobs;
ok( @packs > 1, 'several packs at the test pack size' );
ok( !grep( { index( slurp("$hsub/$ARG"), 'small file' ) >= 0 } @blobs ),
    'no plaintext in any blob' );

( $rc, $out ) = cli(
    "pw\n",  'seal-recover', '-root-key', "$base/rk",
    '-from', $holder,        '-tree',     't',
    "$base/rec"
);
ok( $rc == 0, 'clean recovery of the packed tree' ) or say $out;
my $same = 1;
foreach my $n ( 1 .. 300 ) {
    $same = 0 if ( slurp("$base/rec/f$n") // 'x' ) ne slurp("$tree/f$n");
}
$same = 0 if ( slurp("$base/rec/big.bin") // 'x' ) ne slurp("$tree/big.bin");
$same = 0 if not -f "$base/rec/sub/empty" or -s "$base/rec/sub/empty";
ok( $same, 'every packed, empty and large file is identical' );

( $rc, $out )
    = cli( "pw\n", 'holder-check', $holder, '-root-key',
    "$base/rk", '-samples', 400 );
ok( $rc == 0, 'holder check passes over packed nodes' ) or say $out;

( $rc, $out )
    = cli( "pw\n", 'seal', $disk, '-root-key', "$base/rk", '-out',
    $holder, '-all-trees' );
ok( $rc == 0 && $out =~ m|sealed 0 new|, 'a repeat run adds nothing' );

## superseded maps and journals : a second seal leaves the first ones ##
write_file( "$tree/later", 'a later file' );
( $rc, $out )
    = cli( '', 'assimilate', '-disk', $disk, '-keep', '-tree', 't2', $tree );
( $rc, $out )
    = cli( "pw\n", 'seal', $disk, '-root-key', "$base/rk", '-out',
    $holder, '-all-trees' );
## a per-root holder needs no -only-root : the listing is its own subdir ##
( $rc, $out ) = cli( "pw\n", 'holder-gc', $holder, '-root-key', "$base/rk" );
ok( $rc == 0 && $out =~ m|would remove|,
    'per-root gc needs no -only-root [ review finding 2 ]' )
    or say $out;
my $count  = sub { scalar holder_blobs($holder) };
my $before = $count->();
( $rc, $out )
    = cli( "pw\n", 'holder-gc', $holder, '-root-key', "$base/rk",
    '-grace', '0' );
ok( $rc == 0 && $out =~ m|would remove [1-9]| && $count->() == $before,
    'a dry run lists superseded blobs and deletes nothing'
) or say $out;
( $rc, $out )
    = cli( "pw\n", 'holder-gc', $holder, '-root-key',
    "$base/rk", '-delete', '-grace', '0' );
ok( $rc == 0 && $count->() < $before,
    'superseded blobs removed to the trash'
) or say $out;
( $rc, $out ) = cli(
    "pw\n",  'seal-recover', '-root-key', "$base/rk",
    '-from', $holder,        '-tree',     't2',
    "$base/rec3"
);
ok( $rc == 0
        && ( slurp("$base/rec3/later") // '' ) eq 'a later file'
        && ( slurp("$base/rec3/f9")    // '' ) eq slurp("$tree/f9"),
    'the holder still recovers fully after gc'
) or say $out;
( $rc, $out )
    = cli( "pw\n", 'holder-gc', $holder, '-root-key', "$base/rk",
    '-only-root' );
ok( $out =~ m|would remove 0 |, 'nothing left to collect' ) or say $out;

## pack members seal in memory : no per-node temp, and the byte form is ##
## exact                                                                ##
{
    require AMOS7::N7FS::Seal;
    require AMOS7::N7FS::Sum;
    my $writes = 0;
    no warnings qw| redefine once |;
    local *AMOS7::N7FS::Seal::write_new_file_stream = sub {
        $writes++;
        die "pack member used a synced temporary\n";
    };
    local *AMOS7::N7FS::Seal::sync_dir = sub { $writes++; return 1 };
    my $plain = slurp("$tree/f1");
    my $keys  = AMOS7::N7FS::Seal::new_keypair();
    my $bmw
        = AMOS7::N7FS::Sum::bmw_b32( AMOS7::N7FS::Sum::bmw384_bytes($plain) );
    my ( $name, $chunks, $packed )
        = AMOS7::N7FS::Seal::_node_blob( "$tree/f1", $keys, $hsub, $bmw, {},
        1 );
    ok( $writes == 0, 'a pack member writes and syncs no temporary file' );
    my $expected
        = "P7SB\x01"
        . pack( 'C Q> N Q>', 0, 16 * 1024 * 1024, 0, 1 )
        . pack(
        'N/a*',
        AMOS7::N7FS::Seal::seal_bytes(
            $keys, $plain, 'content', '', 0, 0, 1
        )
        );
    ok( $chunks == 1
            && $packed eq $expected
            && $name eq AMOS7::N7FS::Sum::bmw_b32(
            AMOS7::N7FS::Sum::bmw384_bytes($expected)
            ),
        'in-memory sealing keeps the existing blob bytes and address'
    );
}

## damage one byte inside a pack : the node in that range fails alone ##
my $pack  = $packs[0];
my $bytes = slurp("$hsub/$pack");
substr( $bytes, 200, 1 ) = chr( ord( substr( $bytes, 200, 1 ) ) ^ 1 );
chmod 0600, "$hsub/$pack";
write_file( "$hsub/$pack", $bytes );
( $rc, $out ) = cli(
    "pw\n",  'seal-recover', '-root-key', "$base/rk",
    '-from', $holder,        '-tree',     't',
    "$base/rec2"
);
ok( $rc != 0, 'a damaged packed node refuses recovery of the tree' );
( $rc, $out )
    = cli( "pw\n", 'holder-check', $holder, '-root-key',
    "$base/rk", '-samples', 400 );
ok( $rc != 0, 'holder check finds the damaged packed node' );

done();

#,,,.,.,,,.,.,.,,,..,,..,,.,,,,,.,,,,,,,,,.,.,..,,...,...,...,,,.,.,,,,.,,...,
#HPYVKFQCT72IUHRRO57GVJDHTLRQ3TAX6IABZBQWGLZTZHNPE3AMPDBIHHVUDBD47NVUR3ENANCUU
#\\\|C62UJCXBDD7FRPTUFMTVT6ZAXKPVK4GJAC776ZJUW5P7AQG3WIY \ / AMOS7 \ YOURUM ::
#\[7]WL7I6P3K7N2GOR22Z5YMHCDFIXYDQZ43TCWRDSRPFENMJCBTCKDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
