#!/usr/bin/perl
use v5.32.0;
use strict;
use POSIX ();
use English;
use warnings;

## N7FS format 3 stage 2 : release, reclaim, tombstones, crash completion and
## concurrent writers. all disks and sources live below File::Temp
## directories.

use FindBin;

BEGIN {
    unshift @INC, "$FindBin::Bin/../../data/lib-path/pm";
    unshift @INC, $ENV{'N7FS_TEST_LIB'} if $ENV{'N7FS_TEST_LIB'};
}

use AMOS7::N7FS
    qw| read_file signed_record_parse plain_record_pack remove_tree |;
use AMOS7::N7FS::Sum  qw| epoch_b32 epoch_int amos_of_bmw |;
use AMOS7::N7FS::Sign qw| key_file_write key_file_signer verify |;
use AMOS7::N7FS::Disk qw| disk_init disk_attach disk_read_id state_read
    state_write |;
use AMOS7::N7FS::Store qw| assimilate store_verify store_nodes reference_drop
    reference_entries store_repair codec |;
use AMOS7::N7FS::Journal qw| journal_replay journal_write |;
use AMOS7::N7FS::Release qw| release_node store_reclaim tombstone_latest |;
use AMOS7::N7FS::Convert qw| upgrade confirm release_epoch |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";
use constant TRUE  => 5;
use constant FALSE => 0;

my $box  = sandbox();
my $root = $box->{'root'};
my $hdir = $box->{'host'};
my $src  = $box->{'src'};
my $host = key_file_write("$hdir/host.key");
my %base = ( root => $root, host_dir => $hdir );
clock_real();

sub cli_n7fs {
    my @args = @ARG;
    my $out  = "$box->{'base'}/cli.stdout";
    my $err  = "$box->{'base'}/cli.stderr";
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
        %base,
        parent => test_signer(),
        name   => $name,
        intent => 'n7fs release tests [ test data ]'
    );
    my %run = ( %base, disk => $disk, host => $host );
    disk_attach(%run);
    return ( $disk, %run );
}

sub one_node {
    my ( $run, $body, $name ) = @ARG;
    my $file = write_file( "$src/$name", $body );
    assimilate( %{$run}, paths => [$file] );
    my $id = disk_read_id( %base, disk => $run->{'disk'} );
    my $st = state_read("$root/$run->{'disk'}");
    my ($node)
        = grep { read_file("$ARG->{'path'}/content") eq $body }
        store_nodes( "$root/$run->{'disk'}", $st->{'epochs'}->@* );
    my $address = join '/', epoch_b32( $node->{'epoch'} ), $node->{'amos'},
        $node->{'bmw'};
    return ( $file, $node, $address, $id );
}

my ( $disk, %run ) = new_disk('release-main');
my ( $file, $node, $address, $id )
    = one_node( \%run, "release me\n", 'release.txt' );
my $dpath = "$root/$disk";

my ( $rc, $out, $err ) = cli_n7fs( 'release', $disk, $address );
ok( $rc != 0 && $err =~ m|live references.*\Q$file\E|s,
    'release refuses and names a live reference'
);
ok( -e "$node->{'path'}/content", 'the refused release kept the node' );
( $rc, $out, $err )
    = cli_n7fs( 'release', $disk, $address, '-force',
    '-reason', 'owner request' );
