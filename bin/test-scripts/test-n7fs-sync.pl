#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## local union sync through the real CLI, plus direct fault injection.

use FindBin;

BEGIN {
    unshift @INC, "$FindBin::Bin/../../data/lib-path/pm";
    unshift @INC, $ENV{'N7FS_TEST_LIB'} if $ENV{'N7FS_TEST_LIB'};
}

use AMOS7::N7FS qw| read_file signed_record_pack signed_record_parse make_dirs
    remove_tree ntime_now ntime14 |;
use AMOS7::N7FS::Sign    qw| key_file_write key_file_signer |;
use AMOS7::N7FS::Disk    qw| disk_init disk_attach disk_read_id |;
use AMOS7::N7FS::Store   qw| reference_entries |;
use AMOS7::N7FS::Journal qw| journal_replay |;
use AMOS7::N7FS::Sync    qw| store_sync |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

my $box = sandbox();
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
my $host = key_file_write("$hdir/host.key");
my %base = ( root => $root, host_dir => $hdir );
clock_real();

my $cli_epoch;

sub cli_n7fs {
    my @args = @ARG;
    my $out  = "$box->{'base'}/cli.stdout";
    my $err  = "$box->{'base'}/cli.stderr";
    my $pid  = fork // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDOUT, '>:raw', $out ) or exit 98;
        open( STDERR, '>:raw', $err ) or exit 98;
        if ( defined $cli_epoch ) {
            $0    = "$FindBin::Bin/../n7fs";
            @ARGV = ( '-root', $root, '-host-dir', $hdir, @args );
            my $ntime
                = int( $cli_epoch * $AMOS7::N7FS::Sum::EPOCH_DIVISOR ) + 4200;
            $AMOS7::N7FS::CLOCK = sub { return $ntime++ };
            $AMOS7::N7FS::FAULT = sub {
                die "injected sync crash\n"
                    if $ARG[0] eq $ENV{'N7FS_TEST_FAULT'};
                }
                if $ENV{'N7FS_TEST_FAULT'};
            do $0;
            die $EVAL_ERROR if $EVAL_ERROR;
            exit 0;
        }
        exec( $EXECUTABLE_NAME, "$FindBin::Bin/../n7fs", '-root', $root,
            '-host-dir', $hdir, @args )
            or exit 99;
    }
    waitpid $pid, 0;
    return ( $CHILD_ERROR >> 8, read_file($out), read_file($err) );
}

sub new_disk {
    my $name = shift;
    my $disk = disk_init(
        %base,
        parent => test_signer(),
        name   => $name,
        intent => 'local sync tests'
    );
    disk_attach( %base, disk => $disk, host => $host );
    return $disk;
}

my $a    = new_disk('sync-a');
my $b    = new_disk('sync-b');
my $c    = new_disk('sync-c');
my $tree = "$src/tree";
make_dirs("$tree/empty");
make_dirs("$tree/sub");
write_file( "$tree/sub/one", "one bytes\n" );
write_file( "$tree/sub/two", "two bytes\n" );
symlink 'sub/one', "$tree/link" or die "symlink : $OS_ERROR";
my $raw = "raw-\xFF-\x80";
write_file( "$tree/$raw", "raw name\n" );
my $incoming = write_file( "$src/pool-file", 'pool bytes' );
my ( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $a, '-tree', 'union', $tree );
ok( $rc == 0, 'source tree assimilates' ) or say $err;
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $a, '-incoming', $incoming );
ok( $rc == 0, 'source incoming reference assimilates' ) or say $err;
my $before_b = snapshot("$root/$b");
( $rc, $out, $err ) = cli_n7fs( 'sync', $a, $b, '-dry-run' );
ok( $rc == 0
        && $out =~ m|dry run : nothing was changed|
        && snap_equal( $before_b, snapshot("$root/$b") ),
    'dry run reports work and writes nothing'
) or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'sync', $a, $b );
ok( $rc == 0 && $out =~ m|references4| && $out =~ m|trees1|,
    'A to B imports references and the tree' )
    or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'verify', $b );
