#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## stage 5 : vault holder registry, receipts, placement report and place.

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }
use AMOS7::Vault qw| vault_init |;
use AMOS7::N7FS  qw| make_dirs |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

my $box  = sandbox();
my $base = $box->{'base'};
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
my $vdir = "$base/vault";
$ENV{'N7FS_HOST_DIR'} = $hdir;
vault_init( $vdir, 'vp', undef, t => 1, m => 1024, p => 1 );

sub cli {
    my ( $lines, @args ) = @ARG;
    my $pf = "$base/pass";
    write_file( $pf, join '', map {"$ARG\n"} @{$lines} );
    my $out = "$base/out";
    my $pid = fork // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDIN,  '<',     $pf )      or exit 98;
        open( STDOUT, '>:raw', $out )     or exit 98;
        open( STDERR, '>&',    \*STDOUT ) or exit 98;
        exec( $EXECUTABLE_NAME, "$FindBin::Bin/../n7fs", '-root', $root,
            '-host-dir', $hdir, @args, '-pass-fd', 0, '-vault-dir', $vdir )
            or exit 99;
    }
    waitpid $pid, 0;
    my $rc = $CHILD_ERROR >> 8;
    open( my $fh, '<:raw', $out ) or die;
    local $INPUT_RECORD_SEPARATOR;
    return ( $rc, scalar <$fh> );
}

my ( $rc, $out ) = cli( [], 'keygen', "$hdir/host.key" );
( $rc, $out ) = cli( [], 'keygen', "$hdir/parent.key" );
( $rc, $out ) = cli( [], 'pubkey', "$hdir/parent.key" );
write_file( "$hdir/trusted-parents", $out );
( $rc, $out ) = cli( [], 'init', '-name', 't', '-intent', 'x' );
my ($disk)
    = grep { !m|^\.| } do { opendir( my $d, $root ) or die; readdir $d };
( $rc, $out ) = cli( [], 'attach', $disk );
( $rc, $out ) = cli( [], 'category', $disk, 'set', 'two', '-copies', 2 );
my $tree = "$src/t";
make_dirs($tree);
write_file( "$tree/f$ARG", "file $ARG\n" ) for 1 .. 20;
( $rc, $out ) = cli(
    [],  'assimilate', '-disk', $disk, '-keep', '-tree',
    't', '-category',  'two',   $tree
);
ok( $rc == 0, 'fixture imported in a two-copy category' ) or say $out;
( $rc, $out ) = cli( ['vp'], 'root', 'init', 'vault:main' );

my @h = map {"$base/h$ARG"} 1 .. 4;
make_dirs($ARG) for @h;
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'one', $h[0], '-domain', 'a', '-owned' );
ok( $rc == 0, 'holder added to the vault registry' ) or say $out;
( $rc, $out ) = cli( ['vp'], 'holder', 'add', 'two', $h[1], '-domain', 'a' );
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'three', $h[2], '-domain', 'b' );
( $rc, $out ) = cli(
    ['vp'], 'holder', 'add', 'four', $h[3], '-domain',
    'c',    '-role',  'intake'
);
( $rc, $out ) = cli( ['vp'], 'holder', 'list' );
ok( $rc == 0 && $out =~ m|^one durable a owned|m && $out =~ m|^four intake|m,
    'registry lists the holders'
);
( $rc, $out ) = cli( ['vp'], 'holder', 'add', 'bad', $h[0] );
ok( $rc != 0, 'a holder without a domain is refused' );

( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $rc == 0 && $out =~ m|category two target 2 : \d+ nodes at 0|,
    'report shows nothing placed yet' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main', '-dry-run' );
ok( $rc == 0
        && $out =~ m|would place \d+ nodes on one|
        && $out =~ m|would place \d+ nodes on three|
        && $out !~ m|on two|
        && $out !~ m|on four|,
    'plan uses two domains, owned first, skips the '
        . 'second holder in a domain and the intake holder'
) or say $out;
( $rc, $out ) = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main' );
ok( $rc == 0, 'place seals the missing copies' ) or say $out;
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|one \[ a \] no fresh receipt|,
    'copies count only after a receipt'
) or say $out;

