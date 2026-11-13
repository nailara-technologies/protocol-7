#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## legacy drain, two-disk untag, relay disk-id merge and orphan prune.

use constant TRUE  => 5;
use constant FALSE => 0;

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }
use AMOS7::Vault qw| vault_init |;
use AMOS7::N7FS  qw| make_dirs read_file |;
use AMOS7::N7FS::Keys;
use AMOS7::N7FS::Seal;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

my $box  = sandbox();
my $base = $box->{'base'};
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
my $vdir     = "$base/vault";
my $root_key = 'vault:main';
$ENV{'N7FS_HOST_DIR'} = $hdir;
vault_init( $vdir, 'vp', undef, t => 1, m => 1024, p => 1 );
write_file( "$base/root-pass", "vp\n" );

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

sub open_root {
    open( my $fh, '<', "$base/root-pass" ) or die;
    return AMOS7::N7FS::Keys::root_open(
        qw| path |      => $root_key,
        qw| pass_fd |   => fileno($fh),
        qw| vault_dir | => $vdir,
    );
}

sub read_map {
    my $holder = shift;
    my ( undef, $head, $map )
        = AMOS7::N7FS::Seal::_context( open_root(), $holder, TRUE );
    return ( $head, $map );
}

my ( $rc, $out ) = cli( [], 'keygen', "$hdir/host.key" );
( $rc, $out ) = cli( [], 'keygen', "$hdir/parent.key" );
( $rc, $out ) = cli( [], 'pubkey', "$hdir/parent.key" );
write_file( "$hdir/trusted-parents", $out );
( $rc, $out ) = cli( [], 'init', '-name', 'one', '-intent', 'x' );
my ($disk)
    = grep { !m|^\.| } do { opendir( my $d, $root ) or die; readdir $d };
( $rc, $out ) = cli( [], 'attach', $disk );
make_dirs("$src/t");
write_file( "$src/t/file", "shared content\n" );
( $rc, $out )
    = cli( [], 'assimilate', '-disk', $disk, '-keep', '-tree', 't',
    "$src/t" );
ok( $rc == 0, 'the first disk has a tree' ) or say $out;
( $rc, $out ) = cli( [], 'init', '-name', 'two', '-intent', 'y' );
my ($disk2)
    = grep { !m|^\.| and $ARG ne $disk }
    do { opendir( my $d, $root ) or die; readdir $d };
( $rc, $out ) = cli( [], 'attach', $disk2 );
( $rc, $out ) = cli( [], 'sync', $disk, $disk2 );
ok( $rc == 0, 'the second disk has the same content addresses' ) or say $out;
make_dirs("$src/u");
write_file( "$src/u/other", "other disk only\n" );
( $rc, $out )
    = cli( [], 'assimilate', '-disk', $disk2, '-keep', '-tree',
    'u', "$src/u" );
( $rc, $out ) = cli( ['vp'], 'root', 'init', $root_key );
ok( $rc == 0, 'root key file created' ) or say $out;

my %holder = (
    qw| source | => "$base/source",
    qw| second | => "$base/second",
    qw| shared | => "$base/shared",
    qw| legacy | => "$base/legacy",
);
make_dirs( $holder{$ARG} ) for keys %holder;
foreach my $name ( sort keys %holder ) {
    ( $rc, $out )
        = cli( ['vp'], 'holder', 'add', $name, $holder{$name},
        '-domain', $name );
}
( $rc, $out ) = cli(
    ['vp'],    'seal', $disk,             '-root-key',
    $root_key, '-out', $holder{'source'}, '-tree',
    't'
);
( $rc, $out ) = cli(
    ['vp'],    'seal', $disk2,            '-root-key',
    $root_key, '-out', $holder{'second'}, '-tree',
    't'
);
( $rc, $out ) = cli(
    ['vp'],    'seal', $disk,             '-root-key',
    $root_key, '-out', $holder{'legacy'}, '-tree',
    't'
);
( $rc, $out ) = cli(
    ['vp'],    'seal', $disk2,            '-root-key',
    $root_key, '-out', $holder{'legacy'}, '-tree',
    'u'
);
ok( $rc == 0, 'holders contain one shared and one disk-specific tree' )
    or say $out;

