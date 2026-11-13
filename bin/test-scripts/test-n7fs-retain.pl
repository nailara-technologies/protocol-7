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
use AMOS7::N7FS::Placement;
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
( undef, my $referenced_map ) = read_map();
ok( exists $referenced_map->{'nodes'}{$unique_file},
    'an expired tree file stays while its import reference remains' );
( $rc, $out )
    = cli( [], 'release', $disk, $unique_file, '-force',
    '-reason', 'retain test' );
( $rc, $out )
    = cli( ['vp'], 'holder-prune', 'main', '-root-key', $root_key );
ok( $rc == 0 && $out =~ m|dropped 1 nodes|,
    'an explicitly released expired file is pruned before repack' )
    or say $out;
( my $before_corrupt_head, undef ) = read_map();
{
    no warnings qw| redefine |;
    local *AMOS7::N7FS::Seal::holder_read_range = sub {
        my ( undef, $name ) = @ARG;
        my $bytes = AMOS7::N7FS::Holder::holder_read_range(@ARG);
        substr( $bytes, 0, 1 ) = chr( ord( substr( $bytes, 0, 1 ) ) ^ 1 )
            if $name ne $old_pack;
        return $bytes;
    };
    eval {
        AMOS7::N7FS::Seal::repack_packs(
            qw| root |      => open_root(),
            qw| holder |    => $holder,
            qw| host_dir |  => $hdir,
            qw| signer |    => key_file_signer("$hdir/host.key"),
            qw| grace |     => 0,
            qw| threshold | => 0,
        );
    };
}
my $corrupt_error = $EVAL_ERROR;
( my $after_corrupt_head, my $after_corrupt_map ) = read_map();
ok( $corrupt_error =~ m|moved pack entry checksum does not match|
        && $after_corrupt_head->{'version'}
        == $before_corrupt_head->{'version'}
        && $after_corrupt_map->{'nodes'}{$shared}{'blob'} eq $old_pack,
    'a corrupted moved entry refuses before the map commit'
) or say $corrupt_error;
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
    = cli( ['vp'], 'holder-gc', $holder, '-root-key', $root_key,
    '-delete', '-grace', '0' );
ok( $rc == 0 && -f "$sub/$old_pack",
    'plain gc keeps the superseded pack without a covering receipt' )
    or say $out;
( $rc, $out ) = cli(
    ['vp'],    'repack', $disk, '-root-key',
    $root_key, '-grace', '0',   '-threshold',
    '0'
);
ok( $rc == 0 && $out =~ m|repacked 0 packs| && -f "$sub/$old_pack",
    'a repack rerun after the crash leaves the protected old pack alone'
) or say $out;
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
    'released unique nodes are garbage while shared nodes stay mapped'
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

( $rc, $out )
    = cli( ['vp'], 'holder-check', '-full', $holder, '-root-key', $root_key );
die $out if $rc;
my $receipt_path = AMOS7::N7FS::Placement::_receipt_path( $hdir, $holder,
    open_root()->{'root_id'} );
my $receipt_before = read_file($receipt_path);
( my $authenticated_head, my $authenticated_map ) = read_map();
foreach my $case (
    [   'manifest chunk',
        $authenticated_map->{'trees'}{'snap.current'}{'chunks'}[0]{'blob'}
    ],
    [   'manifest index',
        $authenticated_map->{'trees'}{'snap.current'}{'index'}{'blob'}
    ],
    [   'map shard', ( values $authenticated_map->{'_shards'}->%* )[0]{'blob'}
    ],
    [ 'map root', $authenticated_head->{'map'} ],
) {
    my ( $kind, $name ) = @{$case};
    my $good = read_file("$sub/$name");
    substr( $good, 20, 1 ) = chr( ord( substr( $good, 20, 1 ) ) ^ 1 );
    write_file( "$sub/$name", $good );
    ( $rc, $out )
        = cli( ['vp'], 'holder-check', '-full', $holder,
        '-root-key', $root_key );
    ok( $rc != 0 && read_file($receipt_path) eq $receipt_before,
        "a damaged $kind produces no full receipt" )
        or say $out;
    substr( $good, 20, 1 ) = chr( ord( substr( $good, 20, 1 ) ) ^ 1 );
    write_file( "$sub/$name", $good );
}