ok( $rc == 0
        && $err =~ m|breaks live reference \Q$file\E|
        && $out =~ m|does not prove the bytes unrecoverable|,
    'forced release warns what breaks and states the recoverability limit'
);
ok( !-e $node->{'path'}, 'release removes the node directory' );
my $tomb = tombstone_latest( $id, $address );
ok( $tomb
        && $tomb->{'reason'} eq 'owner request'
        && $tomb->{'disk'} eq $disk
        && $tomb->{'addr'} eq $address,
    'a signed tombstone survives outside the node directory'
);
my ($tomb_file) = glob "$dpath/.n7fs/tombstones/*.tombstone";
my $tomb_rec = signed_record_parse( 'tombstone', read_file($tomb_file) );
ok( substr( read_file($tomb_file), 0, 5 ) eq "P7FX\x03" && verify(
        $id->{'store_pub'}, $tomb_rec->{'signed'}, $tomb_rec->{'sig'}
    ),
    'tombstone uses p7 n7fs tombstone:0001 record format 3'
);
{
    my $bytes = read_file($tomb_file);
    my $bad   = $bytes;
    substr( $bad, -1, 1 ) = chr( ord( substr( $bad, -1, 1 ) ) ^ 1 );
    chmod 0600, $tomb_file;
    write_file( $tomb_file, $bad );
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|tombstone.*signature does not verify|,
        'verification authenticates permanent tombstones'
    );
    write_file( $tomb_file, $bytes );
}
ok( store_verify( %base, disk => $disk )->{'nodes'} == 0,
    'released node is expected-absent during verification'
);
( $rc, $out, $err ) = cli_n7fs( 'get', $disk, $address );
ok( $rc != 0 && $err =~ m|was released.*import the same content|s,
    'get by released address fails clearly and names content revival'
);
( $rc, $out, $err ) = cli_n7fs( 'find', $disk, '-all' );
ok( $rc == 0 && $out =~ m|\Q$address\E.*release\.txt.*released|,
    'find -all retains released reference and meta history'
);

my $copy = write_file( "$src/release-copy.txt", "release me\n" );
my $revive;
{
    local $AMOS7::N7FS::CLOCK = sub { return $tomb->{'ntime'} - 100 };
    $revive = assimilate( %run, paths => [ $file, $copy ] );
}
clock_real();
ok( $revive->{'failed'} == 0 && $revive->{'journal_seq'} == 3,
    'same content revives in one batch with a duplicate source'
);
ok( store_verify( %run, disk => $disk )->{'nodes'} == 1,
    'revived duplicate references and meta replay cleanly'
);
my @new_refs
    = grep { !$ARG->{'released'} } reference_entries( %base, disk => $disk );
ok( 2 == @new_refs
        && 2 == grep( { $ARG->{'ntime'} gt $tomb->{'ntime'} } @new_refs )
        && 2 ==
        grep( { $ARG->{'meta'}[-1]{'import_ntime'} gt $tomb->{'ntime'} }
        @new_refs ),
    'revived meta and references have newer ntimes than the tombstone'
);
( $rc, $out, $err ) = cli_n7fs( 'find', $disk, '-all' );
ok( 1 == grep( {m|\[ [^\n]* released \]|} split m|\n|, $out )
        && 2 == grep( { !m|\[ [^\n]* released \]| } split m|\n|, $out ),
    'history distinguishes the released reference from both new live ones'
);

refused(
    sub { release_node( %run, address => $address ) },
    qr|live references|,
    'a live revived node again refuses ordinary release'
);
refused(
    sub { release_node( %run, address => '../../etc/passwd' ) },
    qr|canonical node address|,
    'a malformed address cannot traverse a path'
);
refused(
    sub {
        release_node( %run, address => 'V7L36QQ/AAAAAAA/' . ( 'A' x 77 ) );
    },
    qr|canonical node address|,
    'an address with a wrong amos checksum refuses'
);
my $unknown_bmw = 'A' x 77;
my $unknown     = join '/', epoch_b32( $node->{'epoch'} ),
    amos_of_bmw($unknown_bmw), $unknown_bmw;
refused(
    sub { release_node( %run, address => $unknown ) },
    qr|unknown node|,
    'release of an unknown address refuses'
);
my $old = join '/', epoch_b32( $node->{'epoch'} + 1 ), $node->{'amos'},
    $node->{'bmw'};
refused(
    sub { release_node( %run, address => $old ) },
    qr|epoch is not active|,
    'release in a non-active or old epoch refuses'
);

say ':: dry-run, oldest garbage, size and age limits';
my $f2 = write_file( "$src/garbage.txt", 'garbage' x 100 );
assimilate( %run, paths => [$f2] );
my ($garbage_node)
    = grep { read_file("$ARG->{'path'}/content") eq 'garbage' x 100 }
    store_nodes( $dpath, state_read($dpath)->{'epochs'}->@* );
