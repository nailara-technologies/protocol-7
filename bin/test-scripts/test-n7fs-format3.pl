#!/usr/bin/perl
use v5.32.0;
use strict;
use POSIX ();
use English;
use warnings;

## N7FS store format 3 : signed journal, references, crash repair and witness
## rollback checks. every path is below File::Temp directories.  perl
## bin/test-scripts/test-n7fs-format3.pl

use FindBin;

BEGIN {
    unshift @INC, "$FindBin::Bin/../../data/lib-path/pm";
    unshift @INC, $ENV{'N7FS_TEST_LIB'} if $ENV{'N7FS_TEST_LIB'};
}

use AMOS7::N7FS qw| read_file signed_record_pack signed_record_parse
    remove_tree publish_dir make_dirs ntime14 |;
use AMOS7::N7FS::Sum
    qw| bmw_b32 bmw384_bytes amos_of_bmw epoch_b32 epoch_int |;
use AMOS7::N7FS::Sign qw| verify key_file_write key_file_signer new_seed |;
use AMOS7::N7FS::Disk qw| disk_init disk_attach disk_detach disk_read_id
    disk_status state_read witness_read |;
use AMOS7::N7FS::Store qw| assimilate store_verify store_nodes meta_entries
    reference_entries reference_drop store_repair codec |;
use AMOS7::N7FS::Journal qw| journal_replay journal_head journal_write |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

use constant TRUE  => 5;
use constant FALSE => 0;

my $box    = sandbox();
my $root   = $box->{'root'};
my $hdir   = $box->{'host'};
my $src    = $box->{'src'};
my $parent = test_signer();
my $host   = key_file_write("$hdir/host.key");
my $seed   = new_seed();
my %base   = ( root => $root, host_dir => $hdir );
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

sub replace_bytes {
    my ( $path, $bytes ) = @ARG;
    chmod 0600, $path;
    write_file( $path, $bytes );
}

my $disk = disk_init(
    %base,
    parent     => $parent,
    store_seed => $seed,
    name       => 'format3-test',
    intent     => 'n7fs format 3 security tests [ test data ]'
);
my %run   = ( %base, disk => $disk, host => $host );
my $dpath = "$root/$disk";
disk_attach(%run);
my $f1    = write_file( "$src/one.txt", "test data : format 3 one\n" );
my $f2    = write_file( "$src/two.txt", "test data : format 3 two\n" );
my $r     = assimilate( %run, paths => [ $f1, $f2 ] );
my $id    = disk_read_id( %base, disk => $disk );
my $st    = state_read($dpath);
my $epoch = $st->{'epochs'}[0];
my @nodes = store_nodes( $dpath, $epoch );
my %node_by_content
    = map { read_file("$ARG->{'path'}/content") => $ARG } @nodes;
my $n1 = $node_by_content{"test data : format 3 one\n"};
my $n2 = $node_by_content{"test data : format 3 two\n"};
my $a1 = join '/', epoch_b32($epoch), $n1->{'amos'}, $n1->{'bmw'};

say ':: signed records, one batch entry and reference-bound reads';
ok( $st->{'store_format'} == 3, 'new disk uses store format 3' );
ok( $r->{'journal_seq'} == 1 && journal_head($id)->{'seq'} == 1,
    'one assimilate batch writes one journal entry'
);
ok( journal_replay($id)->{'seq'} == 1 && !journal_replay($id)->{'baseline'},
    'a fresh disk has no conversion baseline' );
my ($journal_file) = glob "$dpath/.n7fs/journal/*.journal";
my $journal_bytes  = read_file($journal_file);
my $journal_rec    = signed_record_parse( 'journal', $journal_bytes );
ok( substr( $journal_bytes, 0, 5 ) eq "P7FJ\x03"
        && $journal_rec->{'payload'}{'seq'} == 1
        && $journal_rec->{'payload'}{'prev'} eq ''
        && $journal_rec->{'payload'}{'disk'} eq $disk,
    'journal : format 3, sequence 1, empty prev and disk binding'
);
ok( verify(
        $id->{'store_pub'}, $journal_rec->{'signed'},
        $journal_rec->{'sig'}
    ),
    'journal verifies only with the id-bound store public key'
);
my ($meta_file) = glob "$n1->{'path'}/meta/*.meta";
ok( substr( read_file($meta_file), 0, 5 ) eq "P7FN\x03",
    'fresh meta is signed record format 3' );
