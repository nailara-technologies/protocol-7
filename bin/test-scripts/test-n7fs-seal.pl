#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

use FindBin;
use Cwd        qw| abs_path |;
use File::Copy qw| copy |;
use IPC::Open3 qw| open3 |;
use Symbol     qw| gensym |;

$^F = 100;

BEGIN {
    unshift @INC, "$FindBin::Bin/../../data/lib-path/pm";
    unshift @INC, $ENV{'N7FS_TEST_LIB'} if $ENV{'N7FS_TEST_LIB'};
}

use AMOS7::N7FS        qw| read_file write_new_file b32 unb32 make_dirs |;
use AMOS7::N7FS::Disk  qw| disk_init disk_attach |;
use AMOS7::N7FS::Store qw| assimilate |;
use AMOS7::N7FS::Sum   qw| bmw384_bytes bmw_b32 |;
use AMOS7::N7FS::Keys  qw| root_open |;
use AMOS7::N7FS::Seal
    qw| new_keypair seal_bytes open_sealed_bytes twofish_crypt |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

## these checks address single node blobs ; packs : test-n7fs-pack.pl ##
$ENV{'N7FS_TEST_PACK_LIMIT'} = 0;

my $box      = sandbox();
my $cli      = "$FindBin::Bin/../n7fs";
my $passfile = "$box->{'base'}/pass";
write_new_file( $passfile, "correct horse\ncorrect horse\n" );
my $rootfile = "$box->{'base'}/root.key";

sub cli {
    my ( $expect, $name, @args ) = @_;
    open( my $pass, '<:raw', $passfile ) or die $OS_ERROR;
    my ( $in, $out, $err ) = ( undef, undef, gensym );
    my $pid
        = open3( $in, $out, $err, $cli, '-pass-fd', fileno($pass), @args );
    close $in;
    my $stdout = do { local $INPUT_RECORD_SEPARATOR; <$out> }
        // '';
    my $stderr = do { local $INPUT_RECORD_SEPARATOR; <$err> }
        // '';
    waitpid $pid, 0;
    my $status = $CHILD_ERROR >> 8;
    ok( $status == $expect, "$name [ status $status ]" );
    say "        $stderr" if $status != $expect;
    ok( index( $stdout . $stderr, 'correct horse' ) < 0,
        "$name : passphrase not printed" );
    return ( $stdout, $stderr );
}

sub root_at {
    my $path = shift;
    open( my $pass, '<:raw', $passfile ) or die $OS_ERROR;
    return root_open( qw| path | => $path, qw| pass_fd | => fileno($pass) );
}

say ':: root and vectors';
cli( 0, 'root init', '-root-key', $rootfile, '-argon-m', 1024,
    qw| root init |, $rootfile );
cli( 0, 'root export-check',
    '-root-key', $rootfile, qw| root export-check |, $rootfile );
{
    local $ENV{'N7FS_TEST_LIB'};
    write_new_file( "$box->{'base'}/wrong", "wrong\n" );
    my $keep = $passfile;
    $passfile = "$box->{'base'}/wrong";
    cli( 1, 'wrong passphrase',
        '-root-key', $rootfile, qw| root export-check |, $rootfile );
    $passfile = $keep;
}
my $vector_key = join '', map {chr} 0 .. 63;
my $vector
    = seal_bytes( $vector_key, 'n7fs known answer', 'vector', 'V' x 16, 7 );
ok( open_sealed_bytes( $vector_key, $vector, 'vector', 'V' x 16, 7 ) eq
        'n7fs known answer',
    'both layers round trip'
);
ok( unpack( 'H*', $vector ) eq
        'bf027f789933045d0d2a5b384d2a69bdd3bee977e8067f9c127999cf89a2e2f4d5',
    'suite known-answer vector'
);
my $rollover_iv = "\0" x 6 . "\x01\x01" . "\xff" x 8;
my $rollover    = twofish_crypt( 'R' x 32, $rollover_iv, "\0" x 32 );
ok( unpack( 'H*', substr( $rollover, 16 ) ) eq
        'a0e9086eb2dd93feb9f0de8d0fdd92ce',
    'twofish counter carry stays in the low 64 bits'
);
{
    my @draws;
    no warnings qw| redefine |;
    local *AMOS7::N7FS::Seal::random_bytes = sub {
        push @draws, $ARG[0];
        return chr( 65 + scalar @draws ) x $ARG[0];
    };
    my $pair = new_keypair();
    ok( @draws == 2
            and $draws[0] == 32
            and $draws[1] == 32
            and substr( $pair, 0, 32 ) ne substr( $pair, 32, 32 ),
        'two independent os entropy draws make each node keypair'
    );
}

