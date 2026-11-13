#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## retention ladders, pins and byte-preserving pack compaction.

use constant TRUE  => 5;
use constant FALSE => 0;

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use AMOS7::Vault       qw| vault_init |;
use AMOS7::NTIME       qw| y_level_ntime |;
use AMOS7::N7FS        qw| make_dirs read_file |;
use AMOS7::N7FS::Disk  qw| disk_read_id |;
use AMOS7::N7FS::Store qw| assimilate |;
use AMOS7::N7FS::Sign  qw| key_file_signer |;
use AMOS7::N7FS::Keys;
use AMOS7::N7FS::Seal;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

my $box  = sandbox();
my $base = $box->{'base'};
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
my $vdir     = "$base/vault";
my $root_key = 'vault:main';
my $holder   = "$base/holder";
$ENV{'N7FS_HOST_DIR'}       = $hdir;
$ENV{'N7FS_TEST_PACK_SIZE'} = 1024 * 1024;
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

sub open_root {
    open( my $fh, '<:raw', "$base/root-pass" ) or die;
    return AMOS7::N7FS::Keys::root_open(
        qw| path |      => $root_key,
        qw| pass_fd |   => fileno($fh),
        qw| vault_dir | => $vdir,
    );
}

sub read_map {
    my ( undef, $head, $map )
        = AMOS7::N7FS::Seal::_context( open_root(), $holder, TRUE );
    return ( $head, $map );
}

write_file( "$base/root-pass", "vp\n" );
my $y4    = y_level_ntime(4);
my $now   = int( 1000 * $y4 );
my %trees = (
    'snap.current' => $now,
    'snap.a-old'   => $now - $y4 - 10,
    'snap.a-new'   => $now - $y4 + 1,
    'snap.b'       => $now - 2 * $y4 + 1,
    'snap.c'       => $now - 3 * $y4 + 1,
    'snap.coarse'  => $now - 20 * $y4,
    'snap.old'     => $now - 100 * $y4,
);
$trees{$ARG} = int $trees{$ARG} for keys %trees;
my $plan = AMOS7::N7FS::Seal::retention_plan(
    qw| trees | => \%trees,
    qw| rules | => { 'snap.'  => '3Y4 2Y3' },
    qw| pins |  => { 'snap.c' => 1 },
    qw| now |   => $now,
);
my %decision = map { $ARG->{'tree'} => $ARG } @{$plan};
ok(
    (   !grep { not $decision{$ARG}{'keep'} }
            qw| snap.current snap.a-new snap.b snap.coarse snap.c |
        )
        && !$decision{'snap.a-old'}{'keep'}
        && !$decision{'snap.old'}{'keep'},
    'the ladder keeps newest trees in newest buckets and honors a pin'
);
ok( $decision{'snap.a-new'}{'reason'} eq '3 Y4'
        && $decision{'snap.coarse'}{'reason'} eq '2 Y3'
        && $decision{'snap.current'}{'reason'} =~ m|current|,
    'keep reasons name the term or the current fine bucket'
);

## a tree owned by a longer prefix never takes a bucket of the shorter one ##
{
    my $p = AMOS7::N7FS::Seal::retention_plan(
        qw| trees | => {
            'snap.p'   => int( $now - 2 * $y4 + 1 ),
            'snap.x.q' => int( $now - $y4 + 1 ),
        },
        qw| rules | => { 'snap.' => '1Y4', 'snap.x.' => '5Y4' },
        qw| now |   => $now,
    );
    my %d = map { $ARG->{'tree'} => $ARG } @{$p};
    ok( $d{'snap.p'}{'keep'} && $d{'snap.x.q'}{'keep'},
        'nested prefixes keep separate ladders'
    );
}

my ( $rc, $out ) = cli( [], 'keygen', "$hdir/host.key" );
( $rc, $out ) = cli( [], 'keygen', "$hdir/parent.key" );
( $rc, $out ) = cli( [], 'pubkey', "$hdir/parent.key" );
write_file( "$hdir/trusted-parents", $out );
( $rc, $out ) = cli( [], 'init', '-name', 'retain', '-intent', 'sandbox' );
my ($disk)
    = grep { !m|^\.| } do { opendir( my $d, $root ) or die; readdir $d };