refused(
    sub { codec(2)->{'verify_node'}->( $n1->{'path'}, $n1, { id => $id } ) },
    qr|format 2|,
    'a format 3 node does not validate as format 2'
);
my $meta_bytes = read_file($meta_file);
{
    my $bad = $meta_bytes;
    substr( $bad, -1, 1 ) = chr( ord( substr( $bad, -1, 1 ) ) ^ 1 );
    replace_bytes( $meta_file, $bad );
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|store signature does not verify|,
        'a tampered format 3 meta record fails its signature'
    );
    replace_bytes( $meta_file, $meta_bytes );
}
{
    my $copied = "$n2->{'path'}/meta/99999999999999.COPIEDAA.meta";
    write_file( $copied, $meta_bytes );
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|does not match its location|,
        'a format 3 meta record moved to another node refuses'
    );
    unlink $copied or die "unlink copied meta : $OS_ERROR";
}
my @refs = reference_entries( %base, disk => $disk );
ok( @refs == 2 && !grep( { $ARG->{'dropped'} } @refs ),
    'assimilate creates two live references'
);
my ($ref1) = grep { $ARG->{'holder'} eq $f1 } @refs;
ok( $ref1->{'name'} eq 'one.txt'
        && $ref1->{'node'} eq $a1
        && $ref1->{'path'}
        =~ m|\A\d{14}/\Q$n1->{'amos'}\E/\Q$n1->{'bmw'}\E/addr\z|,
    'reference holder is the absolute source and its path names the target'
);
my $ref_bytes = read_file( $ref1->{'full_path'} );
my $ref_rec   = signed_record_parse( 'reference', $ref_bytes );
ok( substr( $ref_bytes, 0, 5 ) eq "P7FR\x03"
        && verify( $id->{'store_pub'}, $ref_rec->{'signed'},
        $ref_rec->{'sig'} ),
    'reference uses the signed format 3 reference record'
);
ok( witness_read(%run)->{'journal_seq'} == 1,
    'assimilate advances the host journal witness after the entry' );

my $repeat_before = snapshot( $root, $hdir, $src );
my $repeat        = assimilate( %run, paths => [ $f1, $f2 ] );
ok( !defined $repeat->{'journal_seq'}
        && snap_equal( $repeat_before, snapshot( $root, $hdir, $src ) ),
    'unchanged repeat import writes no reference, meta, journal or witness'
);
my ( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'find', $disk );
ok( $cli_rc == 0 && $cli_out =~ m|/one\.txt| && $cli_out =~ m|/two\.txt|,
    'find defaults to live references' );
( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'get', $disk, 'one.txt' );
ok( $cli_rc == 0 && $cli_out eq "test data : format 3 one\n",
    'get by name resolves a live reference' );

say ':: drop, history and revival';
my $before_unknown_drop = snapshot( $root, $hdir );
refused(
    sub { reference_drop( %run, address => $a1, holder => 'unknown' ) },
    qr|unknown reference|,
    'drop of an unknown reference refuses'
);
ok( snap_equal( $before_unknown_drop, snapshot( $root, $hdir ) ),
    'unknown drop changed nothing' );
{
    my $add  = { nodes => [], meta => [], references => [] };
    my $drop = {
        nodes      => [],
        meta       => [],
        releases   => [],
        references => [
            {   node   => $a1,
                path   => "99999999999999/$n1->{'amos'}/$n1->{'bmw'}/addr",
                holder => $f1,
                name   => 'one.txt',
            }
        ],
    };
    my $before = snapshot( $root, $hdir );
    refused(
        sub {
            journal_write( $id,
                key_file_signer("$hdir/stores/$disk.store.key"),
                $add, $drop, {} );
        },
        qr|drop of a non-live reference|,
        'an invalid journal operation refuses before it is signed'
    );
    ok( snap_equal( $before, snapshot( $root, $hdir ) ),
        'the invalid journal entry changed nothing'
    );
}
( $cli_rc, $cli_out, $cli_err )
    = cli_n7fs( 'drop', $disk, $a1, '-holder', $f1 );