ok( $rc == 0, 'receiver verifies after sync' ) or say $err;
( $rc, $out, $err ) = cli_n7fs( 'status', $b );
ok( $rc == 0 && $out =~ m|incoming\s+1 references, 10 bytes|,
    'receiver status and incoming meta join work'
) or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'incoming', $b, 'list' );
ok( $rc == 0 && $out =~ m|incoming 1 references, 10 bytes|,
    'incoming list crosses with the reference'
);
( $rc, $out, $err ) = cli_n7fs( 'restore', $b, 'union', "$src/restored-b" );
ok( $rc == 0
        && read_file("$src/restored-b/sub/one") eq "one bytes\n"
        && readlink("$src/restored-b/link") eq 'sub/one'
        && read_file("$src/restored-b/$raw") eq "raw name\n",
    'receiver restores regular, symlink and raw-octet paths'
) or say $err;
my $a_seq = journal_replay( disk_read_id( %base, disk => $a ) )->{'seq'};
my $b_seq = journal_replay( disk_read_id( %base, disk => $b ) )->{'seq'};
( $rc, $out, $err ) = cli_n7fs( 'sync', $b, $a );
ok( $rc == 0
        && $out =~ m|no changes ; no journal entry|
        && journal_replay( disk_read_id( %base, disk => $a ) )->{'seq'}
        == $a_seq,
    'B to A suppresses receiver-origin echoes and writes no entry'
) or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'sync', $a, $b );
ok( $rc == 0
        && journal_replay( disk_read_id( %base, disk => $b ) )->{'seq'}
        == $b_seq,
    'third converged run writes no journal entry'
);
( $rc, $out, $err ) = cli_n7fs( 'sync', $b, $c );
( $rc, $out, $err ) = cli_n7fs( 'sync', $c, $a );
ok( $rc == 0 && $out =~ m|no changes ; no journal entry|,
    'A to B to C to A preserves first origins and suppresses the echo'
) or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'sync', $a, $c );
ok( $rc == 0 && $out =~ m|no changes ; no journal entry|,
    'the same first origin arriving from another source is not reapplied' )
    or say "$out$err";

my ($pool_ref)
    = grep { $ARG->{'holder'} eq $incoming }
    values journal_replay( disk_read_id( %base, disk => $b ) )
    ->{'references'}->%*;
( $rc, $out, $err ) = cli_n7fs( 'incoming', $b, 'tag', $incoming, 'default' );
( $rc, $out, $err ) = cli_n7fs( 'sync', $b, $a );
( $rc, $out, $err ) = cli_n7fs( 'sync', $a, $b );
ok( $rc == 0 && $out =~ m|no changes|,
    'pool tag on one side converges without another conflict' )
    or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'incoming', $a, 'done' );
ok( $rc == 0 && $out =~ m|empty|, 'pool leaves incoming on both disks' );

say ':: origin-matched drop and retained release';
my ($file_ref)
    = grep { $ARG->{'holder'} eq "$tree/sub/one" }
    reference_entries( %base, disk => $a, host => $host );
( $rc, $out, $err )
    = cli_n7fs( 'drop', $a, $file_ref->{'node'}, '-holder', "$tree/sub/one" );
ok( $rc == 0, 'source reference drops' ) or say $err;
( $rc, $out, $err ) = cli_n7fs( 'sync', $a, $b );
my ($b_file_ref)
    = grep { $ARG->{'holder'} eq "$tree/sub/one" }
    reference_entries( %base, disk => $b, host => $host );
ok( $rc == 0 && $b_file_ref->{'dropped'},
    'drop matches the original reference identity across translated paths' )
    or say "$out$err";
$b_seq = journal_replay( disk_read_id( %base, disk => $b ) )->{'seq'};
( $rc, $out, $err ) = cli_n7fs( 'sync', $b, $a );
ok( $rc == 0
        && journal_replay( disk_read_id( %base, disk => $b ) )->{'seq'}
        == $b_seq,
    'drop does not echo back or resurrect anything'
);
( $rc, $out, $err )
    = cli_n7fs( 'release', $a, $file_ref->{'node'}, '-force' );
ok( $rc == 0, 'source release journals after its reference drop' )
    or say $err;
( $rc, $out, $err ) = cli_n7fs( 'sync', $a, $b );
ok( $rc == 0 && -f "$root/$b/$file_ref->{'node'}/content",
    'journaled release is honored without reclaiming receiver bytes'
) or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'verify', $b );
ok( $rc == 0, 'retained release remains fully verifiable' ) or say $err;

say ':: unjournaled tombstone and a receiver-local live reference';
my $d     = new_disk('sync-d');
my $local = write_file( "$src/local-two", "two bytes\n" );
( $rc, $out, $err ) = cli_n7fs( 'assimilate', '-disk', $b, $local );
my ($two_a)
    = grep { $ARG->{'holder'} eq "$tree/sub/two" }
    reference_entries( %base, disk => $a, host => $host );
( $rc, $out, $err ) = cli_n7fs( 'release', $a, $two_a->{'node'}, '-force' );
ok( $rc == 0, 'second source release succeeds with no local references left' )
    or say $err;
( $rc, $out, $err ) = cli_n7fs( 'sync', $a, $b );
ok( $rc == 0 && $out =~ m|release retained .* live references|,
    'receiver-local reference keeps content live and is reported'
) or say "$out$err";
my ($two_b)
    = grep { $ARG->{'holder'} eq $local }
    reference_entries( %base, disk => $b, host => $host );