foreach my $fault (qw| repack:before-commit repack:after-receipt |) {
    $box  = sandbox();
    $base = $box->{'base'};
    ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
    $vdir                 = "$base/vault";
    $holder               = "$base/holder";
    $ENV{'N7FS_HOST_DIR'} = $hdir;
    vault_init( $vdir, 'vp', undef, t => 1, m => 1024, p => 1 );
    write_file( "$base/root-pass", "vp\n" );
    ( $rc, $out ) = cli( [], 'keygen', "$hdir/host.key" );
    ( $rc, $out ) = cli( [], 'keygen', "$hdir/parent.key" );
    ( $rc, $out ) = cli( [], 'pubkey', "$hdir/parent.key" );
    write_file( "$hdir/trusted-parents", $out );
    ( $rc, $out ) = cli( ['vp'], 'root', 'init', $root_key );
    ( $rc, $out )
        = cli( ['vp'], 'holder', 'add', 'main', $holder, '-domain',
        'sandbox' );
    ( $rc, $out ) = cli( [], 'init', '-name', $fault, '-intent', 'sandbox' );
    ($disk)
        = grep { !m|^\.| } do { opendir( my $d, $root ) or die; readdir $d };
    ( $rc, $out ) = cli( [], 'attach', $disk );
    import_tree(
        'snap.old', $clock - 20 * $y4,
        'unique' => "old unique\n",
        'shared' => "shared\n"
    );
    import_tree( 'snap.current', $clock, 'shared' => "shared\n" );
    ( $rc, $out )
        = cli( ['vp'], 'seal', $disk, '-root-key', $root_key,
        '-out', $holder, '-all-trees' );
    ( $rc, $out )
        = cli( ['vp'], 'retain-set', $disk, '-root-key', $root_key,
        'snap.', '1Y4' );
    ( $rc, $out )
        = cli( ['vp'], 'retain', $disk, '-root-key', $root_key,
        '-grace', '0Y3' );
    AMOS7::N7FS::Seal::unmap_nodes(
        qw| root |      => open_root(),
        qw| holder |    => $holder,
        qw| addresses | => [$unique_file],
    );
    ( my $fault_head_before, my $fault_map_before ) = read_map();
    my $crash_pack = $fault_map_before->{'nodes'}{$shared}{'blob'};
    $sub = holder_sub($holder);
    {
        local $ENV{'N7FS_TEST_FAULT'} = $fault;
        ( $rc, $out ) = cli(
            ['vp'],    'repack', $disk, '-root-key',
            $root_key, '-grace', '0Y3', '-threshold',
            '0'
        );
    }
    ok( $rc != 0 && $out =~ m|injected fault \Q$fault\E|,
        "$fault stops repack at the requested point"
    ) or say $out;
    if ( $fault eq qw| repack:before-commit | ) {
        ( my $fault_head_after, my $fault_map_after ) = read_map();
        ok( $fault_head_after->{'version'} == $fault_head_before->{'version'}
                && $fault_map_after->{'nodes'}{$shared}{'blob'} eq
                $crash_pack,
            'a crash before commit leaves the previous head authoritative'
        );
        ( $rc, $out ) = cli(
            ['vp'],    'repack', $disk, '-root-key',
            $root_key, '-grace', '0Y3', '-threshold',
            '0'
        );
    } else {
        ok( -f "$sub/$crash_pack",
            'a crash after the receipt leaves the superseded pack in place' );
        ( $rc, $out ) = cli(
            ['vp'],    'holder-gc', $holder,  '-root-key',
            $root_key, '-delete',   '-grace', '0Y3'
        );
    }
    ok( $rc == 0 && !-f "$sub/$crash_pack",
        "recovery after $fault releases only the verified old pack" )
        or say $out;
    ( $rc, $out ) = cli(
        ['vp'],      'seal-recover',
        '-root-key', $root_key,
        '-from',     $holder,
        '-tree',     'snap.current',
        "$base/recovered"
    );
    ok( $rc == 0 && read_file("$base/recovered/shared") eq "shared\n",
        "restore works after recovery from $fault" )
        or say $out;
}