ok( $cli_rc == 0 && $cli_out =~ m|dropped| && $cli_out =~ m|journal 2|,
    'drop writes a signed record and journal entry, removing nothing'
);
ok( -e "$n1->{'path'}/content" && -e $meta_file,
    'drop keeps content and meta' );
( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'find', $disk );
ok( $cli_rc == 0 && $cli_out !~ m|/one\.txt| && $cli_out =~ m|/two\.txt|,
    'find hides a dropped reference by default' );
( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'find', $disk, '-all' );
ok( $cli_rc == 0 && $cli_out =~ m|/one\.txt.*dropped|,
    'find -all marks dropped history' );
( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'get', $disk, 'one.txt' );
ok( $cli_rc != 0 && $cli_err =~ m|was dropped|,
    'get by a dropped name says that it was dropped'
);
( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'get', $disk, 'one.txt', '-all' );
ok( $cli_rc == 0 && $cli_out eq "test data : format 3 one\n",
    'get -all can resolve dropped history' );
( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'get', $disk, $a1 );
ok( $cli_rc == 0 && $cli_out eq "test data : format 3 one\n",
    'get by address still resolves dropped content'
);
{
    my $before_second_drop = snapshot( $root, $hdir );
    local *AMOS7::N7FS::Store::reference_drop_write
        = sub { die "drop writer reached\n" };
    refused( sub { reference_drop( %run, address => $a1, holder => $f1 ) },
        qr|not live|,
        'a second drop refuses before calling the drop writer' );
    ok( snap_equal( $before_second_drop, snapshot( $root, $hdir ) ),
        'non-live drop changed nothing' );
}
my $revived = assimilate( %run, paths => [$f1] );
ok( $revived->{'journal_seq'} == 3,
    're-import of a dropped source writes a new reference and entry' );
@refs = reference_entries( %base, disk => $disk );
my @one_refs = grep { $ARG->{'holder'} eq $f1 } @refs;
ok( @one_refs == 2
        && 1 == grep( { $ARG->{'dropped'} } @one_refs )
        && 1 == grep( { !$ARG->{'dropped'} } @one_refs ),
    'revival keeps the dropped record and adds a distinct live reference'
);
( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'get', $disk, 'one.txt' );
ok( $cli_rc == 0, 'the revived name resolves again' );
my $f3 = write_file( "$src/three.txt", "test data : format 3 three\n" );
assimilate( %run, paths => [$f3] );
ok( journal_head($id)->{'seq'} == 4, 'a later batch advances sequence to 4' );

say ':: deletion and journal replay failures';
{
    my $backup = "$box->{'base'}/node.saved";
    copy_tree( $n1->{'path'}, $backup );
    remove_tree( $n1->{'path'} );
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|missing node \Q$a1\E|,
        'deleted node is a loud missing-node failure'
    );
    copy_tree( $backup, $n1->{'path'} );
}
ok( store_verify( %base, disk => $disk )->{'nodes'} == 3,
    'restored node verifies' );
{
    my $bytes = read_file($meta_file);
    unlink $meta_file or die "unlink meta : $OS_ERROR";
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|missing meta .*\.meta|,
        'deleted meta is a loud missing-meta failure'
    );
    write_file( $meta_file, $bytes );
}
{
    my $bytes = read_file( $ref1->{'full_path'} );
    unlink $ref1->{'full_path'} or die "unlink reference : $OS_ERROR";
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|missing reference|,
        'deleted reference is a loud missing-reference failure'
    );
    write_file( $ref1->{'full_path'}, $bytes );
}

my @jfiles     = sort glob "$dpath/.n7fs/journal/*.journal";
my $tail_bytes = read_file( $jfiles[-1] );
unlink $jfiles[-1] or die "unlink journal tail : $OS_ERROR";
refused(
    sub { store_verify( %run, disk => $disk ) },
    qr|journal sequence 3 is below the witnessed highest 4|,
    'deleted journal tail is caught by the host witness'
);
refused(
    sub { store_verify( %run, disk => $disk, allow_rollback => TRUE ) },
    qr|unlisted|,
    'allow-rollback does not hide the resulting unlisted disk data'
);
refused( sub { store_verify( %base, disk => $disk ) },
    qr|unlisted|,
    'deleted tail without a witness is caught by disk-set comparison' );