( $rc, $out ) = cli( [],     'attach', $disk );
( $rc, $out ) = cli( ['vp'], 'root',   'init', $root_key );
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'main', $holder, '-domain', 'sandbox' );
ok( $rc == 0, 'sandbox disk, root and holder are ready' ) or say $out;

sub import_tree {
    my ( $name, $time, %file ) = @ARG;
    my $dir = "$src/$name";
    make_dirs($dir);
    write_file( "$dir/$ARG", $file{$ARG} ) for keys %file;
    local $AMOS7::N7FS::CLOCK = sub { return int $time };
    return assimilate(
        qw| root |           => $root,
        qw| host_dir |       => $hdir,
        qw| disk |           => $disk,
        qw| host |           => key_file_signer("$hdir/host.key"),
        qw| paths |          => [$dir],
        qw| tree |           => $name,
        qw| remove |         => 0,
        qw| category_rules | => [],
        qw| protect |        => [],
    );
}

my $clock = AMOS7::N7FS::ntime_now();
import_tree(
    'snap.old', $clock - 20 * $y4,
    'unique' => "old unique\n",
    'shared' => "shared\n"
);
import_tree( 'snap.pinned',  $clock - 19 * $y4, 'pinned' => "pinned\n" );
import_tree( 'snap.current', $clock,            'shared' => "shared\n" );
( $rc, $out )
    = cli( ['vp'], 'seal', $disk, '-root-key', $root_key,
    '-out', $holder, '-all-trees' );
ok( $rc == 0, 'three synthetic-age trees are sealed' ) or say $out;
( undef, my $before_map ) = read_map();
my $id         = disk_read_id( qw| root | => $root, qw| disk | => $disk );
my $old_unique = $before_map->{'trees'}{'snap.old'}{'manifest'};
my @old_files  = AMOS7::N7FS::Seal::_manifest_files( $id,
    $before_map->{'trees'}{'snap.old'}{'manifest'} );
my @current_files = AMOS7::N7FS::Seal::_manifest_files( $id,
    $before_map->{'trees'}{'snap.current'}{'manifest'} );
my %current       = map  { $ARG => 1 } @current_files;
my ($shared)      = grep { $current{$ARG} } @old_files;
my ($unique_file) = grep { not $current{$ARG} } @old_files;
my ($old_pack)    = map  { $before_map->{'nodes'}{$ARG}{'blob'} }
    grep { defined $before_map->{'nodes'}{$ARG}{'node'} }
    keys $before_map->{'nodes'}->%*;
my $sub       = holder_sub($holder);
my $old_size  = -s "$sub/$old_pack";
my $old_bytes = read_file("$sub/$old_pack");
ok( defined $old_pack, 'the fixture has a shared pack to compact' );

( $rc, $out )
    = cli( ['vp'], 'retain-set', $disk, '-root-key', $root_key,
    'snap.', '1Y4' );
ok( $rc == 0, 'retain-set stores the ladder' ) or say $out;
( $rc, $out )
    = cli( ['vp'], 'tree-pin', $disk, '-root-key', $root_key, 'snap.pinned' );
( $rc, $out ) = cli( ['vp'], 'retain-show', $disk, '-root-key', $root_key );
ok( $rc == 0 && $out =~ m|snap. 1Y4| && $out =~ m|pinned snap.pinned|,
    'retain-show reads rules and pins from the sealed root'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'retain', $disk, '-root-key', $root_key, '-dry-run' );
