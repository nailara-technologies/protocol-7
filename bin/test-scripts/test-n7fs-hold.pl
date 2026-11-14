#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## stage 9 : pre-sync holds, bounded restore and hold-aware reclaim.

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use AMOS7::N7FS       qw| read_file make_dirs ntime_now ntime14 |;
use AMOS7::NTIME      qw| parse_y_age |;
use AMOS7::N7FS::Sign qw| key_file_write key_file_signer |;
use AMOS7::N7FS::Disk qw| disk_init disk_attach disk_read_id state_read
    store_key_signer |;
use AMOS7::N7FS::Store   qw| reference_entries reference_drop store_repair |;
use AMOS7::N7FS::Journal qw| journal_replay |;
use AMOS7::N7FS::Record  qw| record_write |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

my $box  = sandbox();
my $base = $box->{'base'};
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
my $host   = key_file_write("$hdir/host.key");
my %common = ( root => $root, host_dir => $hdir );

sub cli {
    my @args = @ARG;
    my $out  = "$base/out";
    my $err  = "$base/err";
    my $pid  = fork // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDOUT, '>:raw', $out ) or exit 98;
        open( STDERR, '>:raw', $err ) or exit 98;
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
        %common,
        parent => test_signer(),
        name   => $name,
        intent => 'stage 9 sandbox'
    );
    disk_attach( %common, disk => $disk, host => $host );
    return $disk;
}

my $serial = 0;

sub tree_pair {
    my $label = shift;
    my $a     = new_disk("$label-a");
    my $b     = new_disk("$label-b");
    my $tree  = "$src/$label-" . $serial++;
    make_dirs("$tree/sub");
    write_file( "$tree/sub/old", "$label old tree\n" );
    my ( $rc, $out, $err )
        = cli( 'assimilate', '-disk', $a, '-keep', '-tree', 'history',
        $tree );
    die $err if $rc;
    ( $rc, $out, $err ) = cli( 'sync', $a, $b );
    die "$out$err" if $rc;
    return ( $a, $b, $tree );
}

sub drop_receiver_references {
    my $disk = shift;
    foreach my $ref ( reference_entries( %common, disk => $disk ) ) {
        next if $ref->{'dropped'};
        reference_drop(
            %common,
            disk    => $disk,
            host    => $host,
            address => $ref->{'node'},
            holder  => $ref->{'holder'},
        );
    }
    return;
}

my ( $a, $b, $tree ) = tree_pair('held');
my $id_b   = disk_read_id( %common, disk => $b );
my $before = journal_replay($id_b)->{'seq'};
my ( $rc, $out, $err ) = cli( 'tree-drop', $a, 'history' );
( $rc, $out, $err ) = cli( 'sync', $a, $b );
ok( $rc == 0 && $out =~ m|hold \d{14}\.[A-Z2-7]{8}\.hold before sync|,
    'a sync with a tree drop writes its hold first' )
    or say "$out$err";
my $replay      = journal_replay($id_b);
my ($hold_path) = sort keys $replay->{'holds'}->%*;
my $hold        = $replay->{'holds'}{$hold_path};
ok( defined $hold
        && $hold->{'seq'} == $before
        && $hold->{'source'} eq $a
        && $hold->{'reason'} eq 'before sync drops'
        && $hold->{'expires'} - $hold->{'ntime'} == parse_y_age('1Y1'),
    'the hold names the pre-drop sequence, source and default 1Y1 expiry'
);
ok( !$replay->{'trees'}{'history'},
    'the receiver tree drops only after the hold entry' );

( $rc, $out, $err ) = cli( 'holds', $b );
ok( $rc == 0
        && $out =~ m|\Q$hold_path\E|
        && $out =~ m|created=\d{14}|
        && $out =~ m|expires=\d{14}|
        && $out =~ m|trees=history|
        && $out =~ m|state=live|,
    'holds lists id, times, state and protected tree'
) or say "$out$err";

( $rc, $out, $err )
    = cli( 'restore', $b, 'history', "$src/restored-seq", '-at', $before );
ok( $rc == 0 && read_file("$src/restored-seq/sub/old") eq "held old tree\n",
    'restore -at <seq> restores the pre-drop tree' )
    or say "$out$err";
( $rc, $out, $err )
    = cli( 'restore', $b, 'history', "$src/restored-hold", '-at',
    $hold_path );
ok( $rc == 0 && read_file("$src/restored-hold/sub/old") eq "held old tree\n",
    'restore -at <hold> resolves the same journal point'
) or say "$out$err";

drop_receiver_references($b);
my @old_nodes
    = sort keys journal_replay( $id_b, upto => $before )->{'nodes'}->%*;
( $rc, $out, $err ) = cli( 'reclaim', $b );
ok( $rc == 0
        && $out =~ m|reclaim kept [1-9]\d* nodes under live holds|
        && scalar( grep { -e "$root/$b/$ARG/content" } @old_nodes ),
    'reclaim keeps every node named by the live hold sequence'
) or say "$out$err";
( $rc, $out, $err ) = cli( 'verify', $b );
ok( $rc == 0, 'verify authenticates hold records and their journal entries' )
    or say "$out$err";

( $rc, $out, $err ) = cli( 'hold-release', $b, $hold_path );
ok( $rc == 0 && !keys journal_replay($id_b)->{'holds'}->%*,
    'hold-release journals an early release' )
    or say "$out$err";