write_file( $jfiles[-1], $tail_bytes );
ok( store_verify( %run, disk => $disk )->{'journal'}{'seq'} == 4,
    'restored journal verifies again' );

my $tail_payload = signed_record_parse( 'journal', $tail_bytes )->{'payload'};
my $empty_add    = { nodes => [], meta => [], references => [] };
my $empty_drop
    = { nodes => [], meta => [], references => [], releases => [] };
my $tail_prev    = bmw_b32( bmw384_bytes($tail_bytes) );
my $store_signer = key_file_signer("$hdir/stores/$disk.store.key");
{
    my $fork = "$dpath/.n7fs/journal/99999999999998.journal";
    write_file(
        $fork,
        signed_record_pack(
            'journal',
            {   seq  => 5,
                prev => $tail_payload->{'prev'},
                disk => $disk,
                add  => $empty_add,
                drop => $empty_drop,
            },
            $store_signer,
            3
        )
    );
    refused( sub { store_verify( %base, disk => $disk ) },
        qr|fork|,
        'a second successor of one journal entry is a loud fork refusal' );
    unlink $fork or die "unlink fork : $OS_ERROR";
}
{
    my $b0 = read_file( $jfiles[0] );
    my $b1 = read_file( $jfiles[1] );
    replace_bytes( $jfiles[0], $b1 );
    replace_bytes( $jfiles[1], $b0 );
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|sequence is not contiguous|,
        'reordered journal entries refuse'
    );
    replace_bytes( $jfiles[0], $b0 );
    replace_bytes( $jfiles[1], $b1 );
}
{
    my $bad = $tail_bytes;
    substr( $bad, -1, 1 ) = chr( ord( substr( $bad, -1, 1 ) ) ^ 1 );
    replace_bytes( $jfiles[-1], $bad );
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|store signature does not verify|,
        'a tampered journal entry fails its signature'
    );
    replace_bytes( $jfiles[-1], $tail_bytes );
}
{
    my $bad_seq = "$dpath/.n7fs/journal/99999999999996.journal";
    write_file(
        $bad_seq,
        signed_record_pack(
            'journal',
            {   seq  => 6,
                prev => $tail_prev,
                disk => $disk,
                add  => $empty_add,
                drop => $empty_drop,
            },
            $store_signer,
            3
        )
    );
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|sequence is not contiguous|,
        'a signed gap in journal sequence refuses'
    );
    unlink $bad_seq or die "unlink bad sequence : $OS_ERROR";
}
{
    my $bad_prev = "$dpath/.n7fs/journal/99999999999995.journal";
    write_file(
        $bad_prev,
        signed_record_pack(
            'journal',
            {   seq  => 5,
                prev => 'A' x 77,
                disk => $disk,
                add  => $empty_add,
                drop => $empty_drop,
            },
            $store_signer,
            3
        )
    );
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|previous-entry checksum does not match|,
        'a signed wrong previous-entry checksum refuses'
    );
    unlink $bad_prev or die "unlink bad prev : $OS_ERROR";
}
{
    my $bad_disk = "$dpath/.n7fs/journal/99999999999994.journal";
    write_file(
        $bad_disk,
        signed_record_pack(
            'journal',
            {   seq  => 5,
                prev => $tail_prev,
                disk => 'AAAAAAA',
                add  => $empty_add,
                drop => $empty_drop,
            },
            $store_signer,
            3
        )
    );
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|disk binding does not match|,
        'a validly signed journal entry for another disk refuses'
    );
    unlink $bad_disk or die "unlink bad disk : $OS_ERROR";
}
{
    my $foreign = "$dpath/.n7fs/journal/99999999999997.journal";
    write_file(
        $foreign,
        signed_record_pack(
            'journal',
            {   seq  => 5,
                prev => $tail_prev,
                disk => $disk,
                add  => $empty_add,
                drop => $empty_drop,
            },
            test_signer(),
            3
        )
    );
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|foreign store key|,
        'a journal record signed by a foreign key refuses'
    );
    unlink $foreign or die "unlink foreign journal : $OS_ERROR";
}
{
    my $bad = $ref_bytes;
    substr( $bad, -1, 1 ) = chr( ord( substr( $bad, -1, 1 ) ) ^ 1 );
    replace_bytes( $ref1->{'full_path'}, $bad );
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|store signature does not verify|,
        'a tampered reference fails its signature'
    );
    replace_bytes( $ref1->{'full_path'}, $ref_bytes );
}
{
    my $foreign = signed_record_pack( 'reference',
        $ref_rec->{'payload'}, test_signer(), 3 );
    replace_bytes( $ref1->{'full_path'}, $foreign );
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|foreign store key|,
        'a reference signed by a foreign key refuses'
    );
    replace_bytes( $ref1->{'full_path'}, $ref_bytes );
}