ok( !$two_b->{'dropped'}, 'the other-origin local reference stays live' );
my $unjournaled = write_file( "$src/unjournaled", 'not released' );
( $rc, $out, $err ) = cli_n7fs( 'assimilate', '-disk', $d, $unjournaled );
my ($uj_ref) = reference_entries( %base, disk => $d, host => $host );
my $uj_store = key_file_signer("$hdir/stores/$d.store.key");
my $uj_addr  = $uj_ref->{'node'};
my ( undef, $uj_amos, $uj_bmw ) = split m|/|, $uj_addr;
my $uj_nt = ntime14( ntime_now() );
make_dirs("$root/$d/.n7fs/tombstones");
write_file(
    "$root/$d/.n7fs/tombstones/$uj_nt.$uj_amos.$uj_bmw.tombstone",
    signed_record_pack(
        'tombstone',
        {   disk   => $d,
            addr   => $uj_addr,
            ntime  => $uj_nt,
            reason => 'unjournaled test tombstone',
        },
        $uj_store,
        3
    )
);
( $rc, $out, $err ) = cli_n7fs( 'sync', $d, $c );
my ($uj_c)
    = grep { $ARG->{'holder'} eq $unjournaled }
    reference_entries( %base, disk => $c, host => $host );
ok( $rc == 0 && !$uj_c->{'dropped'},
    'a tombstone without a source journal release is ignored' )
    or say "$out$err";

say ':: same disk, clone, rollback, rewrite and tamper refusal';
( $rc, $out, $err ) = cli_n7fs( 'sync', $a, $a );
ok( $rc != 0 && $err =~ m|same disk|, 'from equal to to refuses' );
my $clone = "$root/CLONEAA";
copy_tree( "$root/$d", $clone );
( $rc, $out, $err ) = cli_n7fs( 'sync', 'CLONEAA', $c );
ok( $rc != 0 && $err =~ m|directory name|,
    'a copied disk identity cannot masquerade as another disk' );
my $e             = new_disk('sync-e');
my $f             = new_disk('sync-f');
my $rollback_file = write_file( "$src/rollback", 'rollback' );
( $rc, $out, $err ) = cli_n7fs( 'assimilate', '-disk', $e, $rollback_file );
my $older = "$box->{'base'}/older-e";
copy_tree( "$root/$e", $older );
( $rc, $out, $err ) = cli_n7fs( 'sync', $e, $f );
my $rewrite_path  = ( glob "$root/$e/.n7fs/journal/*.journal" )[0];
my $rewrite_bytes = read_file($rewrite_path);
my $rewrite_payload
    = signed_record_parse( 'journal', $rewrite_bytes )->{'payload'};
$rewrite_payload->{'repaired'} = JSON::PP::true;
my $e_store = key_file_signer("$hdir/stores/$e.store.key");
chmod 0600, $rewrite_path;
write_file( $rewrite_path,
    signed_record_pack( 'journal', $rewrite_payload, $e_store, 3 ) );
( $rc, $out, $err ) = cli_n7fs( 'sync', $e, $f );
ok( $rc != 0 && $err =~ m|hash differs from cursor|,
    'a rewritten source entry is refused by the cursor hash'
) or say "$out$err";
write_file( $rewrite_path, $rewrite_bytes );
my $newer = "$box->{'base'}/newer-e";
copy_tree( "$root/$e", $newer );
my $rollback_extra = write_file( "$src/rollback-extra", 'newer' );
( $rc, $out, $err ) = cli_n7fs( 'assimilate', '-disk', $e, $rollback_extra );
remove_tree("$root/$e");
copy_tree( $older, "$root/$e" );
( $rc, $out, $err ) = cli_n7fs( 'sync', $e, $f );
ok( $rc != 0 && $err =~ m|rollback|,
    'a coherently rolled-back source is refused by the host witness' )
    or say "$out$err";
remove_tree("$root/$e");
copy_tree( $newer, "$root/$e" );

my $g           = new_disk('sync-g');
my $h           = new_disk('sync-h');
my $tamper_file = write_file( "$src/tamper", 'tamper' );
( $rc, $out, $err ) = cli_n7fs( 'assimilate', '-disk', $g, $tamper_file );
my $tamper_ref_path = ( glob "$root/$g/V*/*/*/references/*/*/*/addr" )[0];
my $tamper_bytes    = read_file($tamper_ref_path);
substr( $tamper_bytes, -1, 1 )
    = chr( ord( substr( $tamper_bytes, -1, 1 ) ) ^ 1 );