( $rc, $out, $err ) = cli( 'reclaim', $b );
ok( $rc == 0 && !scalar( grep { -e "$root/$b/$ARG/content" } @old_nodes ),
    'reclaim releases the old nodes after the early hold release'
) or say "$out$err";
( $rc, $out, $err ) = cli( 'hold-release', $b, $hold_path );
ok( $rc != 0 && $err =~ m|no live hold|,
    'releasing an already released hold refuses clearly' );

say ':: expiry';
my ( $ea, $eb ) = tree_pair('expiry');
my $id_eb = disk_read_id( %common, disk => $eb );
( $rc, $out, $err ) = cli( 'tree-drop', $ea, 'history' );
( $rc, $out, $err ) = cli( 'sync', $ea, $eb, '-hold', '0Y0' );
ok( $rc == 0, 'a custom zero-age hold is accepted for the expiry sandbox' )
    or say "$out$err";
( $rc, $out, $err ) = cli( 'holds', $eb );
ok( $rc == 0 && $out =~ m|state=expired|,
    'holds reports an expired hold without extending it' );
my $expired_replay = journal_replay($id_eb);
my ($expired_path) = keys $expired_replay->{'holds'}->%*;
my @expired_nodes
    = keys journal_replay( $id_eb,
    upto => $expired_replay->{'holds'}{$expired_path}{'seq'} )->{'nodes'}->%*;
drop_receiver_references($eb);
( $rc, $out, $err ) = cli( 'reclaim', $eb );
ok( $rc == 0
        && !keys journal_replay($id_eb)->{'holds'}->%*
        && !scalar( grep { -e "$root/$eb/$ARG/content" } @expired_nodes ),
    'reclaim drops an expired hold and releases its nodes normally'
) or say "$out$err";

say ':: no-hold';
my ( $na, $nb ) = tree_pair('no-hold');
( $rc, $out, $err ) = cli( 'tree-drop', $na, 'history' );
( $rc, $out, $err ) = cli( 'sync', $na, $nb, '-no-hold' );
ok( $rc == 0
        && $err =~ m|warning : -no-hold|
        && !
        keys journal_replay( disk_read_id( %common, disk => $nb ) )
        ->{'holds'}->%*
        && !journal_replay( disk_read_id( %common, disk => $nb ) )
        ->{'trees'}{'history'},
    '-no-hold warns and proceeds without a hold'
) or say "$out$err";

say ':: crash between hold and drop';
my ( $ca, $cb ) = tree_pair('crash');
my $id_cb = disk_read_id( %common, disk => $cb );
( $rc, $out, $err ) = cli( 'tree-drop', $ca, 'history' );
{
    local $ENV{'N7FS_TEST_FAULT'} = 'sync:after-hold';
    ( $rc, $out, $err ) = cli( 'sync', $ca, $cb );
}
my $crash_replay = journal_replay($id_cb);
my ($crash_hold) = sort keys $crash_replay->{'holds'}->%*;
ok( $rc != 0
        && $err =~ m|injected fault sync:after-hold|
        && defined $crash_hold
        && $crash_replay->{'trees'}{'history'},
    'a crash after the hold leaves both the hold and old tree live'
) or say "$out$err";
( $rc, $out, $err )
    = cli( 'restore', $cb, 'history', "$src/crash-restored", '-at',
    $crash_hold );
ok( $rc == 0
        && read_file("$src/crash-restored/sub/old") eq "crash old tree\n",
    'the crash hold is immediately usable by restore -at'
) or say "$out$err";
( $rc, $out, $err ) = cli( 'repair', $cb );
( $rc, $out, $err ) = cli( 'sync', $ca, $cb );
ok( $rc == 0 && !journal_replay($id_cb)->{'trees'}{'history'},
    'repair preserves the crash hold and retry completes the drop'
) or say "$out$err";
( $rc, $out, $err ) = cli( 'verify', $cb );
ok( $rc == 0, 'the crash and retry receiver verifies' ) or say "$out$err";

say ':: unjournaled hold quarantine';
my $qb     = new_disk('quarantine');
my $id_qb  = disk_read_id( %common, disk => $qb );
my $orphan = record_write(
    $id_qb,
    store_key_signer( %common, id => $id_qb ),
    qw| hold |,
    qw| holds |,
    qw| hold |,
    {   disk    => $qb,
        seq     => 0,
        reason  => 'unjournaled test hold',
        expires => sub { ntime14( $ARG[0] + parse_y_age('1Y1') ) },
    }
);
my $repair = store_repair( %common, disk => $qb, host => $host );
ok( scalar(
        grep {
            $ARG->{'type'} eq 'hold' && $ARG->{'path'} eq $orphan->{'path'}
        } $repair->{'quarantined'}->@*
    ),
    'repair quarantines an unjournaled hold like other record classes'
);

done();

#,,,.,...,,.,,,.,,...,,..,,.,,.,.,,.,,.,.,,,.,..,,...,..,,...,,..,..,,..,,,..,
#2NVOPCSFJKFRWNXFBBFT7DJYU3XX7H2KHXEB66OBXRKW43VNF5PHYP4WMOVOTLSUUGO6GIXO6273O
#\\\|VKJKSWWIRDBXVYHUN2CJMNCFKYA64ZTQZXX3BLZJLT2GYKEIMZE \ / AMOS7 \ YOURUM ::
#\[7]PYTV3LPMSGIGIWM2KBVZFYALMPVGX5KDNFWDSU2ABWZFT6RINSBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