say ':: reference location binding';
{
    my $planted = "$n2->{'path'}/references/99999999"
        . "999999/$n2->{'amos'}/$n2->{'bmw'}";
    make_dirs($planted);
    write_file( "$planted/addr", $ref_bytes );
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|addr does not match its path|,
        'a reference moved to another target refuses'
    );
    remove_tree("$n2->{'path'}/references/99999999999999");
}
{
    my $disk2 = disk_init(
        %base,
        parent     => $parent,
        store_seed => $seed,
        name       => 'format3-other-disk',
        intent     => 'reference disk binding [ test data ]'
    );
    my %run2 = ( %base, disk => $disk2, host => $host );
    disk_attach(%run2);
    assimilate( %run2, paths => [$f1] );
    my ($other)
        = store_nodes( "$root/$disk2",
        state_read("$root/$disk2")->{'epochs'}->@* );
    my $planted = "$other->{'path'}/references/999999999"
        . "99999/$other->{'amos'}/$other->{'bmw'}";
    make_dirs($planted);
    write_file( "$planted/addr", $ref_bytes );
    refused(
        sub { store_verify( %base, disk => $disk2 ) },
        qr|disk does not match its path|,
        'a reference copied to another disk refuses even with the same key'
    );
}

say ':: crash between publish and journal, foreign data, explicit repair';
my $f4 = write_file( "$src/crash.txt", "test data : unjournaled crash\n" );
{
    local $AMOS7::N7FS::FAULT = sub {
        die "injected crash\n" if $ARG[0] eq 'assimilate:after-publish';
    };
    my $crash = assimilate( %run, paths => [$f4] );
    ok( $crash->{'failed'} == 1, 'the publish-to-journal crash is injected' );
}
refused(
    sub { store_verify( %base, disk => $disk ) },
    qr|unlisted node .*unjournaled data from a crash|,
    'an unjournaled published node is never reported as good'
);
my ($crash_node) = grep {
    read_file("$ARG->{'path'}/content") eq "test data : unjournaled crash\n"
} store_nodes( $dpath, $epoch );
my ($crash_meta) = glob "$crash_node->{'path'}/meta/*.meta";
my $crash_meta_bytes = read_file($crash_meta);
my $crash_meta_payload
    = signed_record_parse( 'meta', $crash_meta_bytes )->{'payload'};
replace_bytes( $crash_meta,
    signed_record_pack( 'meta', $crash_meta_payload, test_signer(), 3 ) );
refused(
    sub { store_repair(%run) },
    qr|foreign store key|,
    'a signed but foreign node fails repair instead of being adopted'
);
replace_bytes( $crash_meta, $crash_meta_bytes );
( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'repair', $disk );
ok( $cli_rc == 0
        && $cli_out =~ m|adopted node \S+|
        && $cli_out =~ m|adopted meta .*\.meta|,
    'repair lists every adopted node and meta record'
);
my $replay = journal_replay($id);
ok( $replay->{'entries'}[-1]{'payload'}{'repaired'} && $replay->{'seq'} == 5,
    'repair writes a repaired:true journal entry'
);
ok( store_verify( %base, disk => $disk )->{'nodes'} == 4,
    'the explicitly repaired store verifies' );
