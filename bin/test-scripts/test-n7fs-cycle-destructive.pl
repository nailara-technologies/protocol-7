#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## stage 11 : the strict cycle gate and per-holder destructive phase.

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use AMOS7::NTIME         qw| parse_y_age y_level_ntime |;
use AMOS7::N7FS          qw| make_dirs read_file ntime_now |;
use AMOS7::N7FS::Cycle   qw| cycle_gate state_read |;
use AMOS7::N7FS::Disk    qw| disk_read_id |;
use AMOS7::N7FS::Journal qw| journal_replay |;
use AMOS7::N7FS::Sign    qw| key_file_signer |;
use AMOS7::N7FS::Store   qw| assimilate |;
use AMOS7::N7FS::Keys;
use AMOS7::N7FS::Seal;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

my $box  = sandbox();
my $base = $box->{'base'};
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
my $key  = "$base/root.key";
my $pass = "$base/pass";
write_file( $pass, "cycle pass\ncycle pass\n" );
chmod 0600, $pass or die $OS_ERROR;
make_dirs("$base/tmp");
$ENV{'TMPDIR'} = "$base/tmp";

sub cli {
    my @args = @ARG;
    my $out  = "$base/out";
    my $err  = "$base/err";
    open( my $stdin, '<:raw', -e $pass ? $pass : '/dev/null' )
        or die $OS_ERROR;
    my $pid = fork // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDIN,  '<&',    $stdin ) or exit 98;
        open( STDOUT, '>:raw', $out )   or exit 98;
        open( STDERR, '>:raw', $err )   or exit 98;
        exec( $EXECUTABLE_NAME, "$FindBin::Bin/../n7fs", '-root', $root,
            '-host-dir', $hdir, '-pass-fd', 0, @args )
            or exit 99;
    }
    close $stdin;
    waitpid $pid, 0;
    return ( $CHILD_ERROR >> 8, read_file($out), read_file($err) );
}

my ( $rc, $out, $err ) = cli( 'keygen', "$hdir/host.key" );
( $rc, $out, $err ) = cli( 'keygen', "$hdir/parent.key" );
( $rc, $out, $err ) = cli( 'pubkey', "$hdir/parent.key" );
write_file( "$hdir/trusted-parents", $out );
( $rc, $out, $err )
    = cli( 'init', '-name', 'destructive', '-intent', 'sandbox' );
my ($disk)
    = grep { !m|^\.| } do { opendir( my $d, $root ) or die; readdir $d };
( $rc, $out, $err ) = cli( 'attach', $disk );
( $rc, $out, $err )
    = cli( 'root', 'init', $key, '-argon-m', 1024, '-argon-t', 1 );
write_file( $pass, "cycle pass\n" );
ok( $rc == 0, 'sandbox disk, host keys and root are ready' )
    or say "$out$err";

my $holder_a = "$base/holder-a";
my $holder_b = "$base/holder-b";
make_dirs($ARG) for $holder_a, $holder_b;
( $rc, $out, $err )
    = cli( 'holder', 'add', 'a', $holder_a,
    '-domain', 'a', '-root-key', $key );
( $rc, $out, $err )
    = cli( 'holder', 'add', 'b', $holder_b,
    '-domain', 'b', '-root-key', $key );
ok( $rc == 0, 'two direct durable holders are registered' ) or say "$out$err";

my $clock = ntime_now();
my $y4    = y_level_ntime(4);

sub import_tree {
    my ( $name, $time, $file, $bytes ) = @ARG;
    my $dir = "$src/$name";
    make_dirs($dir);
    write_file( "$dir/$file", $bytes );
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
        qw| category |       => 'work',
        qw| protect |        => [],
    );
}
( $rc, $out, $err ) = cli( 'category', $disk, 'set', 'work', '-copies', 1 );
die "$out$err" if $rc;
import_tree( 'snap:old', $clock - 10000 * $y4,
    'unique', "old unique bytes\n" );
import_tree( 'snap:pinned', $clock - 9000 * $y4, 'pinned', "pinned bytes\n" );
import_tree( 'snap:current', $clock, 'current', "current bytes\n" );
for my $holder ( $holder_a, $holder_b ) {
    ( $rc, $out, $err )
        = cli( 'seal', $disk, '-root-key', $key, '-out', $holder,
        '-all-trees' );
    die "$out$err" if $rc;
    ( $rc, $out, $err )
        = cli( 'holder-check', $holder, '-root-key', $key, '-full' );
    die "$out$err" if $rc;
}
( $rc, $out, $err )
    = cli( 'retain-set', $disk, '-root-key', $key, 'snap:', '1Y4' );
