#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## place reuses one authenticated journal replay for planning and every seal.

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }
use Time::HiRes  qw| time |;
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
( $rc, $out ) = cli( [], 'init', '-name', 'cache', '-intent', 'benchmark' );
my ($disk)
    = grep { !m|^\.| } do { opendir( my $d, $root ) or die; readdir $d };
( $rc, $out ) = cli( [], 'attach', $disk );
my $tree = "$src/many";
make_dirs($tree);
write_file( "$tree/f$ARG", "file $ARG\n" ) for 1 .. 2500;
( $rc, $out )
    = cli( [], 'assimilate', '-disk', $disk, '-keep', '-tree', 'many',
    $tree );
ok( $rc == 0, '2500-file fixture assimilated' ) or say $out;
( $rc, $out ) = cli( ['vp'], 'root', 'init', 'vault:main' );

my @seconds;
foreach my $cached ( 0, 1 ) {
    my $holder = "$base/holder-$cached";
    make_dirs($holder);
    ( $rc, $out )
        = cli( ['vp'], 'holder', 'add', "h$cached", $holder,
        '-domain', "d$cached" );
    if ($cached) {
        delete $ENV{'N7FS_JOURNAL_CACHE'};
    } else {
        $ENV{'N7FS_JOURNAL_CACHE'} = 0;
    }
    my $start = time();
    ( $rc, $out ) = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main',
        $cached
        ? ( '-exclude', 'h0', '-commit-bytes', '1G', '-commit-age', '99Y0' )
        : () );
    push @seconds, time() - $start;
    ok( $rc == 0 && $out =~ m|placed 2500 nodes on h$cached|,
        $cached ? 'cached place succeeds' : 'uncached place succeeds'
    ) or say $out;
}
printf "journal replay timing : uncached %.3f s, cached %.3f s\n", @seconds;

require AMOS7::N7FS::Disk;
require AMOS7::N7FS::Placement;
my $id = AMOS7::N7FS::Disk::disk_read_id(
    qw| root | => $root,
    qw| disk | => $disk
);
my $replay = AMOS7::N7FS::Placement::journal_replay_cached($id);
ok( $replay == AMOS7::N7FS::Placement::journal_replay_cached($id),
    'an unchanged journal position reuses the replay'
);
write_file( "$id->{'path'}/.n7fs/journal/99999999999999.journal", 'new' );
ok( !eval { AMOS7::N7FS::Placement::journal_replay_cached($id); 1 },
    'a new journal position invalidates the replay' );

done();

#,,..,,,.,,,.,,..,,,.,...,...,,.,,.,.,,..,,..,..,,...,...,...,,,,,.,.,,.,,.,.,
#A24AFICNCEF3ES5OSJKEW2REVO3YOMKB66EXNZC5DE7IRYI5P6STYYFIL4FRFQL4AYZZ4IPXKNMZY
#\\\|RE5G2HUSSVAQG3EM2DACASUPHNOLQJQ5X43QBX5YV55ZLUAYZKF \ / AMOS7 \ YOURUM ::
#\[7]O6IPUJZ4RQJBV2I5ISTQPQVBDH73CEFYBP76KQ5PBVCVYXLYISBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