ok( witness_read(%run)->{'journal_seq'} == 5,
    'repair advances the journal witness after the repair entry' );

say ':: old witness records have journal sequence zero';
{
    my $w = witness_read(%run);
    delete $w->{'journal_seq'};
    my $ntime = $w->{'written'} + 1;
    $w->{'written'} = ntime14($ntime);
    my $path = "$hdir/witness/$disk/$w->{'written'}.use";
    write_file( $path, signed_record_pack( 'use', $w, $host ) );
    my $read = witness_read(%run);
    ok( $read->{'journal_seq'} == 0,
        'a witness without journal_seq reads as zero' );
    ok( store_verify( %run, disk => $disk )->{'journal'}{'seq'} == 5,
        'sequence zero never rejects a newer valid journal'
    );
}

my $st_status = disk_status(%run);
ok( $st_status->{'journal_seq'} == 5 && !$st_status->{'journal_baseline'},
    'status reports journal sequence and baseline absence'
);
( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'detach', $disk );
( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'attach', $disk );
ok( $cli_rc == 0 && witness_read(%run)->{'journal_seq'} == 5,
    'detach and attach retain the highest journal witness'
);

say ':: a valid store-signed but unlisted injected node';
{
    my $body = "test data : explicitly injected node\n";
    my $file = write_file( "$src/injected.txt", $body );
    my $bmw  = bmw_b32( bmw384_bytes($body) );
    my $node = {
        epoch => $epoch,
        amos  => amos_of_bmw($bmw),
        bmw   => $bmw,
    };
    $node->{'path'} = join '/', $dpath, epoch_b32($epoch), $node->{'amos'},
        $bmw;
    my $tmp = "$node->{'path'}.tmp.INJECTAA";
    make_dirs( $node->{'path'} =~ s|/[^/]+\z||r );
    make_dirs($tmp);
    my $meta = {
        name         => 'injected.txt',
        format       => 'txt',
        size         => length($body),
        mtime        => ( stat $file )[9],
        import_ntime => ntime14( clock_now() ),
        epoch        => epoch_b32($epoch),
        source       => $file,
        host         => 'test',
        amos         => $node->{'amos'},
        bmw          => $bmw,
        disk         => $disk,
    };
    codec(3)->{'write_node'}->(
        $tmp,
        {   addr         => $node,
            content_path => $file,
            metas        => [$meta],
        },
        { id => $id, store => $store_signer }
    );
    publish_dir( $tmp, $node->{'path'} );
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|unlisted node|,
        'a valid store-signed but unlisted injected node still fails verify'
    );
    my $repair = store_repair(%run);
    ok( 2 == $repair->{'adopted'}->@*
            && $repair->{'adopted'}[0]{'type'} eq 'node'
            && $repair->{'adopted'}[1]{'type'} eq 'meta',
        'explicit repair reports the injected '
            . 'node and its meta before adopting'
    );
    ok( store_verify( %base, disk => $disk )->{'journal'}{'seq'} == 6,
        'the explicitly reported injection verifies after repair'
    );
}

say ':: readers need no store secret and writers refuse before changing';
{
    my $key  = "$hdir/stores/$disk.store.key";
    my $save = "$box->{'base'}/format3-store-key.saved";
    rename $key, $save or die "rename store key : $OS_ERROR";
    my $no_key_source = write_file( "$src/no-key.txt", 'no key' );
    my $before        = snapshot( $root, $hdir, $src );
    foreach my $command (
        [ 'get',    $disk, $a1 ],
        [ 'find',   $disk ],
        [ 'verify', $disk ],
        [ 'status', $disk ],
    ) {
        my ( $rc, $out, $err ) = cli_n7fs( $command->@* );
        ok( $rc == 0 && $err eq '',
            "$command->[0] verifies with only "
                . "the parent-signed store public key"
        );
    }
    refused(
        sub { assimilate( %run, paths => [$no_key_source] ) },
        qr|no delegated store key|,
        'format 3 assimilate without the store key refuses'
    );
    refused(
        sub { reference_drop( %run, address => $a1, holder => $f1 ) },
        qr|no delegated store key|,
        'format 3 drop without the store key refuses'
    );
    refused(
        sub { store_repair(%run) },
        qr|no delegated store key|,
        'format 3 repair without the store key refuses'
    );
    ok( snap_equal( $before, snapshot( $root, $hdir, $src ) ),
        'all missing-key write refusals changed nothing'
    );
    rename $save, $key or die "restore store key : $OS_ERROR";
}