my $garbage_addr = join '/', epoch_b32( $garbage_node->{'epoch'} ),
    $garbage_node->{'amos'}, $garbage_node->{'bmw'};
reference_drop( %run, address => $garbage_addr, holder => $f2 );
my $fnew = write_file( "$src/garbage-new.txt", 'newer' x 100 );
assimilate( %run, paths => [$fnew] );
my ($new_garbage)
    = grep { read_file("$ARG->{'path'}/content") eq 'newer' x 100 }
    store_nodes( $dpath, state_read($dpath)->{'epochs'}->@* );
my $new_garbage_addr = join '/', epoch_b32( $new_garbage->{'epoch'} ),
    $new_garbage->{'amos'}, $new_garbage->{'bmw'};
reference_drop( %run, address => $new_garbage_addr, holder => $fnew );
my $before = snapshot( $root, $hdir, $src );
( $rc, $out, $err ) = cli_n7fs( 'reclaim', $disk, '-dry-run' );
ok( $rc == 0
        && $out =~ m|would release \Q$garbage_addr\E|
        && snap_equal( $before, snapshot( $root, $hdir, $src ) ),
    'reclaim -dry-run changes no file, including no lock file'
);
ok( index( $out, $garbage_addr ) < index( $out, $new_garbage_addr ),
    'reclaim lists oldest garbage first' );
( $rc, $out, $err )
    = cli_n7fs( 'reclaim', $disk, '-older', '1000000w', '-dry-run' );
ok( $rc == 0 && $out !~ m|would release|,
    'reclaim age filtering leaves young garbage alone' );
( $rc, $out, $err ) = cli_n7fs( 'reclaim', $disk, '-free', '1' );
ok( $rc == 0
        && !-e $garbage_node->{'path'}
        && -e $new_garbage->{'path'}
        && -e "$node->{'path'}/content",
    'reclaim stops at the size goal and never touches live content'
);
ok( store_verify( %run, disk => $disk ), 'reclaimed disk verifies' );

say ':: journal pre-sign checks and format 2 refusal';
{
    my $none = sub {
        { nodes => [], meta => [], references => [], releases => [] }
    };
    my $drop = $none->();
    $drop->{'releases'} = [ 'V7L36QQ/AAAAAAA/' . ( 'A' x 77 ) ];
    refused(
        sub {
            journal_write( $id,
                key_file_signer("$hdir/stores/$disk.store.key"),
                $none->(), $drop, {} );
        },
        qr|release of an unlisted node|,
        'journal_write refuses an invalid release before signing'
    );
}
my ( $v2disk, %v2run ) = new_disk('release-format2');
{
    my $p = state_read("$root/$v2disk");
    delete $p->{'_name'};
    $p->{'store_format'} = 2;
    state_write( "$root/$v2disk", $p,
        key_file_signer("$hdir/stores/$v2disk.store.key") );
}
my $v2file = write_file( "$src/v2.txt", 'format two' );
assimilate( %v2run, paths => [$v2file], allow_rollback => TRUE );
$v2run{'allow_rollback'} = TRUE;
refused(
    sub { store_reclaim(%v2run) },
    qr|only available for store format 3|,
    'format 2 refuses reclaim clearly'
);
my ($v2node)
    = store_nodes( "$root/$v2disk",
    state_read("$root/$v2disk")->{'epochs'}->@* );
my $v2addr = join '/', epoch_b32( $v2node->{'epoch'} ), $v2node->{'amos'},
    $v2node->{'bmw'};
refused(
    sub { release_node( %v2run, address => $v2addr, force => TRUE ) },
    qr|only available for store format 3|,
    'format 2 refuses release clearly'
);

say ':: crash matrix : both retry and repair finish every point';
my @points = qw| release:before-tombstone release:after-tombstone
    release:before-journal journal:before-write journal:after-write
    release:after-journal
    release:before-rename release:after-rename release:before-remove
    release:after-remove |;
