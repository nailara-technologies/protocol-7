#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

use FindBin;
use File::Copy qw| copy |;
use File::Path qw| remove_tree |;
use IPC::Open3 qw| open3 |;
use Symbol     qw| gensym |;

$^F = 100;

BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }
use JSON::PP;
use AMOS7::N7FS        qw| make_dirs read_file |;
use AMOS7::N7FS::Disk  qw| disk_init disk_attach |;
use AMOS7::N7FS::Store qw| assimilate |;
use AMOS7::N7FS::Keys  qw| root_open |;
use AMOS7::N7FS::Seal;
use AMOS7::N7FS::Drill qw| drill_records drill_latest |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

$ENV{'N7FS_TEST_PACK_LIMIT'} = 0;

my $box  = sandbox();
my $base = $box->{'base'};
make_dirs("$base/tmp");
$ENV{'TMPDIR'} = "$base/tmp";
my $key      = "$base/root.key";
my $passfile = "$base/pass";
write_file( $passfile, "drill pass\ndrill pass\n" );

sub cli {
    my @args = @ARG;
    open( my $pass, '<:raw', $passfile ) or die $OS_ERROR;
    my ( $in, $out, $err ) = ( undef, undef, gensym );
    my $pid
        = open3( $in, $out, $err, $EXECUTABLE_NAME, "$FindBin::Bin/../n7fs",
        '-pass-fd', fileno($pass), @args );
    close $in;
    my $stdout = do { local $INPUT_RECORD_SEPARATOR; <$out> }
        // '';
    my $stderr = do { local $INPUT_RECORD_SEPARATOR; <$err> }
        // '';
    waitpid $pid, 0;
    return ( $CHILD_ERROR >> 8, $stdout . $stderr );
}

sub open_root {
    my $path = shift;
    open( my $pass, '<:raw', $passfile ) or die $OS_ERROR;
    return root_open( qw| path | => $path, qw| pass_fd | => fileno($pass) );
}

my ( $rc, $out )
    = cli( 'root', 'init', $key, '-argon-m', 1024, '-argon-t', 1 );
ok( $rc == 0, 'root key created' ) or say $out;

my $host_signer = test_signer();
my $disk        = disk_init(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| parent |   => test_signer(),
    qw| name |     => 'drill-test',
    qw| intent |   => 'stage 7',
);
disk_attach(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| disk |     => $disk,
    qw| host |     => $host_signer,
);
my $src = "$box->{'src'}/tree";
make_dirs("$src/nested");
make_dirs("$src/empty");
write_file( "$src/nested/file", "sealed drill contents\n" );
write_file( "$src/second",      "second file\n" );
link "$src/second", "$src/hardlink" or die $OS_ERROR;
symlink 'nested/file', "$src/link" or die $OS_ERROR;
chmod 0640, "$src/nested/file" or die $OS_ERROR;
utime 123456789, 123456789, "$src/nested/file" or die $OS_ERROR;

foreach my $tree (qw| tree-old tree-new |) {
    assimilate(
        qw| root |           => $box->{'root'},
        qw| host_dir |       => $box->{'host'},
        qw| disk |           => $disk,
        qw| host |           => $host_signer,
        qw| paths |          => [$src],
        qw| tree |           => $tree,
        qw| remove |         => 0,
        qw| category_rules | => [],
        qw| protect |        => [],
    );
}
my $holder = "$base/holder";
( $rc, $out )
    = cli( 'seal', $disk, '-root-key', $key, '-out', $holder, '-all-trees' );
ok( $rc == 0, 'two trees sealed to one sandbox holder' ) or say $out;

my $clean = "$base/offline";
make_dirs($clean);
copy( $key, "$clean/root.key" ) or die $OS_ERROR;
chmod 0600, "$clean/root.key";
chmod 0500, $clean or die $OS_ERROR;
my $before = snapshot($clean);
my $target = "$base/recovered";
( $rc, $out ) = cli(
    '-host-dir',       "$base/clean-host",
    'seal-recover',    '-root-key',
    "$clean/root.key", '-from',
    $holder,           '-tree',
    'tree-old',        $target
);
ok( $rc == 0, 'named-tree recovery works with a key in a 0500 directory' )
    or say $out;
ok( snap_equal( $before, snapshot($clean) ) && !-e "$clean/root.key.state",
    'clean recovery writes nothing beside the offline key' );
ok( read_file("$target/nested/file") eq "sealed drill contents\n"
        && readlink("$target/link") eq 'nested/file',
    'clean recovery restores contents and links'
);

my $state = "$base/explicit-state";
( $rc, $out ) = cli(
    '-host-dir',       "$base/clean-host",
    'seal-recover',    '-root-key',
    "$clean/root.key", '-from',
    $holder,           '-state-dir',
    $state,            '-import-holders'
);
ok( $rc == 0 && -f "$state/registry" && !-e "$clean/root.key.state",
    '-state-dir receives the imported registry instead of the key directory'
) or say $out;

( $rc, $out )
    = cli( '-host-dir', $box->{'host'},
    'drill', "$clean/root.key", '-from', $holder );