say ':: a retry after a crash and concurrent writers cannot end the chain';
my $f9 = write_file( "$src/retry.txt", "test data : crash then retry\n" );
{
    local $AMOS7::N7FS::FAULT = sub {
        die "injected crash\n" if $ARG[0] eq 'assimilate:after-publish';
    };
    assimilate( %run, paths => [$f9] );
}
my $retry = assimilate( %run, paths => [$f9] );
ok( $retry->{'failed'} == 1
        && $retry->{'entries'}[0]{'why'} =~ m|not journaled|,
    'importing onto an unjournaled node refuses and names repair'
);
store_repair(%run);
ok( store_verify( %base, disk => $disk )->{'nodes'} > 0,
    'the chain still replays, repair adopted the node'
);
ok( assimilate( %run, paths => [$f9] )->{'failed'} == 0,
    'the retry works after repair' );

my $same_a
    = write_file( "$src/same-a.txt", "test data : one batch, same bytes\n" );
my $same_b
    = write_file( "$src/same-b.txt", "test data : one batch, same bytes\n" );
my $same = assimilate( %run, paths => [ $same_a, $same_b ] );
ok( $same->{'failed'} == 0,
    'a second source of a node new in this batch is not refused' );
ok( store_verify( %base, disk => $disk ), 'and that batch verifies' );

my @writers;
foreach my $n ( 1 .. 6 ) {
    my $path = write_file( "$src/writer-$n.txt", "test data : writer $n\n" );
    my $pid  = fork // die "fork : $OS_ERROR\n";
    if ( not $pid ) {
        my $ok
            = eval { assimilate( %run, paths => [$path] )->{'failed'} == 0 };
        POSIX::_exit( $ok ? 0 : 1 );
    }
    push @writers, $pid;
}
my $writers_failed = grep { waitpid( $ARG, 0 ); $CHILD_ERROR != 0 } @writers;
ok( $writers_failed == 0, 'six concurrent writers all succeed' );
ok( store_verify( %base, disk => $disk ), 'and the journal has no fork' );

{
    my $bad_id = AMOS7::N7FS::Disk::disk_read_id( %base, disk => $disk );
    my $signer = AMOS7::N7FS::Disk::store_key_signer( %run, id => $bad_id );
    my $none   = sub {
        { nodes => [], meta => [], references => [], releases => [] }
    };
    my $add    = $none->();
    my $nobody = 'V7L36QQ/AAAAAAA/' . ( 'A' x 77 );
    $add->{'references'} = [
        {   node   => $nobody,
            holder => 'x',
            name   => 'x',
            path   => '03237364882853/AAAAAAA/' . ( 'A' x 77 ) . '/addr'
        }
    ];
    refused(
        sub {
            AMOS7::N7FS::Journal::journal_write( $bad_id, $signer, $add,
                $none->(), {} );
        },
        qr|unlisted node|,
        'an entry replay would refuse is never signed'
    );
    ok( store_verify( %base, disk => $disk ), 'and nothing was written' );
}

done();

#,,,,,,,.,..,,,,.,...,,.,,.,,,,,,,,,,,,.,,,.,,.,.,...,...,...,,,.,.,,,,..,,,.,
#A4YA2TL2Y5GKMFTBPEV27NEWXWBATYZFF7LPC6CRBUID2R7X6SK5XT4B5A3TNLQNNFDXVYXQXETAS
#\\\|XE3G4NX5FW64JBZWRAN7FSL2S77VRRKO6UGFHYWIO6UVCDZSGWN \ / AMOS7 \ YOURUM ::
#\[7]75A6R77PWXIWXNH3YYMGJJ3ICLIEUXJUILNGCLTCFZOFWJEY74CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
