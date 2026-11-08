#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## incoming pool CLI, batch assignment crash recovery and scale measurements.

use FindBin;

BEGIN {
    unshift @INC, "$FindBin::Bin/../../data/lib-path/pm";
    unshift @INC, $ENV{'N7FS_TEST_LIB'} if $ENV{'N7FS_TEST_LIB'};
}

use Time::HiRes qw| time |;
use AMOS7::N7FS qw| read_file signed_record_pack signed_record_parse make_dirs
    ntime_now ntime14 b32 random_bytes |;
use AMOS7::N7FS::Sign     qw| key_file_write key_file_signer |;
use AMOS7::N7FS::Disk     qw| disk_init disk_attach disk_read_id |;
use AMOS7::N7FS::Store    qw| store_verify meta_entries |;
use AMOS7::N7FS::Journal  qw| journal_replay journal_write |;
use AMOS7::N7FS::Incoming qw| incoming_tag |;
use AMOS7::N7FS::Batch    qw| batch_read batch_write |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";
use constant TRUE => 5;

my $box = sandbox();
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
my $host = key_file_write("$hdir/host.key");
my %base = ( root => $root, host_dir => $hdir );
clock_real();
my $disk = disk_init(
    %base,
    parent => test_signer(),
    name   => 'incoming-test',
    intent => 'incoming pool tests'
);
my %run = ( %base, disk => $disk, host => $host );
disk_attach(%run);
my $id    = disk_read_id( %base, disk => $disk );
my $store = key_file_signer("$hdir/stores/$disk.store.key");

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

sub pool_count {
    my $replay = journal_replay($id);
    my $count  = 0;
    foreach my $key ( keys $replay->{'references'}->%* ) {
        next if $replay->{'references'}{$key}{'dropped'};
        $count++
            if ( $replay->{'assignments'}{$key}{'category'} // 'default' ) eq
            'incoming';
    }
    return $count;
}

my ( $rc, $out, $err ) = cli_n7fs( 'incoming', $disk, 'done' );
ok( $rc == 0 && $out =~ m|0 references, 0 bytes \[ empty \]|,
    'incoming done is zero and says empty on a new disk'
);
( $rc, $out ) = cli_n7fs( 'incoming', $disk, 'list' );
ok( $rc == 0 && $out =~ m|incoming 0 references|,
    'incoming list handles the empty pool'
);
( $rc, $out, $err )
    = cli_n7fs( 'incoming', $disk, 'tag', 'nothing', 'default' );
ok( $rc != 0 && $err =~ m|no pool references match|,
    'tag of nothing refuses clearly' );
( $rc, $out, $err ) = cli_n7fs( 'incoming', $disk, 'tag', '*', 'missing' );
ok( $rc != 0 && $err =~ m|unknown category|,
    'tag refuses an unknown category before matching'
);
( $rc, $out ) = cli_n7fs( 'category', $disk, 'list' );
ok( $rc == 0
        && $out =~ m|incoming local-encryption=none copies=2 priority=50|,
    'built-in incoming category has copies two and priority fifty'
);
( $rc, $out )
    = cli_n7fs( 'category', $disk, 'set', 'incoming', '-copies', 3 );
( $rc, $out ) = cli_n7fs( 'category', $disk, 'list' );
ok( $rc == 0
        && $out =~ m|incoming local-encryption=none copies=3 priority=50|,
    'category set incoming versions the built-in policy'
);

say ':: several roots, re-import, grouping and raw paths';
my $root_a = "$src/root-a";
my $root_b = "$src/root-b";
make_dirs("$root_a/sub");
make_dirs($root_b);
write_file( "$root_a/sub/one", 'aa' );
write_file( "$root_a/sub/two", 'bbbb' );
write_file( "$root_b/three",   'ccc' );
my $raw_name = "raw-\xFF-\x80";
my $raw_file = "$raw_name/file";
make_dirs("$root_b/$raw_name");
write_file( "$root_b/$raw_file", 'zz' );
my $single = write_file( "$src/single", 'q' );
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $disk, '-incoming',
    "$src/no-such-root", $root_a, $root_b, $single );
ok( $rc != 0
        && $err =~ m|no-such-root|
        && $out =~ m|tree incoming:.*root-a|
        && $out =~ m|tree incoming:.*root-b|,
    'one failing root does not stop later roots and exits nonzero'
);
ok( pool_count() == 5, 'all readable roots and the single file enter once' );
my $before_reimport = journal_replay($id)->{'seq'};
( $rc, $out )
    = cli_n7fs( 'assimilate', '-disk', $disk, '-incoming',
    $root_a, $root_b, $single );
ok( $rc == 0 && pool_count() == 5,
    'safe re-import does not double-count the pool' );