chmod 0600, $tamper_ref_path;
write_file( $tamper_ref_path, $tamper_bytes );
my $h_seq = journal_replay( disk_read_id( %base, disk => $h ) )->{'seq'};
( $rc, $out, $err ) = cli_n7fs( 'sync', $g, $h );
ok( $rc != 0
        && $err =~ m|signature does not verify|
        && journal_replay( disk_read_id( %base, disk => $h ) )->{'seq'}
        == $h_seq,
    'a forged source record refuses with nothing applied'
) or say "$out$err";
my $i            = new_disk('sync-i');
my $j            = new_disk('sync-j');
my $corrupt_file = write_file( "$src/corrupt", 'correct bytes' );
( $rc, $out, $err ) = cli_n7fs( 'assimilate', '-disk', $i, $corrupt_file );
my ($corrupt_ref) = reference_entries( %base, disk => $i, host => $host );
chmod 0600, "$root/$i/$corrupt_ref->{'node'}/content";
write_file( "$root/$i/$corrupt_ref->{'node'}/content", 'wrong bytes' );
( $rc, $out, $err ) = cli_n7fs( 'sync', $i, $j );
ok( $rc != 0
        && $err =~ m|content does not match|
        && journal_replay( disk_read_id( %base, disk => $j ) )->{'seq'} == 0,
    'corrupt source content is verified before receiver publication'
) or say "$out$err";

say ':: concurrent assignments, categories and tree names';
my $k      = new_disk('sync-k');
my $l      = new_disk('sync-l');
my $assign = write_file( "$src/assignment", 'assignment' );
( $rc, $out, $err ) = cli_n7fs( 'assimilate', '-disk', $k, $assign );
( $rc, $out, $err ) = cli_n7fs( 'category', $k, 'set', 'cat-a' );
( $rc, $out, $err ) = cli_n7fs( 'category', $k, 'set', 'cat-b' );
( $rc, $out, $err )
    = cli_n7fs( 'category', $k, 'set', 'strict', '-copies', 1 );
( $rc, $out, $err ) = cli_n7fs( 'sync', $k, $l );
my ($assign_ref) = reference_entries( %base, disk => $l, host => $host );
( $rc, $out, $err )
    = cli_n7fs( 'set-category', $k, $assign_ref->{'node'}, 'cat-a' );
( $rc, $out, $err )
    = cli_n7fs( 'set-category', $l, $assign_ref->{'node'}, 'cat-b' );
( $rc, $out, $err ) = cli_n7fs( 'sync', $k, $l );
ok( $rc != 0
        && $out
        =~ m|conflict assignment .* receiver \[ cat-b \] ; source \[ cat-a \]|,
    'concurrent assignment keeps the receiver and prints both values'
) or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'sync-conflicts', $l );
ok( $rc == 0 && $out =~ m|assignment .* receiver=cat-b source=cat-a|,
    'sync-conflicts lists the durable conflict' )
    or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'sync', $k, $l );
ok( $rc != 0 && $out =~ m|no changes|,
    'a no-change run still exits nonzero while a conflict remains' )
    or say "$out$err";
( $rc, $out, $err )
    = cli_n7fs( 'set-category', $l, $assign_ref->{'node'}, 'cat-a' );
( $rc, $out, $err ) = cli_n7fs( 'sync-conflicts', $l );
ok( $rc == 0 && $out =~ m|conflicts 0|,
    'an explicit set-category resolves the conflict' )
    or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'sync', $l, $k );
( $rc, $out, $err )
    = cli_n7fs( 'category', $k, 'show', $assign_ref->{'node'} );
ok( $rc == 0 && $out =~ m|cat-a|,
    'resolved assignment converges on the source' );
( $rc, $out, $err ) = cli_n7fs(
    'category', $k,     'set',       'strict',
    '-copies',  2,      '-priority', 4,
    '-want',    'left', '-replica',  'manifest'
);
( $rc, $out, $err ) = cli_n7fs(
    'category', $l,      'set',           'strict',
    '-copies',  5,       '-priority',     2,
    '-want',    'right', '-foreign-work', 'yes'
);
( $rc, $out, $err ) = cli_n7fs( 'sync',     $k, $l );
( $rc, $out, $err ) = cli_n7fs( 'category', $l, 'list' );
ok( $rc == 0
        && $out =~ m|strict local-encryption=none copies=5 priority=4|
        && $out =~ m|want=left,right foreign-work=no|,
    'concurrent category definitions use the strictest effective merge'
) or say "$out$err";
my $tree_a = "$src/name-a";
my $tree_b = "$src/name-b";
make_dirs($tree_a);
make_dirs($tree_b);
write_file( "$tree_a/file", 'tree a' );
write_file( "$tree_b/file", 'tree b' );
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $k, '-tree', 'same', $tree_a );
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $l, '-tree', 'same', $tree_b );
( $rc, $out, $err ) = cli_n7fs( 'sync', $k, $l );
ok( $rc != 0 && $out =~ m|conflict tree|,
    'same tree name from another origin conflicts without overwrite' )
    or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'tree-drop', $l, 'same' );
( $rc, $out, $err ) = cli_n7fs( 'sync',      $k, $l );
ok( $rc == 0 && $out =~ m|trees1|,
    'a tree conflict is re-evaluated and imports after the name is freed' )
    or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'sync-conflicts', $l );