ok( $rc == 0
        && $out =~ m|restored tree-new|
        && $out =~ m|verified : contents, manifest, metadata|
        && $out =~ m|drill passed|,
    'drill restores and verifies the newest complete tree'
) or say $out;
ok( snap_equal( $before, snapshot($clean) ),
    'a successful drill also leaves the read-only key directory unchanged' );

my $root    = open_root($key);
my $records = drill_records( $box->{'host'}, $root );
my $record  = $records->[-1];
ok( @{$records} == 1
        && $record->{'result'} eq 'passed'
        && $record->{'tree'} eq 'tree-new'
        && $record->{'files'} == 3
        && $record->{'bytes'} == 34
        && $record->{'holder_id'} =~ m|\A[A-Z2-7]{26}\z|
        && $record->{'head_version'} >= 1,
    'the passing drill record verifies and carries its required counts'
);
my $drill_path = "$box->{'host'}/receipts/$root->{'root_id'}/drills.json";
ok( -f $drill_path && ( ( stat $drill_path )[2] & 0777 ) == 0600,
    'the drill record is stored with the root receipts at mode 0600'
);
ok( drill_latest( $box->{'host'}, $root, $holder )->{'tree'} eq 'tree-new',
    'the latest passing drill can be read back by holder' );

my $holder2 = "$base/holder-two";
( $rc, $out )
    = cli( 'seal', $disk, '-root-key', $key, '-out', $holder2, '-all-trees' );
ok( $rc == 0, 'a second holder receives a refreshed head' ) or say $out;
my ( $head2, undef ) = AMOS7::N7FS::Seal::_head_locate( $root, $holder2 );
my ($peer) = grep { ref $head2->{'peers'}{$ARG}{'d'} eq 'HASH' }
    keys $head2->{'peers'}->%*;
ok( defined $peer
        && $head2->{'peers'}{$peer}{'d'}{'tr'} eq 'tree-new'
        && $head2->{'peers'}{$peer}{'d'}{'f'} == 3
        && $head2->{'peers'}{$peer}{'d'}{'b'} == 34,
    'the next head summarizes the last passing drill in its peers'
);

my $good_record = read_file($drill_path);
my $decoded     = JSON::PP::decode_json( [ split m|\n|, $good_record ]->[0] );
$decoded->{'drill'}{'files'}++;
open( my $forge, '>>:raw', $drill_path ) or die $OS_ERROR;
print {$forge} JSON::PP::encode_json($decoded) . "\n";
close $forge or die $OS_ERROR;
refused(
    sub { drill_records( $box->{'host'}, $root ) },
    qr|drill record signature does not verify|,
    'a forged drill record is refused'
);
write_file( $drill_path, $good_record );
chmod 0600, $drill_path;

my ( undef, undef, $map, $base_spec )
    = AMOS7::N7FS::Seal::_context( $root, $holder, 0 );
my ($address) = grep { exists $map->{'nodes'}{$ARG} }
    sort keys $map->{'nodes'}->%*;
my $entry     = $map->{'nodes'}{$address};
my $blob      = "$base_spec/$entry->{'blob'}";
my $good_blob = read_file($blob);
substr( $good_blob, -1, 1 ) = chr( ord( substr( $good_blob, -1, 1 ) ) ^ 1 );
write_file( $blob, $good_blob );
( $rc, $out )
    = cli( '-host-dir', $box->{'host'},
    'drill', "$clean/root.key", '-from', $holder, '-tree', 'tree-new' );
ok( $rc != 0
        && $out =~ m|drill FAILED|
        && $out =~ m|blob address mismatch|
        && $out =~ m|scratch kept :|,
    'a damaged chunk fails precisely, non-zero, with its scratch path'
) or say $out;
my ($kept) = $out =~ m|scratch kept : (\S+)|;
remove_tree($kept) if defined $kept and $kept =~ m|\A\Q$base\E/tmp/|;
$records = drill_records( $box->{'host'}, $root );
ok( $records->[-1]{'result'} eq 'failed'
        && $records->[-1]{'error'} =~ m|blob address mismatch|,
    'the failed drill has its own verifiable signed record'
);
ok( snap_equal( $before, snapshot($clean) ),
    'a failed drill still writes nothing beside the key' );

chmod 0700, $clean or die $OS_ERROR;
done();

#,,,,,,.,,...,.,,,...,,.,,..,,..,,.,.,,,.,...,..,,...,...,.,,,.,,,,,.,..,,.,.,
#3ORVBSULA5PX6ZZRE6EMBEOV2FTVOUYRQCEAQUMUWTEV6TXZJ6TKYW7RW5KXC7KMYYXBGUJUTEGOI
#\\\|KFRXZJPMJM3WLFR5WJI6VDHZBGA6IC3FJHWUN7RQU2WVFA5URBI \ / AMOS7 \ YOURUM ::
#\[7]47Q3IX6NQWIOQJSRORD6KMG567XVGDBBVCWK623L4PKSQI6JI2DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