( $rc, $out ) = cli_n7fs( 'incoming', $disk, 'list' );
ok( $rc == 0
        && $out =~ m|2 6 \Q$root_a/sub\E|
        && index( $out, "$root_b/$raw_name" ) >= 0,
    'list groups counts and bytes and prints non-utf-8 paths by bytes'
);
( $rc, $out ) = cli_n7fs( 'incoming', $disk, 'list', '-under', $root_a );
ok( $rc == 0 && $out =~ m|2 6 \Q$root_a/sub\E| && $out !~ m|root-b|,
    'list -under filters by raw path prefix' );
( $rc, $out )
    = cli_n7fs( 'incoming', $disk, 'list', '-depth', 1, '-limit', 1 );
ok( $rc == 0 && 2 == scalar( split m|\n|, $out ),
    'list -depth and -limit return one group plus the summary' );
( $rc, $out ) = cli_n7fs( 'status', $disk );
ok( $rc == 0 && $out =~ m|incoming\s+5 references, 12 bytes|,
    'status shows current pool count and bytes' );

say ':: prefix, glob and address tagging';
( $rc, $out ) = cli_n7fs( 'incoming', $disk, 'tag', $root_a, 'default' );
ok( $rc == 0
        && $out =~ m|tagged 2 references, 6 bytes as default|
        && pool_count() == 3,
    'prefix tag moves exactly matching references and bytes'
);
my @batch_files
    = glob "$root/$disk/.n7fs/batch-ass" . "ignments/*.batch-assignment";
ok( @batch_files == 1,
    'one prefix tag writes one batch record, not per-reference records' );
( $rc, $out ) = cli_n7fs( 'incoming', $disk, 'tag', '*three', 'default' );
ok( $rc == 0 && $out =~ m|tagged 1 references, 3 bytes| && pool_count() == 2,
    'glob tag moves the matching reference'
);
my ($raw_ref)
    = grep { $ARG->{'holder'} eq "$root_b/$raw_file" }
    values journal_replay($id)->{'references'}->%*;
( $rc, $out )
    = cli_n7fs( 'incoming', $disk, 'tag', $raw_ref->{'node'}, 'default' );
ok( $rc == 0 && $out =~ m|tagged 1 references, 2 bytes| && pool_count() == 1,
    'address tag moves the raw-named reference'
);
( $rc, $out ) = cli_n7fs( 'set-category', $disk, $single, 'default' );
ok( $rc != 0, 'set-category rejects a non-address selector' );
( $rc, $out ) = cli_n7fs( 'set-category', $disk, "tree:$single", 'default' );
ok( $rc == 0 && pool_count() == 0,
    'set-category also moves a reference out of incoming' );
( $rc, $out ) = cli_n7fs( 'incoming', $disk, 'done' );
ok( $rc == 0 && $out =~ m|empty|,
    'done returns zero when the pool is empty' );
( $rc, $out, $err )
    = cli_n7fs( 'incoming', $disk, 'tag', $root_a, 'default' );
ok( $rc != 0 && $err =~ m|no pool references match|,
    'tag after the pool is empty refuses zero matches'
);

say ':: remove and dedup with another category';
my $remove_root = "$src/remove";
make_dirs($remove_root);
write_file( "$remove_root/file", 'remove me' );
( $rc, $out )
    = cli_n7fs( 'assimilate', '-disk', $disk, '-incoming', '-remove',
    $remove_root );
ok( $rc == 0 && !-e "$remove_root/file" && pool_count() == 1,
    'incoming -remove preserves the verified-source removal guarantee'
);
my $dedup_in    = write_file( "$src/dedup-in",    'shared bytes' );
my $dedup_other = write_file( "$src/dedup-other", 'shared bytes' );
( $rc, $out )
    = cli_n7fs( 'assimilate', '-disk', $disk, '-incoming', $dedup_in );
( $rc, $out )
    = cli_n7fs( 'assimilate', '-disk', $disk, '-category', 'default',
    $dedup_other );
ok( $rc == 0 && pool_count() == 2,
    'deduplicated content keeps separate incoming and default references' );
my ($dedup_ref)
    = grep { $ARG->{'holder'} eq $dedup_in }
    values journal_replay($id)->{'references'}->%*;
( $rc, $out )
    = cli_n7fs( 'incoming', $disk, 'tag', $dedup_ref->{'node'}, 'default' );
ok( $rc == 0 && pool_count() == 1,
    'address tag moves only the incoming dedup reference' );
( $rc, $out ) = cli_n7fs( 'incoming', $disk, 'tag', '*', 'default' );
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $disk, '-incoming',
    '-tree', 'bad', $root_a );
ok( $rc != 0 && $err =~ m|excludes|,
    'incoming excludes an explicit tree through the CLI' );
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $disk, '-incoming',
    '-category', 'default', $root_a );
ok( $rc != 0 && $err =~ m|excludes|,
    'incoming excludes an explicit category through the CLI' );