foreach my $point (@points) {
    foreach my $recovery (qw| retry repair |) {
        my ( $cdisk, %crun ) = new_disk("crash-$point-$recovery");
        my ( $cfile, $cnode, $caddr )
            = one_node( \%crun, "crash $point $recovery\n",
            "crash-$point-$recovery.txt" );
        {
            local $AMOS7::N7FS::FAULT = sub {
                die "injected crash\n" if $ARG[0] eq $point;
            };
            my $ok = eval {
                release_node( %crun, address => $caddr, force => TRUE );
                1;
            };
            ok( !$ok, "crash injected at $point [ $recovery ]" );
        }
        if ( $point eq 'release:after-journal' and $recovery eq 'repair' ) {
            refused(
                sub { store_verify( %crun, disk => $cdisk ) },
                qr|released node still present.*repair|s,
                'a journaled release still present is loud until repair'
            );
        }
        if ( $recovery eq 'retry' ) {
            my $ok = eval {
                release_node( %crun, address => $caddr, force => TRUE );
                1;
            };
            ok( $ok, "retry finishes $point" );
        } else {
            my $repair = store_repair(%crun);
            ok( ref $repair eq 'HASH', "repair returns after $point" );
        }
        my $verified = eval { store_verify( %crun, disk => $cdisk ); 1 };
        ok( $verified,
            "disk verifies after $point and $recovery : $EVAL_ERROR" );
        my $committed = $recovery eq 'retry'
            || ($point ne 'release:before-tombstone'
            and $point ne 'release:after-tombstone'
            and $point ne 'release:before-journal'
            and $point ne 'journal:before-write' );
        ok( $committed ? !-e $cnode->{'path'} : -e $cnode->{'path'},
            "node presence is correct after $point and $recovery"
        );
    }
}

say ':: the same crash matrix through reclaim';
foreach my $point (@points) {
    foreach my $recovery (qw| retry repair |) {
        my ( $cdisk, %crun ) = new_disk("reclaim-$point-$recovery");
        my ( $cfile, $cnode, $caddr ) = one_node(
            \%crun,
            "reclaim $point $recovery\n",
            "reclaim-$point-$recovery.txt"
        );
        reference_drop( %crun, address => $caddr, holder => $cfile );
        {
            local $AMOS7::N7FS::FAULT = sub {
                die "injected reclaim crash\n" if $ARG[0] eq $point;
            };
            my $ok = eval { store_reclaim(%crun); 1 };
            ok( !$ok, "reclaim crash injected at $point [ $recovery ]" );
        }
        if ( $recovery eq 'retry' ) {
            my $ok = eval { store_reclaim(%crun); 1 };
            ok( $ok, "reclaim retry finishes $point" );
        } else {
            store_repair(%crun);
        }
        my $verified = eval { store_verify( %crun, disk => $cdisk ); 1 };
        ok( $verified,
                  "reclaim disk verifies after "
                . "$point and $recovery : $EVAL_ERROR" );
    }
}

say ':: import after a crash mid release';
my ( $mid_disk, %mid_run ) = new_disk('crash-import');
my ( $mid_file, $mid_node, $mid_addr )
    = one_node( \%mid_run, "mid release revival\n", 'mid.txt' );
{
    local $AMOS7::N7FS::FAULT = sub {
        die "injected crash\n" if $ARG[0] eq 'release:after-rename';
    };
    eval { release_node( %mid_run, address => $mid_addr, force => TRUE ) };
}
my $mid_import = assimilate( %mid_run, paths => [$mid_file] );
ok( $mid_import->{'failed'} == 0,
    'content import revives after a crash moved the node aside' );
store_repair(%mid_run);
ok( !-e "$root/$mid_disk/.n7fs/releasing/$mid_addr",
    'repair removes the old aside after content revival'
);
ok( store_verify( %mid_run, disk => $mid_disk ),
    'the revived disk verifies after aside cleanup'
);