ok( $rc == 0 && $out =~ m|conflicts 0|,
    'importing the live source tree resolves its old conflict' )
    or say "$out$err";
my $m = new_disk('trees-only');
( $rc, $out, $err ) = cli_n7fs( 'sync', $k, $m, '-trees-only' );
ok( $rc == 0 && $out =~ m|references0| && $out =~ m|trees1|,
    'trees-only imports the tree without ordinary references'
) or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'verify', $m );
ok( $rc == 0, 'trees-only receiver verifies with all pinned content' )
    or say $err;
( $rc, $out, $err ) = cli_n7fs( 'restore', $m, 'same', "$src/trees-only" );
ok( $rc == 0 && read_file("$src/trees-only/file") eq 'tree a',
    'trees-only receiver restores the synced tree'
) or say $err;

say ':: explicit and source-gone conflict resolution';
my $ma       = new_disk('manual-a');
my $me       = new_disk('manual-e');
my $manual_a = "$src/manual-a-tree";
my $manual_e = "$src/manual-e-tree";
make_dirs($manual_a);
make_dirs($manual_e);
write_file( "$manual_a/file", 'source value' );
write_file( "$manual_e/file", 'receiver value' );
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $ma, '-tree', 'manual', $manual_a );
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $me, '-tree', 'manual', $manual_e );
( $rc, $out, $err ) = cli_n7fs( 'sync', $ma, $me );
( $rc, $out, $err ) = cli_n7fs( 'sync-conflicts', $me );
my ($manual_record) = $out =~ m|\A(\S+\.sync-conflict)\s|m;
ok( defined $manual_record,
    'a tree conflict record name is listed for resolution' );
( $rc, $out, $err )
    = cli_n7fs( 'sync-conflicts', $me, 'resolve', $manual_record );
ok( $rc == 0 && $out =~ m|receiver value kept|,
    'explicit resolve keeps the receiver value for any conflict kind' )
    or say "$out$err";
( $rc, $out, $err )
    = cli_n7fs( 'restore', $me, 'manual', "$src/manual-restored" );
ok( $rc == 0 && read_file("$src/manual-restored/file") eq 'receiver value',
    'explicit resolution does not import or overwrite the receiver tree'
);
( $rc, $out, $err )
    = cli_n7fs( 'sync-conflicts', $me, 'resolve', $manual_record );
ok( $rc != 0, 'resolving an already resolved record refuses' );
( $rc, $out, $err ) = cli_n7fs( 'tree-drop', $ma, 'manual' );
( $rc, $out, $err ) = cli_n7fs( 'sync',      $ma, $me );
ok( $rc == 0 && $out =~ m|no changes|,
    'a source tree already gone stays resolved without another import' )
    or say "$out$err";
my $ga = new_disk('gone-a');
my $ge = new_disk('gone-e');
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $ga, '-tree', 'gone', $manual_a );
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $ge, '-tree', 'gone', $manual_e );
( $rc, $out, $err ) = cli_n7fs( 'sync',      $ga, $ge );
( $rc, $out, $err ) = cli_n7fs( 'tree-drop', $ga, 'gone' );
( $rc, $out, $err ) = cli_n7fs( 'sync',      $ga, $ge );
( $rc, $out, $err ) = cli_n7fs( 'sync-conflicts', $ge );
ok( $rc == 0 && $out =~ m|conflicts 0|,
    'an unresolved tree conflict resolves when the source tree is gone' )
    or say "$out$err";

say ':: epoch translation';
my $epoch_box = sandbox();
( $root, $hdir, $src ) = @{$epoch_box}{qw| root host src |};
%base = ( root => $root, host_dir => $hdir );
$host = key_file_write("$hdir/host.key");
my $ea = new_disk('epoch-a');
clock_epoch(200);
my $eb = new_disk('epoch-b');
clock_epoch(100);
my $odd_tree = "$src/epoch-tree";
make_dirs("$odd_tree/empty");
write_file( "$odd_tree/$raw", 'epoch raw' );
AMOS7::N7FS::Tree::_write_xattr( "$odd_tree/$raw", 'user.sync-test',
    'attribute bytes' );