## strip disk ids in the sandbox instead of adding a production test switch ##
{
    my $root_open = open_root();
    my ( $state, undef, $map, $base )
        = AMOS7::N7FS::Seal::_context( $root_open, $holder{'legacy'}, FALSE );
    delete $ARG->{'disks'} for values $map->{'nodes'}->%*;
    AMOS7::N7FS::Seal::_commit( $root_open, $base,
        AMOS7::N7FS::Holder::holder_canonical( $holder{'legacy'} ),
        $state, $map, { qw| test_legacy | => TRUE } );
}
( undef, my $legacy_map ) = read_map( $holder{'legacy'} );
ok( !( grep { exists $ARG->{'disks'} } values $legacy_map->{'nodes'}->%* ),
    'the legacy fixture has no disk ids' );
( $rc, $out )
    = cli( ['vp'], 'holder-check', '-full', $holder{'source'},
    '-root-key', $root_key );
( $rc, $out )
    = cli( ['vp'], 'holder-drain', $disk, 'legacy', '-root-key', $root_key );
ok( $rc == 0
        && $out =~ m|dropped 1 nodes|
        && $out =~ m|kept 1 nodes, \d+ bytes : no disk id|,
    'legacy drain takes live-here entries and reports the others'
) or say $out;
( undef, $legacy_map ) = read_map( $holder{'legacy'} );
ok( !exists $legacy_map->{'trees'}{'t'} && exists $legacy_map->{'trees'}{'u'},
    'legacy drain keeps the other disk\'s tree'
);

( $rc, $out )
    = cli( ['vp'], 'relay', 'source', 'shared', '-root-key', $root_key );
ok( $rc == 0 && $out =~ m|relayed 1 nodes|,
    'the shared holder starts with the first disk\'s ids' )
    or say $out;
( my $before_merge, undef ) = read_map( $holder{'shared'} );
( $rc, $out )
    = cli( ['vp'], 'relay', 'second', 'shared', '-root-key', $root_key );
( my $after_merge, my $shared_map ) = read_map( $holder{'shared'} );
ok( $rc == 0
        && $out =~ m|relayed 0 nodes|
        && $out =~ m|merged disk ids for 1 existing nodes|
        && $after_merge->{'version'} > $before_merge->{'version'},
    'relay merges disk ids into existing entries and commits'
) or say $out;
ok( !(  grep { !$ARG->{'disks'}{$disk} || !$ARG->{'disks'}{$disk2} }
        values $shared_map->{'nodes'}->%*
    ),
    'every merged entry names both disks'
);
( $rc, $out )
    = cli( ['vp'], 'relay', 'second', 'shared', '-root-key', $root_key );
( my $after_repeat, undef ) = read_map( $holder{'shared'} );
ok( $rc == 0
        && $out !~ m|merged disk ids|
        && $after_repeat->{'version'} == $after_merge->{'version'},
    'an unchanged relay merge does not commit'
) or say $out;

( $rc, $out )
    = cli( ['vp'], 'holder-check', '-full', $holder{'second'},
    '-root-key', $root_key );
( $rc, $out )
    = cli( ['vp'], 'holder-drain', $disk, 'shared', '-root-key', $root_key );
ok( $rc == 0 && $out =~ m|dropped 0 nodes| && $out =~ m|untagged 1 nodes|,
    'draining one of two disks only removes its tags' )
    or say $out;
( undef, $shared_map ) = read_map( $holder{'shared'} );
ok( !(  grep { $ARG->{'disks'}{$disk} || !$ARG->{'disks'}{$disk2} }
        values $shared_map->{'nodes'}->%*
        )
    && exists $shared_map->{'trees'}{'t'},
    'the shared entries and tree stay live for the other disk'
);
( $rc, $out ) = cli(
    ['vp'],      'seal-recover',
    '-root-key', $root_key,
    '-from',     $holder{'shared'},
    '-tree',     't',
    "$base/recovered"
);
ok( $rc == 0 && read_file("$base/recovered/file") eq "shared content\n",
    'the other disk\'s entries still recover' )
    or say $out;

( $rc, $out )
    = cli( ['vp'], 'holder-prune', 'shared', '-root-key',
    $root_key, '-dry-run' );