ok( $rc == 0
        && $out =~ m|drop snap.old|
        && $out =~ m|keep snap.pinned \[ pinned|,
    'the retention dry run prints drop and pin reasons without dropping'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'retain', $disk, '-root-key', $root_key, '-grace', '0' );
ok( $rc == 0, 'retention, prune and gc complete' ) or say $out;
{
    local $ENV{'N7FS_TEST_FAULT'} = 'repack:after-commit';
    ( $rc, $out ) = cli(
        ['vp'],    'repack', $disk, '-root-key',
        $root_key, '-grace', '0',   '-threshold',
        '0'
    );
}
ok( $rc != 0 && -f "$sub/$old_pack",
    'an interruption before the fresh receipt never releases the old pack' );
( $rc, $out )
    = cli( ['vp'], 'holder-check', '-full', $holder, '-root-key', $root_key );
ok( $rc == 0 && -f "$sub/$old_pack",
    'a fresh full receipt covers the new pack before release' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-gc', $holder, '-root-key', $root_key,
    '-delete', '-grace', '0' );
ok( $rc == 0 && !-f "$sub/$old_pack",
    'gc releases the old pack only after that receipt' )
    or say $out;
( my $after_head, my $after_map ) = read_map();
ok( exists $after_map->{'trees'}{'snap.pinned'}
        && exists $after_map->{'trees'}{'snap.current'}
        && !exists $after_map->{'trees'}{'snap.old'},
    'the pinned and current trees survive while the old tree is dropped'
);
ok( !exists $after_map->{'nodes'}{$old_unique}
        && !exists $after_map->{'nodes'}{$unique_file}
        && exists $after_map->{'nodes'}{$shared},
    'dropped unique nodes are garbage while shared nodes stay mapped'
    )
    or say join ' ', 'map flags:',
    exists( $after_map->{'nodes'}{$old_unique} ),
    exists( $after_map->{'nodes'}{$unique_file} ),
    exists( $after_map->{'nodes'}{$shared} );
my $new_pack  = $after_map->{'nodes'}{$shared}{'blob'};
my $new_bytes = read_file("$sub/$new_pack");
my $entry     = $after_map->{'nodes'}{$shared};
ok( $new_pack ne $old_pack && length($new_bytes) < $old_size,
    'repack writes a smaller live pack' )
    or say $out;
ok( substr( $new_bytes, $entry->{'offset'}, $entry->{'length'} ) eq substr(
        $old_bytes, $before_map->{'nodes'}{$shared}{'offset'},
        $entry->{'length'}
    ),
    'the sealed entry bytes move unchanged [ no nonce reuse ]'
);

( $rc, $out ) = cli(
    ['vp'],  'seal-recover', '-root-key', $root_key,
    '-from', $holder,        '-tree',     'snap.current',
    "$base/recovered"
);
ok( $rc == 0 && read_file("$base/recovered/shared") eq "shared\n",
    'restore verifies after repack' )
    or say $out;
( my $under_before, undef ) = read_map();
( $rc, $out ) = cli( ['vp'], 'repack', $disk, '-root-key', $root_key );
( my $under_after, undef ) = read_map();
ok( $rc == 0
        && $out =~ m|repacked 0 packs|
        && $under_after->{'version'} == $under_before->{'version'},
    'a pack under the dead-byte threshold is not rewritten'
) or say $out;

( $rc, $out )
    = cli( ['vp'], 'retain-clear', $disk, '-root-key', $root_key, 'snap.' );
( $rc, $out )
    = cli( ['vp'], 'tree-unpin', $disk, '-root-key', $root_key,
    'snap.pinned' );
( $rc, $out ) = cli( ['vp'], 'retain-show', $disk, '-root-key', $root_key );
ok( $rc == 0 && $out !~ m|snap|,
    'retain-clear and tree-unpin remove the sealed settings' )
    or say $out;

done();

#,,..,,..,.,.,.,,,..,,,,.,,,.,,..,,..,.,.,,..,..,,...,...,.,,,...,,..,...,,,,,
#7U3TMJHTYSFZJ4ZNATEYBLYNQGKUCY2UCSAYMOTLZFC3PABUIUGDG3PEJ7G76SFZ3FG5UATOEM6BG
#\\\|AXWVAF6THEHWXFXL26K6XBM52Z5MZ2644LGO2KMUSOYX4ROZL65 \ / AMOS7 \ YOURUM ::
#\[7]KUHUD4K5X2RJ73Q5ESHYA3JDPBMJI2BVDP2XO2MIIBDJGPHY5WCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