foreach my $i ( 0 .. 2 ) {
    ( $rc, $out )
        = cli( ['vp'], 'holder-check', $h[$i], '-root-key', 'vault:main' );
    say "        check $i : $out" if $rc != 0;
}
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|category two target 2 : \d+ nodes at 2| && $out !~ m|under-rep|,
    'every node reaches its target after receipts'
) or say $out;

( $rc, $out ) = cli(
    ['vp'],  'seal-recover', '-root-key', 'vault:main',
    '-from', $h[2],          '-tree',     't',
    "$base/rec"
);
ok( $rc == 0 && -f "$base/rec/f7", 'a placed holder recovers the tree' )
    or say $out;

( $rc, $out ) = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main' );
ok( $rc == 0 && $out !~ m|placed|, 'a second place has nothing to do' )
    or say $out;
## draining : 'one' and 'three' each hold every node [ target 2 ] ##
( $rc, $out )
    = cli( ['vp'], 'holder-drain', $disk, 'one', '-root-key',
    'vault:main', '-dry-run' );
ok( $out =~ m|kept 20 nodes|,
    'drain keeps nodes that would fall below their target' )
    or say $out;
make_dirs("$base/h7");
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'five', "$base/h7", '-domain', 'f' );
( $rc, $out )
    = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main',
    '-exclude', 'one' );
ok( $out =~ m|placed \d+ nodes on five|,
    'place with -exclude fills the new holder for a move' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-drain', $disk, 'one', '-root-key',
    'vault:main', '-dry-run' );
ok( $out =~ m|kept|, 'a copy without a receipt does not count yet' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-check', "$base/h7", '-root-key', 'vault:main' );
( $rc, $out )
    = cli( ['vp'], 'holder-drain', $disk, 'one', '-root-key', 'vault:main' );
ok( $rc == 0 && $out =~ m|dropped [1-9]\d* nodes| && $out !~ m|kept|,
    'after a receipt elsewhere the holder drains' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-gc', $h[0], '-root-key', 'vault:main',
    '-only-root', '-delete' );
ok( $rc == 0 && $out =~ m|removed [1-9]|, 'gc frees the drained blobs' )
    or say $out;
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|category two target 2 : \d+ nodes at 2| && $out !~ m|under-rep|,
    'targets still met after drain and gc'
) or say $out;
( $rc, $out ) = cli(
    ['vp'],  'seal-recover', '-root-key', 'vault:main',
    '-from', "$base/h7",     '-tree',     't',
    "$base/rec7"
);
ok( $rc == 0 && -f "$base/rec7/f7", 'the new holder recovers the tree' )
    or say $out;

( $rc, $out ) = cli( ['vp'], 'holder', 'remove', 'three' );
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|under-replicated|, 'removing a holder shows the shortfall' )
    or say $out;
( $rc, $out ) = cli(
    ['vp'], 'holder', 'add', 'small', "$base/h5", '-domain',
    'd',    '-quota', '10'
);
( $rc, $out )
    = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main', '-dry-run' );
ok( $out !~ m|on small|, 'quota keeps a holder from filling' )
    or say $out;
( $rc, $out ) = cli(
    ['vp'], 'holder',   'add', 'full', "$base/h6", '-domain',
    'e',    '-reserve', '1000000T'
);
make_dirs("$base/h6");
( $rc, $out )
    = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main', '-dry-run' );
ok( $out !~ m|on full|,
    'a holder whose reserve exceeds its free space receives nothing' )
    or say $out;
( $rc, $out ) = cli( ['wrong'], 'holder', 'list' );
ok( $rc != 0, 'registry needs the vault passphrase' );

done();

#,,,.,..,,,..,.,,,,,,,,..,...,..,,.,,,,,,,,..,..,,...,...,..,,,,,,,..,.,.,..,,
#D4DSQOB6T5BIFVU736QNUTRCEXQ33VLT22C7QB4XACB72TS34ZQ3L5JGGDHDKJZG36NLRPUUWNSS4
#\\\|TB4A5FFCH64W635KEKA2QXNPS2PASQ7BJYGIFGLF4PFI6PIK7BN \ / AMOS7 \ YOURUM ::
#\[7]XPLEHOMJSVSV3ESUI4LHNDWVABXSXZZZXRAWRG74ZUOFQRDBLOAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