ok( $rc == 0 && $out =~ m|would drop 0 nodes| && $out =~ m|kept 1 nodes|,
    'prune keeps entries live on an attached disk' )
    or say $out;

my @legacy_addresses = sort keys $legacy_map->{'nodes'}->%*;
foreach my $address (@legacy_addresses) {
    ( $rc, $out )
        = cli( [], 'release', $disk2, $address, '-force',
        '-reason', 'prune test' );
}
( $rc, $out )
    = cli( ['vp'], 'holder-prune', 'legacy', '-root-key',
    $root_key, '-dry-run' );
ok( $rc == 0
        && $out =~ m|would drop 0 nodes|
        && $out =~ m|kept 1 nodes without disk ids|,
    'legacy orphans stay without -legacy'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-prune', 'legacy', '-root-key',
    $root_key, '-legacy', '-dry-run' );
ok( $rc == 0
        && $out =~ m|would drop 1 nodes|
        && $out =~ m|would drop \Q$legacy_addresses[0]\E|,
    'a legacy orphan dry run prints the addresses it would drop'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-prune', 'legacy', '-root-key',
    $root_key, '-legacy' );
( undef, $legacy_map ) = read_map( $holder{'legacy'} );
ok( $rc == 0
        && $out =~ m|dropped 1 nodes|
        && !keys $legacy_map->{'nodes'}->%*,
    'prune drops confirmed legacy orphans'
) or say $out;

my @shared_addresses = sort keys $shared_map->{'nodes'}->%*;
## the first disk still lists them too : prune must see both stop ##
foreach my $d ( $disk, $disk2 ) {
    ( $rc, $out ) = cli( [], 'tree-drop', $d, 't' );
}
foreach my $address (@shared_addresses) {
    foreach my $d ( $disk, $disk2 ) {
        ( $rc, $out )
            = cli( [], 'release', $d, $address, '-force',
            '-reason', 'prune test' );
    }
}
( $rc, $out ) = cli( [], 'detach', $disk2 );
( $rc, $out )
    = cli( ['vp'], 'holder-prune', 'shared', '-root-key',
    $root_key, '-dry-run' );
ok( $rc == 0 && $out =~ m|would drop 0 nodes| && $out =~ m|kept 1 nodes|,
    'prune keeps stale tags whose disk is detached' )
    or say $out;
( $rc, $out ) = cli( [], 'attach', $disk2 );
( $rc, $out )
    = cli( ['vp'], 'holder-prune', 'shared', '-root-key',
    $root_key, '-dry-run' );
( undef, my $after_dry ) = read_map( $holder{'shared'} );
ok( $rc == 0
        && $out =~ m|would drop 1 nodes|
        && keys $after_dry->{'nodes'}->%* == 1,
    'a tagged orphan dry run changes nothing'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-prune', 'shared', '-root-key', $root_key );
( undef, $shared_map ) = read_map( $holder{'shared'} );
ok( $rc == 0
        && $out =~ m|dropped 1 nodes|
        && !keys $shared_map->{'nodes'}->%*,
    'prune drops entries after all their disks stop listing them'
) or say $out;

{
    require Fcntl;
    open( my $lock, '>>', "$hdir/holders.lock" ) or die;
    flock( $lock, Fcntl::LOCK_EX() )             or die;
    ( $rc, $out )
        = cli( ['vp'], 'holder-prune', 'shared', '-root-key', $root_key );
    ok( $rc != 0 && $out =~ m|another n7fs command is writing|,
        'holder-prune takes the holder-writer lock'
    ) or say $out;
    close $lock;
}

done();

#,,,.,,,,,,.,,,,,,,,.,.,.,,..,,,,,,..,...,,,.,..,,...,...,..,,,,.,,.,,...,,..,
#W5WNTAVPDQYXOZ3R373XJG7C2YJILKDWCLVJGIBC6NILBEJ5AUP6BVKA6JYBWTHYW3SKWGEM3ESSM
#\\\|L6CVESGCTH6VGDRVGCNMCHOSHIXJZNPAKYPATWAFII5C7VVEJCH \ / AMOS7 \ YOURUM ::
#\[7]U3VPK6RLO7HYZIDM7EUTOE7U63YCDTKFGDMQPL2GYQQ7MXCSMMAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