symlink $raw, "$odd_tree/symlink" or die "symlink : $OS_ERROR";
$cli_epoch = 100;
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $ea, '-tree', 'epoch', $odd_tree );
$cli_epoch = 200;
( $rc, $out, $err ) = cli_n7fs( 'sync', $ea, $eb );
ok( $rc == 0, 'sync crosses different active epochs' ) or say "$out$err";
$cli_epoch = 100;
( $rc, $out, $err ) = cli_n7fs( 'restore', $ea, 'epoch', "$src/restore-a" );
$cli_epoch = 200;
( $rc, $out, $err ) = cli_n7fs( 'restore', $eb, 'epoch', "$src/restore-b" );
my $xattr_a = AMOS7::N7FS::Tree::_read_xattrs("$src/restore-a/$raw");
my $xattr_b = AMOS7::N7FS::Tree::_read_xattrs("$src/restore-b/$raw");
ok( $rc == 0
        && read_file("$src/restore-a/$raw") eq
        read_file("$src/restore-b/$raw")
        && readlink("$src/restore-a/symlink") eq
        readlink("$src/restore-b/symlink")
        && -d "$src/restore-b/empty"
        && ( $xattr_a->{'user.sync-test'} // '' ) eq 'attribute bytes'
        && ( $xattr_b->{'user.sync-test'} // '' ) eq 'attribute bytes',
    'restore is identical across epochs '
        . 'including odd names, symlinks and xattrs'
) or say $err;
( $rc, $out, $err ) = cli_n7fs( 'verify', $eb );
ok( $rc == 0, 'translated manifest and every pinned file verify' )
    or say $err;
( $rc, $out, $err ) = cli_n7fs( 'sync', $eb, $ea );
ok( $rc == 0 && $out =~ m|no changes ; no journal entry|,
    'rewritten manifest keeps origin and is idempotent back across epochs' )
    or say "$out$err";
my $ef = new_disk('epoch-fault');
$ENV{'N7FS_TEST_FAULT'} = 'sync:before-node-publish';
( $rc, $out, $err ) = cli_n7fs( 'sync', $ea, $ef );
delete $ENV{'N7FS_TEST_FAULT'};
ok( $rc != 0 && $err =~ m|run n7fs repair \Q$ef\E before retrying|,
    'a midway CLI failure names receiver repair before retry'
) or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'repair', $ef );
( $rc, $out, $err ) = cli_n7fs( 'sync', $ea, $ef );
ok( $rc == 0, 'repair and retry completes the failed epoch sync' )
    or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'verify', $ef );
ok( $rc == 0, 'repaired epoch receiver verifies after retry' ) or say $err;
$cli_epoch = undef;

say ':: trees-only cursor and tree drop then recreate';
$box = sandbox();
( $root, $hdir, $src ) = @{$box}{qw| root host src |};
%base = ( root => $root, host_dir => $hdir );
$host = key_file_write("$hdir/host.key");
clock_real();
my $ta           = new_disk('tree-history-a');
my $te           = new_disk('tree-history-e');
my $history_tree = "$src/history-tree";
make_dirs($history_tree);
write_file( "$history_tree/file", 'first tree' );
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $ta, '-tree', 'renew', $history_tree );
write_file( "$src/history-plain", 'plain reference' );
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $ta, "$src/history-plain" );
( $rc, $out, $err ) = cli_n7fs( 'sync', $ta, $te, '-trees-only' );
ok( $rc == 0 && !-d "$root/$te/.n7fs/sync-cursors",
    'trees-only writes no per-source cursor'
) or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'sync', $ta, $te );
my @history_refs = reference_entries( %base, disk => $te, host => $host );
ok( $rc == 0 && @history_refs == 2,
    'full sync after trees-only imports plain '
        . 'references without duplicating trees'
) or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'tree-drop', $ta, 'renew' );
write_file( "$history_tree/file", 'second tree' );
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $ta, '-tree', 'renew', $history_tree );
my $before_recreate
    = journal_replay( disk_read_id( %base, disk => $te ) )->{'seq'};
( $rc, $out, $err ) = cli_n7fs( 'sync', $ta, $te );
my $after_recreate
    = journal_replay( disk_read_id( %base, disk => $te ) )->{'seq'};
my ($source_tree)
    = values journal_replay( disk_read_id( %base, disk => $ta ) )->{'trees'}
    ->%*;
my ($target_tree)
    = values journal_replay( disk_read_id( %base, disk => $te ) )->{'trees'}
    ->%*;
ok( $rc == 0
        && $after_recreate >= $before_recreate + 2
        && $source_tree->{'manifest'} eq $target_tree->{'manifest'},
    'tree drop journals before the replacement add in the same sync'
) or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'tree-drop', $ta, 'renew' );
write_file( "$history_tree/file", 'third tree' );
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $ta, '-tree', 'renew', $history_tree );
{
    local $AMOS7::N7FS::FAULT = sub {
        die "injected tree-drop boundary crash\n"
            if $ARG[0] eq 'sync:after-tree-drop-journal';
    };
    eval { store_sync( %base, from => $ta, to => $te, host => $host ) };
}
ok( $EVAL_ERROR =~ m|tree-drop boundary|,
    'crash between the tree-drop and replacement journals is injected' );
( $rc, $out, $err ) = cli_n7fs( 'repair', $te );
( $rc, $out, $err ) = cli_n7fs( 'sync', $ta, $te );
ok( $rc == 0, 'retry after the tree-drop boundary completes replacement' )
    or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'verify', $te );