say ':: concurrent release, import and reclaim';
my ( $many_disk, %many_run ) = new_disk('release-concurrency');
my ( @files, @addresses );
foreach my $n ( 1 .. 6 ) {
    my $f = write_file( "$src/concurrent-$n.txt", "concurrent $n\n" );
    assimilate( %many_run, paths => [$f] );
    my ($node)
        = grep { read_file("$ARG->{'path'}/content") eq "concurrent $n\n" }
        store_nodes( "$root/$many_disk",
        state_read("$root/$many_disk")->{'epochs'}->@* );
    my $address = join '/', epoch_b32( $node->{'epoch'} ), $node->{'amos'},
        $node->{'bmw'};
    reference_drop( %many_run, address => $address, holder => $f );
    push @files,     $f;
    push @addresses, $address;
}
my @workers;
foreach my $n ( 0 .. 5 ) {
    my $pid = fork // die "fork : $OS_ERROR";
    if ( not $pid ) {
        my $ok = eval {
            if ( $n % 3 == 0 ) {
                store_reclaim(%many_run);
            } elsif ( $n % 3 == 1 ) {
                assimilate( %many_run, paths => [ $files[$n], $files[0] ] );
            } else {
                release_node(
                    %many_run,
                    address => $addresses[$n],
                    force   => TRUE
                );
            }
            1;
        };
        POSIX::_exit( $ok ? 0 : 1 );
    }
    push @workers, $pid;
}
my $failed = grep { waitpid( $ARG, 0 ); $CHILD_ERROR != 0 } @workers;
ok( $failed == 0, 'concurrent reclaim, import and release paths all finish' );
ok( store_verify( %many_run, disk => $many_disk ),
    'concurrent release, import and reclaim leave a verifying disk' );

say ':: early previous-epoch release';
my ( $conv_disk, %conv_run ) = new_disk('release-epoch');
my $E = epoch_int( clock_now() );
{
    my $p = state_read("$root/$conv_disk");
    delete $p->{'_name'};
    $p->{'store_format'} = 2;
    state_write( "$root/$conv_disk", $p,
        key_file_signer("$hdir/stores/$conv_disk.store.key") );
}
my $cf = write_file( "$src/epoch.txt", 'epoch release' );
assimilate( %conv_run, paths => [$cf], allow_rollback => TRUE );
$conv_run{'allow_rollback'} = TRUE;
clock_epoch( $E + 1 );
upgrade( %conv_run, target => 3 );
refused( sub { release_epoch( %conv_run, epoch => $E ) },
    qr|needs -now|, 'release-epoch requires -now' );
refused(
    sub { release_epoch( %conv_run, epoch => $E, now => TRUE ) },
    qr|not confirmed|,
    'release-epoch refuses an unconfirmed conversion'
);
confirm(%conv_run);
my $active_epoch = state_read("$root/$conv_disk")->{'epochs'}[0];
refused(
    sub { release_epoch( %conv_run, epoch => $active_epoch, now => TRUE ) },
    qr|active epoch cannot be released|,
    'release-epoch refuses the active epoch explicitly'
);
my $old_epoch = "$root/$conv_disk/" . epoch_b32($E);
my $er        = release_epoch( %conv_run, epoch => $E, now => TRUE );
ok( $er->{'epoch'} == $E && !-e $old_epoch,
    'confirmed previous epoch is removed before leaving the window' );
clock_epoch( $E + 2 );
my $next = upgrade( %conv_run, target => 3 );
ok( $next->{'from'} == 3 && $next->{'to'} == 3,
    'upgrade no longer refuses because the old form is in the window' );
ok( store_verify( %conv_run, disk => $conv_disk ),
    'disk verifies after early epoch release'
);

my ( $epoch2_disk, %epoch2_run ) = new_disk('release-epoch-format2');
{
    my $path         = "$root/$epoch2_disk";
    my ($state_file) = glob "$path/.n7fs/state/*.state";
    my $p            = state_read($path);
    delete $p->{'_name'};
    $p->{'store_format'} = 1;
    unlink $state_file or die "unlink state : $OS_ERROR";
    write_file( $state_file, plain_record_pack( 'state', $p ) );
}
my $epoch2_file = write_file( "$src/epoch2.txt", 'format 2 upgrade next' );
assimilate( %epoch2_run, paths => [$epoch2_file], allow_rollback => TRUE );
$epoch2_run{'allow_rollback'} = TRUE;
my $E2 = state_read("$root/$epoch2_disk")->{'epochs'}[0];
clock_epoch( $E2 + 1 );
upgrade( %epoch2_run, target => 2 );
confirm(%epoch2_run);
release_epoch( %epoch2_run, epoch => $E2, now => TRUE );
clock_epoch( $E2 + 2 );
my $epoch2_upgrade = upgrade( %epoch2_run, target => 3 );
ok( $epoch2_upgrade->{'from'} == 2 && $epoch2_upgrade->{'to'} == 3,
    'format 2 upgrades after format 1 is released inside the window'
);
confirm(%epoch2_run);
ok( store_verify( %epoch2_run, disk => $epoch2_disk ),
    'the resulting format 3 conversion verifies'
);