( $rc, $out, $err )
    = cli( 'tree-pin', $disk, '-root-key', $key, 'snap:pinned' );
ok( $rc == 0, 'synthetic-age trees are sealed with a ladder and a pin' )
    or say "$out$err";

sub open_root {
    open( my $fh, '<:raw', $pass ) or die $OS_ERROR;
    return AMOS7::N7FS::Keys::root_open(
        qw| path |    => $key,
        qw| pass_fd | => fileno($fh),
    );
}

sub write_config {
    my %extra = @ARG;
    make_dirs("$hdir/cycle");
    my @lines = (
        "cycle.work.disk          = $disk",
        "cycle.work.root-key      = $key",
        "cycle.work.pass-file     = $pass",
        'cycle.work.prefix        = snap',
        'cycle.work.check         = full',
        'cycle.work.scrub-every   = 1Y2',
        'cycle.work.drill-every   = 1Y1',
        "cycle.work.drill-scratch = $base/tmp",
        'cycle.work.retain        = yes',
        'cycle.work.repack        = yes',
        'cycle.work.gc-grace      = 0Y3',
        'cycle.work.trash-age     = 3Y2',
        'cycle.work.reclaim-local = no',
        'cycle.work.snapshot-only = no',
    );
    for my $key ( sort keys %extra ) {
        my $value = delete $extra{$key};
        @lines = grep { !m|\Acycle\.work\.\Q$key\E\s+=| } @lines;
        push @lines, "cycle.work.$key = $value" if defined $value;
    }
    write_file( "$hdir/cycle/work.cfg", join( "\n", @lines ) . "\n" );
    chmod 0600, "$hdir/cycle/work.cfg" or die $OS_ERROR;
    return;
}
write_config();

my $strict = cycle_gate(
    qw| additive_ok |   => 1,
    qw| local_now |     => 1000,
    qw| effective_now | => 1000,
    qw| drill_max_age | => 100,
    qw| drill |  => { time    => 990, tree => 'snap:x', holder => 'a' },
    qw| nodes |  => { address => { target => 1 } },
    qw| proofs | => {
        address => {
            domains => {},
            holders => { map { $ARG => 1 } qw| a b c d e | }
        }
    },
);
ok( !$strict->{'ok'},
    'strict domain coverage fails without a full-receipt domain' );
my $quorum = cycle_gate(
    qw| additive_ok |   => 1,
    qw| local_now |     => 1000,
    qw| effective_now | => 1000,
    qw| drill_max_age | => 100,
    qw| drill |  => { time    => 990, tree => 'snap:x', holder => 'a' },
    qw| nodes |  => { address => { target => 1 } },
    qw| proofs | => {
        address => {
            domains => {},
            holders => { map { $ARG => 1 } qw| a b c d e | }
        }
    },
    qw| rule | => sub { scalar( keys $_[2]{'holders'}->%* ) >= 5 },
);
ok( $quorum->{'ok'},
    'the gate rule parameter supports a five-holder confirmation rule' );
my $bad_clock = cycle_gate(
    qw| additive_ok |   => 1,
    qw| local_now |     => 1000,
    qw| effective_now | => 1000 + parse_y_age('1Y4') + 1,
    qw| drill_max_age | => 100,
    qw| drill |         => { time => 990, tree => 'snap:x', holder => 'a' },
    qw| nodes |         => {},
);
ok( !$bad_clock->{'ok'}, 'an implausible clock floor closes the gate' );