ok( $rc == 0, 'tree replacement receiver verifies after crash retry' )
    or say $err;

say ':: exact-current-version causality and batch category reports';
$box = sandbox();
( $root, $hdir, $src ) = @{$box}{qw| root host src |};
%base = ( root => $root, host_dir => $hdir );
$host = key_file_write("$hdir/host.key");
clock_real();
my $ca = new_disk('causal-a');
my $ce = new_disk('causal-e');

for my $category (qw| c1 c2 |) {
    ( $rc, $out, $err ) = cli_n7fs( 'category', $ca, 'set', $category );
}
my $causal_file = write_file( "$src/causal-file", 'causal bytes' );
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $ca, '-incoming', $causal_file );
( $rc, $out, $err ) = cli_n7fs( 'sync', $ca, $ce );
my ($causal_ref) = reference_entries( %base, disk => $ce, host => $host );
( $rc, $out, $err ) = cli_n7fs( 'incoming', $ca, 'tag', '*', 'c2' );
( $rc, $out, $err ) = cli_n7fs( 'incoming', $ce, 'tag', '*', 'c1' );
( $rc, $out, $err ) = cli_n7fs( 'sync', $ce, $ca );
ok( $rc != 0
        && $out
        =~ m|conflict assignment .* receiver \[ c2 \] ; source \[ c1 \]|,
    'concurrent batch tags conflict without exact-current-version history'
) or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'sync-conflicts', $ca );
my ($causal_conflict) = $out =~ m|\A(\S+\.sync-conflict)\s|m;
( $rc, $out, $err )
    = cli_n7fs( 'sync-conflicts', $ca, 'resolve', $causal_conflict );
my $sa = new_disk('sequential-a');
my $se = new_disk('sequential-e');

for my $category (qw| c1 c2 |) {
    ( $rc, $out, $err ) = cli_n7fs( 'category', $sa, 'set', $category );
}
my $sequential_file
    = write_file( "$src/sequential-file", 'sequential bytes' );
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $sa, '-incoming', $sequential_file );
( $rc, $out, $err ) = cli_n7fs( 'sync', $sa, $se );
my ($sequential_ref) = reference_entries( %base, disk => $se, host => $host );
( $rc, $out, $err ) = cli_n7fs( 'incoming', $sa, 'tag', '*', 'c2' );
( $rc, $out, $err ) = cli_n7fs( 'sync', $sa, $se );
ok( $rc == 0, 'A to E applies a change made after seeing E current version' )
    or say "$out$err";
( $rc, $out, $err )
    = cli_n7fs( 'set-category', $se, $sequential_ref->{'node'}, 'incoming' );
( $rc, $out, $err ) = cli_n7fs( 'incoming', $se, 'tag', '*', 'c1' );
( $rc, $out, $err ) = cli_n7fs( 'sync', $se, $sa );
ok( $rc == 0, 'E to A applies the reverse true-sequential batch change' )
    or say "$out$err";
( $rc, $out, $err )
    = cli_n7fs( 'category', $sa, 'show', $sequential_ref->{'node'} );
ok( $rc == 0 && $out =~ m|c1| && $out !~ m|incoming|,
    'category show reports the current batch assignment, not incoming' )
    or say "$out$err";
( $rc, $out, $err )
    = cli_n7fs( 'set-category', $sa, $sequential_ref->{'node'}, 'c2' );
( $rc, $out, $err ) = cli_n7fs( 'sync', $sa, $se );
( $rc, $out, $err )
    = cli_n7fs( 'set-category', $se, $sequential_ref->{'node'}, 'c1' );
( $rc, $out, $err ) = cli_n7fs( 'sync', $se, $sa );
ok( $rc == 0,
    'individual assignments also follow exact sequential causality' )
    or say "$out$err";
( $rc, $out, $err )
    = cli_n7fs( 'category', $ca, 'set', 'sequence', '-copies', 2 );
( $rc, $out, $err ) = cli_n7fs( 'sync', $ca, $ce );
( $rc, $out, $err )
    = cli_n7fs( 'category', $ce, 'set', 'sequence', '-copies', 3 );
( $rc, $out, $err ) = cli_n7fs( 'sync', $ce, $ca );
( $rc, $out, $err )
    = cli_n7fs( 'category', $ca, 'set', 'sequence', '-copies', 4 );
( $rc, $out, $err ) = cli_n7fs( 'sync',     $ca, $ce );
( $rc, $out, $err ) = cli_n7fs( 'category', $ce, 'list' );
ok( $rc == 0 && $out =~ m|sequence .* copies=4|,
    'category definitions follow true sequential causality in both directions'
) or say "$out$err";