say ':: store and round trips';
my $host = test_signer();
my $disk = disk_init(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| parent |   => test_signer(),
    qw| name |     => 'seal-test',
    qw| intent |   => 'local sealing tests',
);
disk_attach(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| disk |     => $disk,
    qw| host |     => $host,
);
my @sizes = ( 0, 16 * 1024 * 1024, 16 * 1024 * 1024 + 1, 37 );
my @paths;
foreach my $index ( 0 .. $#sizes ) {
    my $path = "$box->{'src'}/node-$index";
    write_new_file( $path,
        $sizes[$index] > 1000
        ? ( 'P' x ( $sizes[$index] - 1 ) ) . 'Q'
        : ( $index == 3 ? 'plaintext-must-never-leak-37' : '' ) );
    push @paths, $path;
}
my $import = assimilate(
    qw| root |           => $box->{'root'},
    qw| host_dir |       => $box->{'host'},
    qw| disk |           => $disk,
    qw| host |           => $host,
    qw| paths |          => \@paths,
    qw| remove |         => 0,
    qw| category_rules | => [],
    qw| protect |        => [],
);
my @addresses = grep {m|\AV7[A-Z2-7]{5}/[A-Z2-7]{7}/[A-Z2-7]{77}\z|}
    map { $ARG->{'addr'} // '' } $import->{'entries'}->@*;
my $holder = "$box->{'base'}/holder";
cli(0,      'seal all sizes', '-root-key', $rootfile,
    '-out', $holder,          'seal',      $disk,
    @addresses
);
my $hsub = holder_sub($holder);
ok( defined $hsub, 'a fresh holder starts in the per-root layout' );
my $initial_root = root_at($rootfile);
my $initial_head_path
    = "$hsub/" . AMOS7::N7FS::Seal::_head_name($initial_root);
my $initial_head_bytes = read_file($initial_head_path);
cli( 0, 'seal is idempotent',
    '-root-key', $rootfile, '-out', $holder, 'seal', $disk, @addresses );
ok( read_file($initial_head_path) eq $initial_head_bytes,
    'idempotent resume reuses neither head nonce nor wraps'
);

foreach my $index ( 0 .. $#addresses ) {
    my $target = "$box->{'base'}/restored-$index";
    cli( 0, "unseal $index",
        '-root-key', $rootfile, '-from',            $holder,
        'unseal',    $disk,     $addresses[$index], $target );
    ok( read_file($target) eq read_file( $paths[$index] ),
        "round trip size $sizes[$index]" );
}

say ':: holder opacity and clean recovery';
my $opaque = 1;
foreach my $name ( holder_blobs($holder) ) {
    my $bytes = read_file("$hsub/$name");
    $opaque = 0 if index( $bytes, 'plaintext-must-never-leak-37' ) >= 0;
    $opaque = 0
        if index( $bytes, bmw384_bytes('plaintext-must-never-leak-37') ) >= 0;
    $opaque = 0
        if index( $bytes,
        bmw_b32( bmw384_bytes('plaintext-must-never-leak-37') ) ) >= 0;
}
ok( $opaque, 'holder contains no plaintext or plaintext hash' );
my $clean_root = "$box->{'base'}/clean-root.key";
copy( $rootfile, $clean_root ) or die $OS_ERROR;
chmod 0600, $clean_root;
my $recovered = "$box->{'base'}/recovered";
cli( 0, 'recover from root and holder only',
    '-root-key', $clean_root, '-from', $holder, 'seal-recover', $recovered );
foreach my $index ( 0 .. $#addresses ) {
    my $safe = $addresses[$index];
    $safe =~ s|/|_|g;
    ok( read_file("$recovered/$safe") eq read_file( $paths[$index] ),
        "clean recovery $index" );
}

say ':: tree restore';
chmod 0644, $paths[3] or die $OS_ERROR;
utime 123456789, 123456789, $paths[3] or die $OS_ERROR;
symlink 'node-3', "$box->{'src'}/link" or die $OS_ERROR;
assimilate(
    qw| root |           => $box->{'root'},
    qw| host_dir |       => $box->{'host'},
    qw| disk |           => $disk,
    qw| host |           => $host,
    qw| paths |          => [ $box->{'src'} ],
    qw| tree |           => 'sealed-tree',
    qw| remove |         => 0,
    qw| category_rules | => [],
    qw| protect |        => [],
);
my $tree_id = AMOS7::N7FS::Disk::disk_read_id(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| disk |     => $disk
);
my $tree_replay      = AMOS7::N7FS::Journal::journal_replay($tree_id);
my $manifest_address = $tree_replay->{'trees'}{'sealed-tree'}{'manifest'};
cli( 0, 'category sealing includes live tree manifests',
    '-root-key', $rootfile, '-out', $holder,
    '-category', 'default', 'seal', $disk );
my $tree_target = "$box->{'base'}/unsealed-tree";
cli(0,             'unseal named tree', '-root-key', $rootfile,
    '-from',       $holder,             'unseal',    $disk,
    'sealed-tree', $tree_target
);
ok( read_file("$tree_target/node-3") eq read_file( $paths[3] ),
    'tree operand restores verified content' );
my @source_stat = stat $paths[3];
my @tree_stat   = stat "$tree_target/node-3";
ok( ( $source_stat[2] & 07777 ) == ( $tree_stat[2] & 07777 )
        and $source_stat[9] == $tree_stat[9]
        and $source_stat[4] == $tree_stat[4]
        and $source_stat[5] == $tree_stat[5],
    'tree restore preserves mode, mtime and owner'
);
ok( readlink("$tree_target/link") eq 'node-3',
    'tree restore preserves symlinks'
);
my $clean_tree_root = "$box->{'base'}/clean-tree-root.key";
copy( $rootfile, $clean_tree_root ) or die $OS_ERROR;
chmod 0600, $clean_tree_root;
my $clean_tree = "$box->{'base'}/clean-tree";
cli(0,              'clean host recovers a named tree without a disk',
    '-root-key',    $clean_tree_root,
    '-from',        $holder,
    '-tree',        'sealed-tree',
    'seal-recover', $clean_tree
);
ok( read_file("$clean_tree/node-3") eq read_file( $paths[3] ),
    'clean named-tree recovery restores content' );

say ':: rejection';
my $root = root_at($rootfile);
my ( undef, $head, $map ) = AMOS7::N7FS::Seal::_context( $root, $holder, 0 );
my $small     = $addresses[3];
my $entry     = $map->{'nodes'}{$small};
my $blob_path = "$hsub/$entry->{'blob'}";
my $good_blob = read_file($blob_path);
write_new_file( "$box->{'base'}/pristine-blob", $good_blob );
substr( $good_blob, 20, 1 ) = chr( ord( substr( $good_blob, 20, 1 ) ) ^ 1 );
write_new_file( "$box->{'base'}/tampered", $good_blob );
copy( "$box->{'base'}/tampered", $blob_path ) or die $OS_ERROR;
cli( 1, 'tamper refused',
    '-root-key', $rootfile, '-from', $holder,
    'unseal',    $disk,     $small,  "$box->{'base'}/bad-tamper" );
copy( "$box->{'base'}/pristine-blob", $blob_path ) or die $OS_ERROR;

say ':: independent node keys';
my $holder2 = "$box->{'base'}/holder2";
cli( 0, 'seal same content elsewhere',
    '-root-key', $rootfile, '-out', $holder2, 'seal', $disk, $small );
my $root2 = root_at($rootfile);
my ( undef, undef, $map2 )
    = AMOS7::N7FS::Seal::_context( $root2, $holder2, 0 );
ok( $map2->{'nodes'}{$small}{'blob'} ne $entry->{'blob'},
    'identical content has different node keys and ciphertext'
);

say ':: shred step 1';
cli(0,      'shred one node', '-root-key', $rootfile,
    '-out', $holder,          'shred',     $disk,
    $small
);
cli( 1, 'shredded node does not unseal',
    '-root-key', $rootfile, '-from', $holder,
    'unseal',    $disk,     $small,  "$box->{'base'}/shredded" );
my $survivor = "$box->{'base'}/survivor";
cli( 0, 'other node survives shred',
    '-root-key', $rootfile, '-from',       $holder,
    'unseal',    $disk,     $addresses[0], $survivor );

say ':: truncation, reorder and blob swap';
copy( "$box->{'base'}/pristine-blob", $blob_path ) or die $OS_ERROR;
my $other_path     = "$hsub/" . $map->{'nodes'}{ $addresses[0] }{'blob'};
my $other_pristine = read_file($other_path);
write_new_file( "$box->{'base'}/other-pristine", $other_pristine );
my $truncated = substr( $other_pristine, 0, -1 );
write_new_file( "$box->{'base'}/truncated", $truncated );
copy( "$box->{'base'}/truncated", $other_path ) or die $OS_ERROR;
cli( 1, 'truncated blob refused',
    '-root-key', $rootfile, '-from',       $holder,
    'unseal',    $disk,     $addresses[0], "$box->{'base'}/bad-truncated" );
copy( "$box->{'base'}/other-pristine", $other_path ) or die $OS_ERROR;
copy( "$box->{'base'}/pristine-blob",  $blob_path )  or die $OS_ERROR;
my $small_again = read_file($blob_path);
my $other_again = read_file($other_path);
copy( $other_path,                    $blob_path )  or die $OS_ERROR;
copy( "$box->{'base'}/pristine-blob", $other_path ) or die $OS_ERROR;
cli(1,             'blob swap refused',
    '-root-key',   $rootfile,
    '-from',       $holder,
    'unseal',      $disk,
    $addresses[0], "$box->{'base'}/bad-swap"
);
write_new_file( "$box->{'base'}/small-again", $small_again );
write_new_file( "$box->{'base'}/other-again", $other_again );
copy( "$box->{'base'}/small-again", $blob_path )  or die $OS_ERROR;
copy( "$box->{'base'}/other-again", $other_path ) or die $OS_ERROR;
my $large_path = "$hsub/" . $map->{'nodes'}{ $addresses[2] }{'blob'};
my $large      = read_file($large_path);
my $first_len  = unpack 'N', substr( $large, 26, 4 );
my $first      = substr( $large, 26, 4 + $first_len );
my $second     = substr( $large, 26 + 4 + $first_len );
write_new_file( "$box->{'base'}/reordered",
    substr( $large, 0, 26 ) . $second . $first );
copy( "$box->{'base'}/reordered", $large_path ) or die $OS_ERROR;
cli( 1, 'chunk reorder refused',
    '-root-key', $rootfile, '-from',       $holder,
    'unseal',    $disk,     $addresses[2], "$box->{'base'}/bad-reorder" );
write_new_file( "$box->{'base'}/large-good", $large );
copy( "$box->{'base'}/large-good", $large_path ) or die $OS_ERROR;

say ':: crash and resume at each seal fault';
foreach my $point (
    qw| seal:before-blob seal:after-blob seal:before-version
    seal:after-reservation seal:after-version seal:after-map seal:after-journal
    seal:after-head |
) {
    my $crash_root = "$box->{'base'}/crash-$point.key";
    copy( $rootfile, $crash_root ) or die $OS_ERROR;
    chmod 0600, $crash_root;
    my $crash_holder = "$box->{'base'}/crash-$point";
    local $ENV{'N7FS_TEST_FAULT'} = $point;
    cli(1,      "crash $point", '-root-key', $crash_root,
        '-out', $crash_holder,  'seal',      $disk,
        $small
    );
    delete local $ENV{'N7FS_TEST_FAULT'};
    cli(0,      "resume $point", '-root-key', $crash_root,
        '-out', $crash_holder,   'seal',      $disk,
        $small
    );
    cli( 0, "resume is idempotent $point",
        '-root-key', $crash_root, '-out', $crash_holder, 'seal', $disk,
        $small );
    cli(0,           "recovered after $point",
        '-root-key', $crash_root,
        '-from',     $crash_holder,
        'unseal',    $disk,
        $small,      "$box->{'base'}/crash-restored-$point"
    );
}

say ':: independent writers and reservation recovery';
my $writer_root1 = "$box->{'base'}/writer1.key";
my $writer_root2 = "$box->{'base'}/writer2.key";
copy( $rootfile, $writer_root1 ) or die $OS_ERROR;
copy( $rootfile, $writer_root2 ) or die $OS_ERROR;
chmod 0600, $writer_root1, $writer_root2;
my $writer_holder1 = "$box->{'base'}/writer-holder1";
my $writer_holder2 = "$box->{'base'}/writer-holder2";
cli( 0, 'first writer seals version one',
    '-root-key', $writer_root1,
    '-out', $writer_holder1, 'seal', $disk, $small );
cli( 0, 'second state seals version one elsewhere',
    '-root-key', $writer_root2,
    '-out', $writer_holder2, 'seal', $disk, $small );
my $writer1      = root_at($writer_root1);
my $writer2      = root_at($writer_root2);
my $whsub1       = holder_sub($writer_holder1);
my $whsub2       = holder_sub($writer_holder2);
my $writer_head1 = AMOS7::N7FS::Seal::_head_open( $writer1, $whsub1, 1 );
my $writer_head2 = AMOS7::N7FS::Seal::_head_open( $writer2, $whsub2, 1 );
my $writer_bytes1
    = read_file( "$whsub1/" . AMOS7::N7FS::Seal::_head_name($writer1) );
my $writer_bytes2
    = read_file( "$whsub2/" . AMOS7::N7FS::Seal::_head_name($writer2) );
ok( $writer_head1->{'writer'} ne $writer_head2->{'writer'}
        and $writer_bytes1 ne $writer_bytes2,
    'state loss cannot repeat a head nonce'
);
my $writer_map1     = read_file("$whsub1/$writer_head1->{'map'}");
my $writer_map2     = read_file("$whsub2/$writer_head2->{'map'}");
my $writer_journal1 = read_file("$whsub1/$writer_head1->{'journal'}");
my $writer_journal2 = read_file("$whsub2/$writer_head2->{'journal'}");
ok( $writer_map1 ne $writer_map2 and $writer_journal1 ne $writer_journal2,
    'map and journal nonces differ across writers' );
ok( substr( $writer_bytes1, 8, 16 ) ne substr( $writer_bytes2, 8, 16 )
        and substr( $writer_map1,     0, 16 ) ne substr( $writer_map2, 0, 16 )
        and substr( $writer_journal1, 0, 16 ) ne
        substr( $writer_journal2, 0, 16 ),
    'writer ids are carried in clear records'
);
cli( 0, 'second writer advances its holder',
    '-root-key', $writer_root2,
    '-out', $writer_holder2, 'seal', $disk, $addresses[0] );
my $writer_root3 = "$box->{'base'}/writer3.key";
copy( $rootfile, $writer_root3 ) or die $OS_ERROR;
chmod 0600, $writer_root3;
cli( 0, 'new state starts above the visible head',
    '-root-key', $writer_root3,
    '-out', $writer_holder2, 'seal', $disk, $addresses[1] );
my $writer3      = root_at($writer_root3);
my $writer_head3 = AMOS7::N7FS::Seal::_head_open( $writer3, $whsub2, 1 );
ok( $writer_head3->{'version'} == 3,
    'new writer version follows the newest visible head' );
my $writer_recovery = "$box->{'base'}/writer-recovery";
cli( 0, 'clean recovery reads the newest writer head',
    '-root-key',    $writer_root3, '-from', $writer_holder2,
    'seal-recover', $writer_recovery );
my $writer_safe = $addresses[1];
$writer_safe =~ s|/|_|g;
ok( -f "$writer_recovery/$writer_safe", 'newest writer map is recovered' );

say ':: batch resume and multi-category wraps';
my $batch_holder = "$box->{'base'}/batch-holder";
my $batch_root   = "$box->{'base'}/batch.key";
copy( $rootfile, $batch_root ) or die $OS_ERROR;
chmod 0600, $batch_root;
{
    local $ENV{'N7FS_TEST_SEAL_BATCH'} = 2;
    local $ENV{'N7FS_TEST_FAULT'}      = 'seal:after-head';
    cli( 1, 'fault after a mid-run commit',
        '-root-key', $batch_root,
        '-out', $batch_holder, 'seal', $disk, @addresses[ 0 .. 2 ] );
    delete local $ENV{'N7FS_TEST_FAULT'};
    my ($batch_out) = cli( 0, 'resume after mid-run commit',
        '-root-key', $batch_root, '-out', $batch_holder,
        'seal',      $disk,       @addresses[ 0 .. 2 ] );
    ok( $batch_out =~ m|1 new nodes|,
        'earlier committed nodes are not resealed' );
}
require AMOS7::N7FS::Category;
AMOS7::N7FS::Category::category_set(
    qw| root |             => $box->{'root'},
    qw| host_dir |         => $box->{'host'},
    qw| disk |             => $disk,
    qw| host |             => $host,
    qw| name |             => 'secondary',
    qw| local_encryption | => 'none',
);
AMOS7::N7FS::Category::category_set_reference(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| disk |     => $disk,
    qw| host |     => $host,
    qw| target |   => $small,
    qw| category | => 'secondary',
);
copy( $paths[3], "$box->{'src'}/alias" ) or die $OS_ERROR;
assimilate(
    qw| root |           => $box->{'root'},
    qw| host_dir |       => $box->{'host'},
    qw| disk |           => $disk,
    qw| host |           => $host,
    qw| paths |          => ["$box->{'src'}/alias"],
    qw| remove |         => 0,
    qw| category_rules | => [],
    qw| protect |        => [],
);
my $multi_holder = "$box->{'base'}/multi-holder";
cli( 0, 'deduplicated node seals under two categories',
    '-root-key', $rootfile, '-out', $multi_holder, 'seal', $disk, $small );
my $multi_root = root_at($rootfile);
my ( undef, undef, $multi_map )
    = AMOS7::N7FS::Seal::_context( $multi_root, $multi_holder, 0 );
ok( scalar keys $multi_map->{'nodes'}{$small}{'wraps'}->%* == 2,
    'map carries one wrap per referencing category'
);
my $multi_target = "$box->{'base'}/multi-restored";
cli( 0, 'multi-category node restores',
    '-root-key', $rootfile,
    '-from',     $multi_holder, 'unseal', $disk, $small, $multi_target );

say ':: plaintext verification, layout and option domains';
my $local_content = AMOS7::N7FS::Seal::_content_path( $tree_id, $small );
copy( $local_content, "$box->{'base'}/local-content-good" ) or die $OS_ERROR;
write_new_file( "$box->{'base'}/bit-rot", 'rot' );
chmod 0600, $local_content or die $OS_ERROR;
copy( "$box->{'base'}/bit-rot", $local_content ) or die $OS_ERROR;
my $rot_holder = "$box->{'base'}/rot-holder";
cli( 1, 'plaintext address mismatch refused while sealing',
    '-root-key', $rootfile, '-out', $rot_holder, 'seal', $disk, $small );
copy( "$box->{'base'}/local-content-good", $local_content ) or die $OS_ERROR;
my $bad_layout = { %{ $multi_map->{'nodes'}{$small} } };
$bad_layout->{'layout'} = {
    qw| mode |        => qw| segment |,
    qw| chunk_size |  => 16 * 1024 * 1024,
    qw| header_size | => 0
};
refused(
    sub {
        AMOS7::N7FS::Seal::_restore_node( $multi_root, $multi_holder,
            { %{$multi_map}, 'nodes' => { $small => $bad_layout } },
            $small, "$box->{'base'}/bad-layout" );
    },
    qr|unknown or impossible sealed content layout|,
    'reserved layout mode refused'
);
my $disk_root_holder = "$box->{'base'}/disk-root-holder";
cli(0,           'disk root and root key options coexist',
    '-root',     $box->{'root'},
    '-root-key', $rootfile,
    '-out',      $disk_root_holder,
    '-tree',     'sealed-tree',
    'seal',      $disk
);
my $all_trees_holder = "$box->{'base'}/all-trees-holder";
cli( 0, 'all-trees seals live tree records and file nodes',
    '-root-key',  $rootfile, '-out', $all_trees_holder,
    '-all-trees', 'seal',    $disk );
AMOS7::N7FS::Seal::_context( $multi_root, "$multi_holder/.", 0 );
my $canonical_state = AMOS7::N7FS::Seal::_state_read($multi_root);
ok(
    (   grep { $_ eq Cwd::abs_path($ARG) }
            keys $canonical_state->{'pins'}->%*
    ) == scalar keys $canonical_state->{'pins'}->%*,
    'holder pins use canonical paths'
);
{
    my $calls    = 0;
    my $original = \&AMOS7::N7FS::Journal::journal_replay;
    no warnings qw| redefine |;
    local *AMOS7::N7FS::Seal::journal_replay = sub {
        $calls++;
        return $original->(@ARG);
    };
    my $scale_root = root_at($rootfile);
    AMOS7::N7FS::Seal::seal_nodes(
        qw| disk |      => $disk,
        qw| disk_root | => $box->{'root'},
        qw| root |      => $scale_root,
        qw| holder |    => "$box->{'base'}/scale-holder",
        qw| addresses | => [$small],
        qw| trees |     => [],
    );
    ok( $calls == 1, 'seal selection replays the journal once' );
}

say ':: old head and cascade refusal';
my $head_path = "$hsub/" . AMOS7::N7FS::Seal::_head_name($root);
copy( $head_path, "$box->{'base'}/old-head" ) or die $OS_ERROR;
cli(0,      'advance head', '-root-key', $rootfile,
    '-out', $holder,        'shred',     $disk,
    $addresses[0]
);
copy( "$box->{'base'}/old-head", $head_path ) or die $OS_ERROR;
cli( 1, 'old head refused by pin',
    '-root-key', $rootfile, '-from',       $holder,
    'unseal',    $disk,     $addresses[1], "$box->{'base'}/old-head-target" );
copy( "$box->{'base'}/old-head", "$box->{'base'}/saved-head" );
require AMOS7::N7FS::Category;
AMOS7::N7FS::Category::category_set(
    qw| root |             => $box->{'root'},
    qw| host_dir |         => $box->{'host'},
    qw| disk |             => $disk,
    qw| host |             => $host,
    qw| name |             => 'protected',
    qw| local_encryption | => 'cascade',
);
AMOS7::N7FS::Category::category_set_reference(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| disk |     => $disk,
    qw| host |     => $host,
    qw| target |   => $small,
    qw| category | => 'protected',
);
my $cascade_holder = "$box->{'base'}/cascade-holder";
cli( 1, 'cascade refused rather than ignored',
    '-root-key', $rootfile, '-out', $cascade_holder, 'seal', $disk, $small );

done();

#,,,,,...,,.,,..,,,.,,.,.,,,.,.,.,...,...,...,..,,...,...,..,,...,,,,,.,.,.,.,
#64GHGD2TLEDA4H4LQAJG7YHCK53QX2ZFUOJTI7BEVSE6PMVYUHW5363RGUBYFS5N7U3SLU7TEC5MQ
#\\\|B4QMWNDZEKQ6NERJ4HLRUYHZN2KLNRDFDTPK4RU4NM3D4SS6PXD \ / AMOS7 \ YOURUM ::
#\[7]O6KZQMYRRRD6JDO4WOCO2W6KWQLOMBEN6GYBLSXE762HB53ERWAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