say ':: regressions found by review';
{
    my ( $d, %r ) = new_disk('review-reason');
    my ( undef, undef, $a ) = one_node( \%r, "empty reason\n", 'reason.txt' );
    release_node( %r, address => $a, force => TRUE, reason => '' );
    ok( store_verify(%r),
        'an empty reason cannot make an unreadable tombstone' );
    my $id = disk_read_id( %base, disk => $d );
    ok( tombstone_latest( $id, $a )->{'reason'} eq 'explicit release',
        'an empty reason becomes the default' );

    my ($t) = glob "$root/$d/.n7fs/tombstones/*.tombstone";
    my $kept = read_file($t);
    unlink $t;
    refused(
        sub { store_verify(%r) },
        qr|missing tombstone|,
        'verify fails loudly on a lost tombstone'
    );
    write_file( $t, $kept );
    ok( store_verify(%r), 'a restored tombstone verifies again' );
}
{
    my ( $d, %r ) = new_disk('review-aside');
    my ( $f, undef, $a ) = one_node( \%r, "stale aside\n", 'aside.txt' );
    {
        local $AMOS7::N7FS::FAULT = sub {
            die "crash\n" if $ARG[0] eq 'release:before-remove';
        };
        eval { release_node( %r, address => $a, force => TRUE ) };
    }
    ok( -e "$root/$d/.n7fs/releasing/$a", 'the crash left an aside' );
    assimilate( %r, paths => [$f] );
    ok( store_verify(%r),
        'the revived node verifies beside the stale aside' );
    release_node( %r, address => $a, force => TRUE );
    ok( !-e "$root/$d/.n7fs/releasing/$a" && store_verify(%r),
        'a stale aside does not block the next release'
    );
}
{
    my ( $d, %r ) = new_disk('review-copies');
    my $E = epoch_int( clock_now() );
    my $p = state_read("$root/$d");
    delete $p->{'_name'};
    $p->{'store_format'} = 2;
    state_write( "$root/$d", $p,
        key_file_signer("$hdir/stores/$d.store.key") );
    $r{'allow_rollback'} = TRUE;
    my $body = "held by the previous form\n";
    assimilate( %r, paths => [ write_file( "$src/copies.txt", $body ) ] );
    clock_epoch( $E + 1 );
    upgrade( %r, target => 3 );
    confirm(%r);
    my $st = state_read("$root/$d");
    my ($n)
        = grep { read_file("$ARG->{'path'}/content") eq $body }
        store_nodes( "$root/$d", $st->{'epochs'}->@* );
    my $a   = join '/', epoch_b32( $n->{'epoch'} ), $n->{'amos'}, $n->{'bmw'};
    my $res = release_node( %r, address => $a, force => TRUE );
    ok( scalar $res->{'copies'}->@* == 1,
        'release names the copy the previous form still holds' );
    release_epoch( %r, epoch => $E, now => TRUE );
    clock_real();
}

done();

#,,.,,,.,,,..,.,.,,,.,.,.,,.,,...,,,,,..,,,,.,..,,...,...,.,.,..,,.,.,,,.,.,.,
#N65X6LPZSSQPSGPMJBSYY4WBXMLTSFUHDJOQ25LXRPML7JC3IONER4QPULGYLWFCTJG5WSLJLB6HI
#\\\|U2ITCM7O5MT5ECL2DS3S7EVLIPJA4CKV25W33URQDNMKLDCKAEP \ / AMOS7 \ YOURUM ::
#\[7]HC67TTS3YUFAE2KRD6KOET5XCUEU7RF3IJSXEKIWOKZ64PNEISAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