say ':: batch crash, quarantine, tamper and CLI repair';
## sorted references stay sorted on re-import : the fixture needs fresh ##
## roots                                                                ##
foreach my $name (qw| a b |) {
    my $fresh = "$src/crash-$name";
    make_dirs($fresh);
    write_file( "$fresh/$ARG", "crash $name $ARG" ) for qw| one two |;
}
( $root_a, $root_b ) = ( "$src/crash-a", "$src/crash-b" );
( $rc,     $out )
    = cli_n7fs( 'assimilate', '-disk', $disk, '-incoming', $root_a, $root_b );
ok( $rc == 0 && pool_count() == 4, 'crash fixture enters the pool' );
{
    local $AMOS7::N7FS::FAULT = sub {
        die "injected batch crash\n" if $_[0] eq 'batch:after-record';
    };
    refused(
        sub {
            incoming_tag(
                %run,
                selector => $root_a,
                category => 'default'
            );
        },
        qr|injected batch crash|,
        'batch fault fires between record and journal'
    );
}
( $rc, $out, $err ) = cli_n7fs( 'verify', $disk );
ok( $rc != 0 && $err =~ m|unlisted batch record|,
    'unjournaled batch record fails verify'
);
( $rc, $out ) = cli_n7fs( 'repair', $disk );
ok( $rc == 0 && $out =~ m|quarantined batch .*batch-assignment|,
    'CLI repair reports the quarantined batch by name'
);
( $rc, $out, $err ) = cli_n7fs( 'verify', $disk );
ok( $rc == 0, 'verify passes after batch quarantine' );
( $rc, $out ) = cli_n7fs( 'incoming', $disk, 'tag', $root_a, 'default' );
ok( $rc == 0 && pool_count() == 2, 'batch tag retry works after quarantine' );
( $rc, $out, $err ) = cli_n7fs( 'verify', $disk );
ok( $rc == 0, 'retry verifies with the batch assignment' );
my ($batch_path)
    = glob "$root/$disk/.n7fs/batch-ass" . "ignments/*.batch-assignment";
my $batch_bytes = read_file($batch_path);
substr( $batch_bytes, -1, 1 )
    = chr( ord( substr( $batch_bytes, -1, 1 ) ) ^ 1 );
chmod 0600, $batch_path;
write_file( $batch_path, $batch_bytes );
( $rc, $out, $err ) = cli_n7fs( 'verify', $disk );
ok( $rc != 0 && $err =~ m|signature does not verify|,
    'a tampered batch record fails verification'
);
my $batch_payload = signed_record_parse( 'batch', $batch_bytes )->{'payload'};
write_file( $batch_path,
    signed_record_pack( 'batch', $batch_payload, $store, 3 ) );
( $rc, $out, $err ) = cli_n7fs( 'verify', $disk );
ok( $rc == 0, 'restored batch signature verifies again' );
( $rc, $out ) = cli_n7fs( 'incoming', $disk, 'tag', '*', 'default' );
( $rc, $out ) = cli_n7fs( 'incoming', $disk, 'done' );
ok( $rc == 0 && pool_count() == 0,
    'final pool is empty after all tag paths' );

## selector, depth, re-import and label regressions ##
my $edge = "$src/edge";
make_dirs("$edge/foo/inner");
make_dirs("$edge/foobar");
write_file( "$edge/foo/inner/a", 'edge a' );
write_file( "$edge/foobar/b",    'edge b' );
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $disk, '-incoming', '-keep', $edge );
ok( $rc == 0 && pool_count() == 2, 'edge pool imported' );
( $rc, $out )
    = cli_n7fs( 'incoming', $disk, 'list', '-under', $edge, '-depth', '1' );
ok( $out =~ m|\Q$edge\E/foo\n| && $out =~ m|\Q$edge\E/foobar\n|,
    'depth joins the prefix and the kept component with a slash'
);
( $rc, $out ) = cli_n7fs( 'incoming', $disk, 'list', '-under', "$edge/foo" );
ok( $out !~ m|foobar|, 'list under stops at a path component' );
( $rc, $out, $err ) = cli_n7fs( 'incoming', $disk, 'tag', '', 'default' );
ok( $rc != 0 && pool_count() == 2, 'an empty selector refuses' );
( $rc, $out ) = cli_n7fs( 'incoming', $disk, 'tag', "$edge/foo", 'default' );
ok( $rc == 0 && pool_count() == 1, 'tag prefix stops at a path component' );
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $disk, '-incoming', '-keep', $edge );
ok( $rc == 0 && pool_count() == 1,
    're-import leaves a sorted reference out of the pool' );
my $odd = "$src/odd\nname \xe4";
make_dirs($odd);
write_file( "$odd/f", 'odd' );
( $rc, $out, $err )
    = cli_n7fs( 'assimilate', '-disk', $disk, '-incoming', '-keep', $odd );