( $rc, $out, $err ) = cli( 'category', $disk, 'set', 'work', '-copies', 3 );
die "$out$err" if $rc;
my @before_a = holder_blobs($holder_a);
my @before_b = holder_blobs($holder_b);
( $rc, $out, $err ) = cli( 'cycle', 'work' );
ok( $rc == 1
        && $out =~ m|gate replication : shut \[ [1-9]\d* nodes below target|
        && $out =~ m|gate shut \[ no destructive step ran \]|
        && $out !~ m|D1-retain|,
    'one under-target node closes the gate with exit 1 and no delete step'
) or say "$out$err";
my %after_a = map { $ARG => 1 } holder_blobs($holder_a);
my %after_b = map { $ARG => 1 } holder_blobs($holder_b);
ok(    !( grep { not $after_a{$ARG} } @before_a )
    && !( grep { not $after_b{$ARG} } @before_b )
        && journal_replay( disk_read_id( root => $root, disk => $disk ) )
        ->{'trees'}{'snap:old'},
    'the under-target run deletes no holder blob and keeps the old tree'
);

my $dry_before = snapshot( $root, $hdir, $holder_a, $holder_b, $key, $src );
( $rc, $out, $err ) = cli( 'cycle', 'work', '-dry-run' );
my $dry_after = snapshot( $root, $hdir, $holder_a, $holder_b, $key, $src );
ok( $rc == 1
        && $out =~ m|D1-retain.*would drop 1 trees|
        && $out =~ m|D2-repack.*would repack|
        && $out =~ m|D3-gc.*would trash|
        && $out =~ m|D4-purge.*would purge|
        && $out =~ m|D5-reclaim.*local reclaim disabled|
        && snap_equal( $dry_before, $dry_after ),
    'dry-run reports every destructive step and changes no bytes or state'
) or say "$out$err";

( $rc, $out, $err ) = cli( 'category', $disk, 'set', 'work', '-copies', 1 );
die "$out$err" if $rc;
( $rc, $out, $err )
    = cli( 'hold', $disk, '-reason', 'stage 11 test', '-for', '1Y1' );
die "$out$err" if $rc;
my ($hold_path) = $out =~ m|hold ([^ ]+\.hold)|;
ok( defined $hold_path, 'a live hold covers the old tree before retention' )
    or say "$out$err";
( $rc, $out, $err ) = cli( 'cycle', 'work' );
my @order = map { $out =~ m|\Q$ARG\E| ? index( $out, $ARG ) : -1 }
    qw| D1-retain D2-repack D3-gc D4-purge D5-reclaim |;
ok( $rc == 0
        && $out =~ m|gate open|
        && !( grep { $ARG < 0 } @order )
        && join( ',', @order ) eq join( ',', sort { $a <=> $b } @order ),
    'an open gate runs retain, repack, gc, purge and reclaim in order'
) or say "$out$err";
my $id     = disk_read_id( root => $root, disk => $disk );
my $replay = journal_replay($id);
ok( !exists $replay->{'trees'}{'snap:old'}
        && exists $replay->{'trees'}{'snap:pinned'}
        && exists $replay->{'trees'}{'snap:current'},
    'the full cycle drops the expired tree '
        . 'and preserves pinned and current trees'
);
( $rc, $out, $err )
    = cli( 'restore', $disk, 'snap:old',
    "$base/held-restore", '-at', $hold_path );
ok( $rc == 0
        && read_file("$base/held-restore/unique") eq "old unique bytes\n",
    'the held tree remains restorable after the full cycle'
) or say "$out$err";
( $rc, $out, $err )
    = cli( 'seal-recover', '-root-key', $key,
    '-from', $holder_a, '-tree', 'snap:pinned', "$base/pinned-restore" );
ok( $rc == 0 && read_file("$base/pinned-restore/pinned") eq "pinned bytes\n",
    'the pinned tree restores from a holder after retain, repack and gc'
) or say "$out$err";

{
    local $ENV{'N7FS_TEST_FAULT'} = 'cycle:before-D2-repack';
    ( $rc, $out, $err ) = cli( 'cycle', 'work' );
}
ok( $rc == 2
        && $out =~ m|D1-retain ok|
        && $out =~ m|D2-repack failed|
        && $out
        =~ m|holder a : skipped \[ holder unavailable or an earlier destructive step failed \]|
        && $out =~ m|D4-purge ok \[ purged 0 trash buckets|,
    'a repack failure keeps retain results and skips gc and purge'
) or say "$out$err";
my $fault_state = state_read( $hdir, 'work' );
ok( ( $fault_state->{'step.D3-gc.holder.a.result'} // '' ) eq 'skipped'
        && ( $fault_state->{'step.D3-gc.holder.b.result'} // '' ) eq 'skipped'
        && ( $fault_state->{'step.D4-purge.holder.a.result'} // '' ) eq
        'skipped'
        && ( $fault_state->{'step.D4-purge.holder.b.result'} // '' ) eq
        'skipped',
    'per-holder state records that repack blocked every later holder step'
);

my $open_root = open_root();
my $sub_a     = holder_sub($holder_a);
my $head_path = "$sub_a/" . AMOS7::N7FS::Seal::_head_name($open_root);
my $old_head  = read_file($head_path);
( $rc, $out, $err ) = cli( 'head-refresh', '-root-key', $key, $holder_a );
die "$out$err" if $rc;
my $new_head = read_file($head_path);
write_file( $head_path, $old_head );
( $rc, $out, $err ) = cli( 'cycle', 'work' );
ok( $rc == 1
        && $out =~ m|gate stale-head : shut \[ a \]|
        && $out !~ m|D1-retain|,
    'a stale head closes the gate before any destructive step'
) or say "$out$err";
write_file( $head_path, $new_head );

write_file( "$hdir/snapshot-retention.cfg",
          "[$disk/snap:]\ntree = snap:current\nfiles "
        . "= 1\nbytes = 1\ntime = 00000000000000\n" );
( $rc, $out, $err ) = cli( 'cycle', 'work' );
ok( $rc == 1 && $out =~ m|gate shrink-freeze : shut| && $out !~ m|D1-retain|,
    'a shrink-guard freeze closes the gate before any destructive step'
) or say "$out$err";
unlink "$hdir/snapshot-retention.cfg" or die $OS_ERROR;

my $old_manifest
    = $replay->{'trees'}{'snap:old'}
    ? $replay->{'trees'}{'snap:old'}{'manifest'}
    : do {
    my $before_drop = journal_replay( $id,
        upto => $replay->{'holds'}{$hold_path}{'seq'} );
    $before_drop->{'trees'}{'snap:old'}{'manifest'};
    };
my ($old_unique) = AMOS7::N7FS::Seal::_manifest_files( $id, $old_manifest );
ok( -e "$root/$disk/$old_unique/content",
    'retention and gc leave the old local content for the reclaim decision' );

write_config( 'reclaim-local' => '13Y2' );
( $rc, $out, $err ) = cli( 'cycle', 'work' );
ok( $rc == 4
        && $err =~ m|reclaim-local needs snapshot-only = yes|
        && -e "$root/$disk/$old_unique/content",
    'reclaim is refused on a disk not marked snapshot-only'
) or say "$out$err";

write_config( 'reclaim-local' => '13Y2', 'snapshot-only' => 'yes' );
( $rc, $out, $err ) = cli( 'cycle', 'work' );
ok( $rc == 0
        && $out
        =~ m|holder local : ok \[ reclaimed 0 nodes, 0 bytes older than 13Y2 \[ [1-9]\d* held \] \]|
        && -e "$root/$disk/$old_unique/content",
    'snapshot-only reclaim honours the live hold and deletes no held bytes'
) or say "$out$err";

( $rc, $out, $err ) = cli( 'hold-release', $disk, $hold_path );
die "$out$err" if $rc;
( $rc, $out, $err ) = cli( 'cycle', 'work' );
ok( $rc == 0
        && $out
        =~ m|holder local : ok \[ reclaimed [1-9]\d* nodes, [1-9]\d* bytes older than 13Y2|
        && !-e "$root/$disk/$old_unique/content"
        && !-e "$root/$disk/$old_manifest/content",
    'snapshot-only reclaim deletes garbage older than 13Y2 after hold release'
) or say "$out$err";
( $rc, $out, $err )
    = cli( 'seal-recover', '-root-key', $key,
    '-from', $holder_b, '-tree', 'snap:pinned', "$base/final-restore" );
ok( $rc == 0 && read_file("$base/final-restore/pinned") eq "pinned bytes\n",
    'the pinned tree still restores after local reclaim' )
    or say "$out$err";

done();

#,,..,...,,,,,,,,,.,,,.,,,,,.,.,.,.,.,,.,,.,.,..,,...,.,,,.,.,.,.,,.,,,,.,..,,
#DLEUWDZ2BSIUXF2ITM2FSPDN3BNQ6DNIWOALEC4VNHUVR7IS5KNO5NHMVZ3KXNVS5JY7O4B7GGJ3M
#\\\|Z32YEFN7CUTKNEP5BNEBXP2LLWSCLM7OOEOJHB5K2HT5BFOR2S3 \ / AMOS7 \ YOURUM ::
#\[7]Q7DDDLE2YSP3LD7MP7NMU453DWIW45KB4QYKI7YOGJ2NH6JUAWCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