say ':: release and revival at source head';
my $ra          = new_disk('revival-a');
my $re          = new_disk('revival-e');
my $revive_file = write_file( "$src/revive", 'revive bytes' );
( $rc, $out, $err ) = cli_n7fs( 'assimilate', '-disk', $ra, $revive_file );
my ($revive_old) = reference_entries( %base, disk => $ra, host => $host );
( $rc, $out, $err )
    = cli_n7fs( 'release', $ra, $revive_old->{'node'}, '-force' );
( $rc, $out, $err ) = cli_n7fs( 'assimilate', '-disk', $ra, $revive_file );
( $rc, $out, $err ) = cli_n7fs( 'sync', $ra, $re );
my @revive_live = grep { !$ARG->{'dropped'} && !$ARG->{'released'} }
    reference_entries( %base, disk => $re, host => $host );
ok( $rc == 0 && @revive_live == 1,
    'first sync of import, release and '
        . 're-import never releases live head content'
) or say "$out$err";
( $rc, $out, $err )
    = cli_n7fs( 'release', $ra, $revive_old->{'node'}, '-force' );
( $rc, $out, $err ) = cli_n7fs( 'sync', $ra, $re );
( $rc, $out, $err ) = cli_n7fs( 'assimilate', '-disk', $ra, $revive_file );
( $rc, $out, $err ) = cli_n7fs( 'sync', $ra, $re );
@revive_live = grep { !$ARG->{'dropped'} && !$ARG->{'released'} }
    reference_entries( %base, disk => $re, host => $host );
ok( $rc == 0 && @revive_live == 1,
    'incremental release then revival leaves '
        . 'the new origin live on the receiver'
) or say "$out$err";
( $rc, $out, $err ) = cli_n7fs( 'verify', $re );
ok( $rc == 0, 'receiver verifies after both revival orderings' ) or say $err;

say ':: crash points, repair and retry';
$box = sandbox();
( $root, $hdir, $src ) = @{$box}{qw| root host src |};
%base = ( root => $root, host_dir => $hdir );
$host = key_file_write("$hdir/host.key");
clock_real();
for my $point (
    qw| sync:after-categories sync:after-nodes sync:after-meta
    sync:after-references sync:after-trees sync:after-assignments
    sync:after-batches sync:after-drops sync:after-releases
    sync:before-journal |
) {
    my $fa         = new_disk('fault-a');
    my $fb         = new_disk('fault-b');
    my $fault_tree = "$src/fault-tree";
    make_dirs($fault_tree);
    write_file( "$fault_tree/file", 'fault bytes' );
    ( $rc, $out, $err ) = cli_n7fs( 'category', $fa, 'set', 'fault-cat' );
    ( $rc, $out, $err )
        = cli_n7fs( 'assimilate', '-disk', $fa,
        '-tree', 'fault-tree', $fault_tree );
    write_file( "$src/fault-pool", 'pool' );
    ( $rc, $out, $err )
        = cli_n7fs( 'assimilate', '-disk', $fa,
        '-incoming', "$src/fault-pool" );
    ( $rc, $out, $err )
        = cli_n7fs( 'incoming', $fa, 'tag', '*', 'fault-cat' );
    my ($fault_ref) = reference_entries( %base, disk => $fa, host => $host );
    ( $rc, $out, $err )
        = cli_n7fs( 'release', $fa, $fault_ref->{'node'}, '-force' );
    my %run    = ( %base, from => $fa, to => $fb, host => $host );
    my $failed = eval {
        local $AMOS7::N7FS::FAULT = sub {
            die "injected sync crash\n" if $ARG[0] eq $point;
        };
        store_sync(%run);
        1;
    };
    ok( !$failed && $EVAL_ERROR =~ m|injected sync crash|,
        "fault point $point fires" );
    ( $rc, $out, $err ) = cli_n7fs( 'repair', $fb );
    ok( $rc == 0, "repair after $point" ) or say $err;
    ( $rc, $out, $err ) = cli_n7fs( 'sync', $fa, $fb );
    ok( $rc == 0, "sync retry after $point" ) or say "$out$err";
    ( $rc, $out, $err ) = cli_n7fs( 'verify', $fb );
    ok( $rc == 0, "verify after $point repair and retry" ) or say $err;
}

done();

#,,..,..,,.,,,.,.,,,.,,.,,,,.,,,,,...,.,.,,,.,..,,...,...,...,.,.,.,,,,..,,,.,
#473K5DKYZKW57VGCDXGYGTIEURYJ7HTVOEHU7QQU2VR5GE2G53Z465DXOVHD7BXL7D5BU373FKEJ6
#\\\|WFYRIUCRBHARZKR747RLWJ3IC4TU22MYRCJTZ3ZCSVTMX4CSCEU \ / AMOS7 \ YOURUM ::
#\[7]6KSSNXQRDSXAAGMKZKPUCLSEWGFGTGGDA5YGOSTTHN5NN4EH4EBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