( $rc, $out, $err ) = cli_n7fs( 'trees', $disk );
ok( $out =~ m|^incoming:\d{14}:odd_name_ |m,
    'a generated tree name is a one-line ascii label'
);
( $rc, $out ) = cli_n7fs( 'incoming', $disk, 'tag', '*', 'default' );
( $rc, $out, $err ) = cli_n7fs( 'verify', $disk );
ok( $rc == 0 && pool_count() == 0, 'edge pool emptied and verifies' )
    or print "rc $rc pool ", pool_count(), " err $err\n";

if ( $ENV{'N7FS_INCOMING_SCALE'} ) {
    my $count       = $ENV{'N7FS_INCOMING_SCALE'} + 0;
    my $scale_root  = "$src/scale";
    my ($base_ref)  = values journal_replay($id)->{'references'}->%*;
    my ($base_meta) = grep {
                $ARG->{'address'} eq $base_ref->{'node'}
            and $ARG->{'source'} eq $base_ref->{'holder'}
    } meta_entries(%run);
    my $node_path = "$root/$disk/$base_ref->{'node'}";
    my ( $epoch_name, $amos, $bmw ) = split m|/|, $base_ref->{'node'};
    my $add = {
        nodes      => [],
        meta       => [],
        references => [],
        batches    => [],
    };
    my $bytes = 0;
    for my $n ( 0 .. $count - 1 ) {
        my $ntime     = ntime14( ntime_now() );
        my $holder    = sprintf '%s/file-%05d', $scale_root, $n;
        my $name      = "file-$n";
        my $meta_name = "$ntime." . b32( random_bytes(5) ) . '.meta';
        my $meta      = {
            %{$base_meta},
            qw| name |         => $name,
            qw| source |       => $holder,
            qw| import_ntime | => $ntime,
            qw| epoch |        => $epoch_name,
        };
        make_dirs("$node_path/meta");
        write_file( "$node_path/meta/$meta_name",
            signed_record_pack( 'meta', $meta, $store, 3 ) );
        push $add->{'meta'}->@*,
            { node => $base_ref->{'node'}, name => $meta_name };
        my $ref_path = "$ntime/$amos/$bmw/addr";
        my $ref_dir  = "$node_path/references/$ntime/$amos/$bmw";
        make_dirs($ref_dir);
        write_file(
            "$ref_dir/addr",
            signed_record_pack(
                'reference',
                {   disk   => $disk,
                    addr   => $base_ref->{'node'},
                    holder => $holder,
                    name   => $name,
                    ntime  => $ntime,
                },
                $store, 3
            )
        );
        push $add->{'references'}->@*,
            {
            node   => $base_ref->{'node'},
            path   => $ref_path,
            holder => $holder,
            name   => $name
            };
        $bytes += $base_meta->{'size'};
    }
    my $initial = batch_write( $id, $store, 'incoming',
        $add->{'references'}, $bytes );
    push $add->{'batches'}->@*,
        { path => $initial->{'path'}, category => 'incoming' };
    journal_write( $id, $store, $add,
        { nodes => [], meta => [], references => [], releases => [] }, {} );
    die 'scale fixture failed' if pool_count() != $count;
    my $start = time;
    ( $rc, $out, $err ) = cli_n7fs( 'incoming', $disk, 'list' );
    my $list_before = time - $start;
    die "scale list failed : $err" if $rc != 0;
    $start = time;
    ( $rc, $out )
        = cli_n7fs( 'incoming', $disk, 'tag', $scale_root, 'default' );
    my $tag_time = time - $start;
    die 'scale tag failed' if $rc != 0 or pool_count() != 0;
    $start = time;
    ( $rc, $out ) = cli_n7fs( 'incoming', $disk, 'list' );
    my $list_empty = time - $start;
    die 'scale empty list failed' if $rc != 0;
    say sprintf 'SCALE %d references : list %.3f s, '
        . 'batch tag %.3f s, empty list %.3f s',
        $count, $list_before, $tag_time, $list_empty;
}

done();

#,,,.,,,,,,..,,,,,,,,,...,,..,...,,,,,,,.,,.,,..,,...,...,..,,..,,..,,,..,..,,
#SGNRBHULBE6ED7F2TQ5MHSMTFQ4TFFGJRGOIXHC3S4LQHJAGEHVG57ZTJ3OEEN5LDQFZG3SSCTP4Y
#\\\|GJKJFUJA6JEZ6CLW4S3FG4MA7TNWA4G7TW5EZ33SV425DQ4UPMN \ / AMOS7 \ YOURUM ::
#\[7]UHSYMR4CS3BMPXJDSWPZD2E5KWXBEUG3YARPQQJKNVECSQQJLUAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