## r1, r2 and r8a : detached disks and split holder settings stay safe ##
{
    $box  = sandbox();
    $base = $box->{'base'};
    ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
    $vdir                 = "$base/vault";
    $holder               = "$base/a-hub";
    $ENV{'N7FS_HOST_DIR'} = $hdir;
    vault_init( $vdir, 'vp', undef, t => 1, m => 1024, p => 1 );
    write_file( "$base/root-pass", "vp\n" );
    ( $rc, $out ) = cli( [], 'keygen', "$hdir/host.key" );
    ( $rc, $out ) = cli( [], 'keygen', "$hdir/parent.key" );
    ( $rc, $out ) = cli( [], 'pubkey', "$hdir/parent.key" );
    write_file( "$hdir/trusted-parents", $out );
    ( $rc, $out ) = cli( ['vp'], 'root', 'init', $root_key );
    my %holders = ( 'a-hub' => "$base/a-hub", 'b-far' => "$base/b-far" );

    foreach my $name ( sort keys %holders ) {
        ( $rc, $out )
            = cli( ['vp'], 'holder', 'add', $name, $holders{$name},
            '-domain', "dom-$name" );
    }

    ( $rc, $out )
        = cli( [], 'init', '-name', 'disk-a', '-intent', 'sandbox' );
    my ($disk_a)
        = grep { !m|^\.| } do { opendir( my $d, $root ) or die; readdir $d };
    ( $rc, $out ) = cli( [], 'attach', $disk_a );
    $disk = $disk_a;
    my $shared = "the same bytes on both disks\n";
    import_tree(
        'snap.old', $clock - 20 * $y4,
        'shared' => $shared,
        'old'    => "old unique\n"
    );
    import_tree( 'snap.pinned', $clock - 19 * $y4, 'pinned' => "pinned\n" );
    import_tree( 'snap.new',    $clock,            'new' => "new state\n" );
    ( $rc, $out )
        = cli( [], 'init', '-name', 'disk-b', '-intent', 'sandbox' );
    my ($disk_b)
        = grep { !m|^\.| and $ARG ne $disk_a }
        do { opendir( my $d, $root ) or die; readdir $d };
    ( $rc, $out ) = cli( [], 'attach', $disk_b );
    $disk = $disk_b;
    import_tree( 'docs.b1', $clock, 'copy' => $shared );

    my $id_a = disk_read_id( qw| root | => $root, qw| disk | => $disk_a );
    my $id_b = disk_read_id( qw| root | => $root, qw| disk | => $disk_b );
    my %docs_files = map { $ARG => TRUE } AMOS7::N7FS::Seal::_manifest_files(
        $id_b,
        AMOS7::N7FS::Journal::journal_replay($id_b)
            ->{'trees'}{'docs.b1'}{'manifest'}
    );
    my ($shared_address)
        = grep { $docs_files{$ARG} } AMOS7::N7FS::Seal::_manifest_files(
        $id_a,
        AMOS7::N7FS::Journal::journal_replay($id_a)
            ->{'trees'}{'snap.old'}{'manifest'}
        );

    foreach my $name ( sort keys %holders ) {
        ( $rc, $out )
            = cli( ['vp'], 'seal', $disk_a, '-root-key', $root_key,
            '-out', $holders{$name}, '-all-trees' );
        ok( $rc == 0, "disk a seals to $name with tree disk ids" )
            or say $out;
    }
    ( $rc, $out )
        = cli( ['vp'], 'seal', $disk_b, '-root-key', $root_key,
        '-out', $holders{'a-hub'}, '-all-trees' );
    ok( $rc == 0, 'disk b seals its tree to the first holder' ) or say $out;
    ( $rc, $out ) = cli( [], 'detach', $disk_b );

    ( $rc, $out )
        = cli( ['vp'], 'retain', $disk_a, '-root-key', $root_key,
        '-grace', '0Y3' );
    $holder = $holders{'a-hub'};
    ( undef, my $detached_map ) = read_map();
    ok( $rc == 0
            && exists $detached_map->{'trees'}{'docs.b1'}
            && exists $detached_map->{'trees'}{'snap.old'},
        'retain without a rule drops nothing of a detached disk'
    ) or say $out;
    ok( $detached_map->{'trees'}{'docs.b1'}{'disks'}{$disk_b},
        'the detached tree record names its owning disk'
    );

    ( $rc, $out )
        = cli( ['vp'], 'retain-set', $disk_a, '-root-key', $root_key,
        'snap.', '1Y4' );
    ok( $rc == 0, 'the initial rule reaches both holders' ) or say $out;
    rename $holders{'a-hub'}, "$holders{'a-hub'}.away" or die;
    ( $rc, $out ) = cli(
        ['vp'],    'tree-pin', $disk_a, '-root-key',
        $root_key, 'snap.pinned'
    );
    ok( $rc != 0 && $out =~ m|did not reach holders : a-hub|,
        'a pin written with one holder away fails and names that holder'
    ) or say $out;
    rename "$holders{'a-hub'}.away", $holders{'a-hub'} or die;
    ( $rc, $out )
        = cli( ['vp'], 'retain-show', $disk_a, '-root-key', $root_key );
    ok( $rc == 0 && $out =~ m|pinned snap.pinned|,
        'retain-show merges a pin present on any holder'
    ) or say $out;
    ( $rc, $out )
        = cli( ['vp'], 'retain', $disk_a, '-root-key', $root_key,
        '-dry-run' );
    ok( $rc == 0
            && $out =~ m|keep snap.pinned \[ pinned|
            && $out =~ m|drop snap.old|,
        'the offline pin protects the tree when the first holder returns'
    ) or say $out;

    rename $holders{'a-hub'}, "$holders{'a-hub'}.away" or die;
    ( $rc, $out )
        = cli( ['vp'], 'retain-set', $disk_a, '-root-key', $root_key,
        'snap.', '2Y4' );
    rename "$holders{'a-hub'}.away", $holders{'a-hub'} or die;
    ( $rc, $out )
        = cli( ['vp'], 'retain', $disk_a, '-root-key', $root_key,
        '-dry-run' );
    ok( $rc != 0
            && $out =~ m|retention rules differ for snap.|
            && $out =~ m|2Y4|,
        'different rules on reachable holders refuse retention'
    ) or say $out;
    ( $rc, $out )
        = cli( ['vp'], 'retain-set', $disk_a, '-root-key', $root_key,
        'snap.', '1Y4' );
    ok( $rc == 0, 'retain-set repairs the differing rules' ) or say $out;

    rename $holders{'a-hub'}, "$holders{'a-hub'}.away" or die;
    ( $rc, $out )
        = cli( ['vp'], 'retain-clear', $disk_a, '-root-key',
        $root_key, 'snap.' );
    rename "$holders{'a-hub'}.away", $holders{'a-hub'} or die;
    ( $rc, $out )
        = cli( ['vp'], 'retain', $disk_a, '-root-key', $root_key,
        '-dry-run' );
    ok( $rc != 0 && $out =~ m|b-far has no rule|,
        'a rule missing on one reachable holder refuses retention' )
        or say $out;
    ( $rc, $out )
        = cli( ['vp'], 'retain-set', $disk_a, '-root-key', $root_key,
        'snap.', '1Y4' );
    ok( $rc == 0, 'retain-set repairs a rule missing on one holder' )
        or say $out;

    rename $holders{'a-hub'}, "$holders{'a-hub'}.away" or die;
    rename $holders{'b-far'}, "$holders{'b-far'}.away" or die;
    ( $rc, $out )
        = cli( ['vp'], 'retain', $disk_a, '-root-key', $root_key,
        '-dry-run' );
    ok( $rc != 0 && $out =~ m|retain needs a registered holder|,
        'retain refuses when no holder is reachable'
    ) or say $out;
    rename "$holders{'a-hub'}.away", $holders{'a-hub'} or die;
    rename "$holders{'b-far'}.away", $holders{'b-far'} or die;

    ( $rc, $out )
        = cli( ['vp'], 'retain', $disk_a, '-root-key', $root_key,
        '-grace', '0Y3' );
    ok( $rc == 0, 'merged retention completes on both holders' ) or say $out;
    foreach my $name ( sort keys %holders ) {
        $holder = $holders{$name};
        ( undef, my $map ) = read_map();
        ok( exists $map->{'trees'}{'snap.pinned'}
                && exists $map->{'trees'}{'snap.new'}
                && !exists $map->{'trees'}{'snap.old'},
            "$name keeps the pin and drops only the expired tree"
        );
        ok( exists $map->{'nodes'}{$shared_address},
            "$name keeps the detached disk's shared node"
        );
    }
    $holder = $holders{'a-hub'};
    ( undef, $detached_map ) = read_map();
    ok( exists $detached_map->{'trees'}{'docs.b1'},
        'the detached disk tree survives the real retention run' );
}

done();

#,,..,.,.,,,.,,,,,.,,,,..,,,.,.,.,,.,,.,.,,..,..,,...,...,.,,,,,.,..,,,,,,...,
#QPZYBY7NSFRUBGUIFPQ67XSLNFREA6YSGQOVFMZYPCYWXEORGZXEHMOHJNHNZYFZ4FPAF6YRYEFV2
#\\\|QXQ7XBHZDTYUIMAXJUBQRTDD6YIH7J7UTPLRNWNKNBXWGE75NLE \ / AMOS7 \ YOURUM ::
#\[7]NUNKHPFLCZF7VGBQO7GJ2PAJS67NFD3GQVTGNA4RQ5UXRAGTYKAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
